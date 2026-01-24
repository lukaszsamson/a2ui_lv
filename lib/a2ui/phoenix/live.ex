defmodule A2UI.Phoenix.Live do
  @moduledoc """
  LiveView behavior for A2UI rendering.

  This is a thin Phoenix adapter over `A2UI.Session`, providing:
  - Message ingestion via handle_info
  - User events via handle_event
  - Two-way binding for input components
  - Version-aware action event construction and dispatch
  - Event transport integration for client→server communication

  Per LiveView docs on bindings:
  - phx-click for button actions
  - phx-change with phx-debounce for text inputs
  - phx-value-* for passing data to server

  ## Event Transport

  Per the A2UI spec, client events should be sent back to the server.
  Configure an event transport to enable this:

      socket = A2UI.Phoenix.Live.init(socket,
        event_transport: my_transport_pid,
        event_transport_module: A2UI.Transport.Local
      )

  When configured, all user actions and errors will be sent via the transport
  in addition to invoking any configured callbacks.

  ## Protocol Versions

  The module automatically detects the protocol version from each surface
  and uses the appropriate envelope format:
  - v0.8: `{"userAction": {...}}`
  - v0.9: `{"action": {...}}`
  """

  alias A2UI.{Session, Binding, Event, DataBroadcast, DynamicValue}

  require Logger

  @doc """
  Call this from your LiveView's mount/3 to initialize A2UI state.
  Returns socket with :a2ui_surfaces assign.

  ## Options

  - `:action_callback` - Function called when a user action is triggered.
    Signature: `(user_action, socket) -> any()`
  - `:error_callback` - Function called when a client-side error occurs.
    Signature: `(error, socket) -> any()`
  - `:client_capabilities` - Optional `A2UI.ClientCapabilities` struct
  - `:event_transport` - PID of a process implementing `A2UI.Transport.Events`.
    When configured, userAction and error events are sent to the server.
  - `:event_transport_module` - Module implementing `A2UI.Transport.Events`.
    Defaults to `A2UI.Transport.Local` if not specified.

  ## Example (with transport)

      def mount(_params, _session, socket) do
        {:ok, transport} = A2UI.Transport.Local.start_link(
          event_handler: fn event -> handle_server_event(event) end
        )

        socket = A2UI.Phoenix.Live.init(socket,
          event_transport: transport,
          action_callback: &handle_action/2  # Optional: also get local callback
        )
        {:ok, socket}
      end

  ## Example (without transport, callbacks only)

      def mount(_params, _session, socket) do
        socket = A2UI.Phoenix.Live.init(socket,
          action_callback: &handle_action/2,
          error_callback: &handle_error/2
        )
        {:ok, socket}
      end
  """
  @spec init(Phoenix.LiveView.Socket.t(), keyword()) :: Phoenix.LiveView.Socket.t()
  def init(socket, opts \\ []) do
    session = Session.new(client_capabilities: opts[:client_capabilities])

    Phoenix.Component.assign(socket,
      a2ui_session: session,
      a2ui_surfaces: session.surfaces,
      a2ui_action_callback: opts[:action_callback],
      a2ui_error_callback: opts[:error_callback],
      a2ui_event_transport: opts[:event_transport],
      a2ui_event_transport_module: opts[:event_transport_module] || A2UI.Transport.Local,
      a2ui_last_action: nil,
      a2ui_last_error: nil
    )
  end

  @doc """
  Resets the A2UI session, clearing all surfaces and state.

  Use this when you need to start fresh (e.g., switching between demos/scenarios).
  Preserves the configured callbacks and transport settings.

  ## Example

      socket = A2UI.Phoenix.Live.reset_session(socket)
  """
  @spec reset_session(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def reset_session(socket) do
    # Get existing client_capabilities from the current session if available
    client_capabilities =
      case socket.assigns[:a2ui_session] do
        %Session{} = session -> session.client_capabilities
        _ -> nil
      end

    session = Session.new(client_capabilities: client_capabilities)

    Phoenix.Component.assign(socket,
      a2ui_session: session,
      a2ui_surfaces: session.surfaces,
      a2ui_last_action: nil,
      a2ui_last_error: nil
    )
  end

  @doc """
  Handle incoming A2UI JSONL messages.
  Call from your LiveView's handle_info/2.

  ## Example

      def handle_info({:a2ui, json_line}, socket) do
        A2UI.Phoenix.Live.handle_a2ui_message({:a2ui, json_line}, socket)
      end
  """
  @spec handle_a2ui_message({:a2ui, String.t()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_a2ui_message({:a2ui, json_line}, socket) do
    session = socket.assigns.a2ui_session

    case Session.apply_json_line(session, json_line) do
      {:ok, updated_session} ->
        {:noreply, update_session(socket, updated_session)}

      {:error, error_map} ->
        log_error(error_map)
        {:noreply, emit_error(socket, error_map)}
    end
  end

  @doc """
  Handle A2UI user events.
  Call from your LiveView's handle_event/3.

  ## Events

  - `"a2ui:action"` - Button clicks, triggers action callback with resolved context
  - `"a2ui:input"` - TextField changes, updates data model
  - `"a2ui:toggle"` - CheckBox changes, updates data model

  ## Example

      def handle_event("a2ui:" <> _ = event, params, socket) do
        A2UI.Phoenix.Live.handle_a2ui_event(event, params, socket)
      end
  """
  @spec handle_a2ui_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_a2ui_event("a2ui:action", params, socket) do
    surface_id = params["surface-id"]
    component_id = params["component-id"]

    scope_path =
      case params["scope-path"] do
        "" -> nil
        nil -> nil
        path -> path
      end

    surface = socket.assigns.a2ui_surfaces[surface_id]

    # Look up the component definition to get the action
    component = surface && surface.components[component_id]
    action = component && component.props["action"]

    # Action can be a string (just the name) or a map with name and context
    {action_name, action_context} =
      case action do
        name when is_binary(name) -> {name, []}
        %{"name" => name} -> {name, action["context"] || []}
        _ -> {nil, []}
      end

    if action_name do
      # Determine protocol version from surface (defaults to v0.8 for compatibility)
      version = surface.protocol_version || :v0_8

      # Resolve all context bindings against current data model (version-aware)
      resolved_context =
        resolve_action_context(action_context, surface.data_model, scope_path, version)

      # Build version-aware action envelope
      action_event =
        Event.build_action(version,
          name: action_name,
          surface_id: surface_id,
          component_id: component_id,
          context: resolved_context
        )

      # Send via transport if configured
      send_event_to_transport(socket, action_event)

      # Dispatch to callback if configured (for local handling)
      socket =
        if callback = socket.assigns[:a2ui_action_callback] do
          case callback.(action_event, socket) do
            %Phoenix.LiveView.Socket{} = updated_socket -> updated_socket
            {:noreply, %Phoenix.LiveView.Socket{} = updated_socket} -> updated_socket
            _ -> socket
          end
        else
          socket
        end

      {:noreply, Phoenix.Component.assign(socket, :a2ui_last_action, action_event)}
    else
      Logger.warning("A2UI action event for component without valid action: #{component_id}")
      {:noreply, socket}
    end
  end

  def handle_a2ui_event("a2ui:input", params, socket) do
    # Two-way binding: update local data model on input change
    input = params["a2ui_input"] || %{}
    surface_id = input["surface_id"]
    path = input["path"]
    value = input["value"]

    if path && surface_id do
      socket = update_data_at_path(socket, surface_id, path, value)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_a2ui_event("a2ui:toggle", params, socket) do
    # Two-way binding: update boolean at path
    input = params["a2ui_input"] || %{}
    surface_id = input["surface_id"]
    path = input["path"]
    value = input["value"]

    checked? =
      case value do
        true -> true
        "true" -> true
        "on" -> true
        _ -> false
      end

    if path && surface_id do
      {:noreply, update_data_at_path(socket, surface_id, path, checked?)}
    else
      {:noreply, socket}
    end
  end

  def handle_a2ui_event("a2ui:slider", params, socket) do
    # Two-way binding: update numeric value at path
    input = params["a2ui_input"] || %{}
    surface_id = input["surface_id"]
    path = input["path"]
    value_str = input["value"] || ""

    # Parse as number (integer or float)
    value =
      case Integer.parse(value_str) do
        {int_val, ""} ->
          int_val

        _ ->
          case Float.parse(value_str) do
            {float_val, _} -> float_val
            :error -> 0
          end
      end

    if path && surface_id do
      {:noreply, update_data_at_path(socket, surface_id, path, value)}
    else
      {:noreply, socket}
    end
  end

  def handle_a2ui_event("a2ui:datetime", params, socket) do
    # Two-way binding: convert HTML datetime format to ISO 8601
    input = params["a2ui_input"] || %{}
    surface_id = input["surface_id"]
    path = input["path"]
    value = input["value"] || ""
    input_type = input["input_type"] || "datetime-local"

    # Convert HTML datetime format to ISO 8601
    iso_value = html_datetime_to_iso8601(value, input_type)

    if path && surface_id do
      {:noreply, update_data_at_path(socket, surface_id, path, iso_value)}
    else
      {:noreply, socket}
    end
  end

  def handle_a2ui_event("a2ui:choice", params, socket) do
    # Two-way binding: update selections array at path
    input = params["a2ui_input"] || %{}
    surface_id = input["surface_id"]
    path = input["path"]
    values = input["values"] || []
    max_allowed_str = input["max_allowed"]

    # Filter out empty sentinel value and get actual selections
    selections = Enum.filter(values, &(&1 != "" and &1 != nil))

    # Enforce max_allowed if specified
    max_allowed = parse_max_allowed(max_allowed_str)

    selections =
      if is_integer(max_allowed) and max_allowed > 0 do
        Enum.take(selections, max_allowed)
      else
        selections
      end

    if path && surface_id do
      {:noreply, update_data_at_path(socket, surface_id, path, selections)}
    else
      {:noreply, socket}
    end
  end

  # Private helpers

  defp update_session(socket, session) do
    Phoenix.Component.assign(socket,
      a2ui_session: session,
      a2ui_surfaces: session.surfaces
    )
  end

  defp update_data_at_path(socket, surface_id, path, value) do
    session = socket.assigns.a2ui_session

    case Session.update_data_at_path(session, surface_id, path, value) do
      {:ok, updated_session} ->
        update_session(socket, updated_session)

      {:error, error_map} ->
        log_error(error_map)
        emit_error(socket, error_map)
    end
  end

  defp log_error(error_map) do
    type = get_in(error_map, ["error", "type"]) || "unknown"
    Logger.warning("A2UI #{type}: #{inspect(error_map)}")
  end

  defp html_datetime_to_iso8601("", _type), do: ""
  defp html_datetime_to_iso8601(nil, _type), do: ""

  defp html_datetime_to_iso8601(value, "datetime-local") do
    with [date, time_raw] <- String.split(value, "T", parts: 2),
         {:ok, _} <- Date.from_iso8601(date),
         {:ok, time} <- normalize_html_time(time_raw) do
      "#{date}T#{time}Z"
    else
      _ -> ""
    end
  end

  defp html_datetime_to_iso8601(value, "date") do
    case Date.from_iso8601(value) do
      {:ok, _} -> value
      _ -> ""
    end
  end

  defp html_datetime_to_iso8601(value, "time") do
    case normalize_html_time(value) do
      {:ok, time} -> time
      _ -> ""
    end
  end

  defp html_datetime_to_iso8601(value, _), do: value

  defp normalize_html_time(value) when is_binary(value) do
    case Regex.run(~r/^(\d{2}):(\d{2})(?::(\d{2}))?/, value) do
      [_, hh, mm, ss] ->
        normalize_html_time_parts(hh, mm, ss)

      [_, hh, mm] ->
        normalize_html_time_parts(hh, mm, "00")

      _ ->
        {:error, :invalid_time}
    end
  end

  defp normalize_html_time(_), do: {:error, :invalid_time}

  defp normalize_html_time_parts(hh, mm, ss) do
    with {h, ""} <- Integer.parse(hh),
         {m, ""} <- Integer.parse(mm),
         {s, ""} <- Integer.parse(ss),
         true <- h in 0..23,
         true <- m in 0..59,
         true <- s in 0..59 do
      {:ok, "#{pad2(h)}:#{pad2(m)}:#{pad2(s)}"}
    else
      _ -> {:error, :invalid_time}
    end
  end

  defp pad2(int) when is_integer(int) do
    int
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp parse_max_allowed(""), do: nil
  defp parse_max_allowed(nil), do: nil

  defp parse_max_allowed(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_max_allowed(int) when is_integer(int), do: int
  defp parse_max_allowed(_), do: nil

  # Resolves action context to a map of key => resolved_value.
  # Supports both:
  # - v0.8 format: list of %{"key" => "k", "value" => <BoundValue>}
  # - v0.9 format: map of %{"k" => <DynamicValue>}
  defp resolve_action_context(context, data_model, scope_path, version)

  # v0.9 format: context is a map of DynamicValues
  defp resolve_action_context(context, data_model, scope_path, version) when is_map(context) do
    opts = [version: version]

    Map.new(context, fn {key, value} ->
      resolved = DynamicValue.evaluate(value, data_model, scope_path, opts)
      {key, resolved}
    end)
  end

  # v0.8 format: context is a list of %{"key" => k, "value" => v} entries
  defp resolve_action_context(context, data_model, scope_path, version) when is_list(context) do
    opts = [version: version]

    Enum.reduce(context, %{}, fn
      %{"key" => key, "value" => bound_value}, acc ->
        resolved = Binding.resolve(bound_value, data_model, scope_path, opts)
        Map.put(acc, key, resolved)

      _, acc ->
        acc
    end)
  end

  # Fallback for nil or invalid context
  defp resolve_action_context(_, _data_model, _scope_path, _version), do: %{}

  # Emits an error to the configured callback and stores in assigns for debugging
  # Also sends via transport if configured (per v0.8 spec Section 5)
  defp emit_error(socket, error_map) do
    socket = Phoenix.Component.assign(socket, :a2ui_last_error, error_map)

    # Send via transport if configured (error envelope per spec)
    send_event_to_transport(socket, error_map)

    if callback = socket.assigns[:a2ui_error_callback] do
      case callback.(error_map, socket) do
        %Phoenix.LiveView.Socket{} = updated_socket -> updated_socket
        {:noreply, %Phoenix.LiveView.Socket{} = updated_socket} -> updated_socket
        _ -> socket
      end
    else
      socket
    end
  end

  # Sends an event envelope to the configured transport.
  # Events are single-key envelopes:
  # - v0.8: {"userAction": ...} or {"error": ...}
  # - v0.9: {"action": ...} or {"error": ...}
  #
  # For v0.9, also builds and passes the data broadcast payload for surfaces
  # that have broadcastDataModel enabled.
  defp send_event_to_transport(socket, event_envelope) do
    transport_pid = socket.assigns[:a2ui_event_transport]
    transport_module = socket.assigns[:a2ui_event_transport_module]

    if transport_pid && Process.alive?(transport_pid) do
      # Build data broadcast payload for surfaces with broadcasting enabled
      surfaces = socket.assigns[:a2ui_surfaces] || %{}
      data_broadcast = DataBroadcast.build(surfaces)

      opts = if data_broadcast, do: [data_broadcast: data_broadcast], else: []

      case transport_module.send_event(transport_pid, event_envelope, opts) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("A2UI failed to send event via transport: #{inspect(reason)}")
          {:error, reason}
      end
    else
      :ok
    end
  end
end
