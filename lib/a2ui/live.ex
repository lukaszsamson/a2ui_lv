defmodule A2UI.Live do
  @moduledoc """
  LiveView behavior for A2UI rendering.

  Handles:
  - Message ingestion via handle_info
  - User events via handle_event
  - Two-way binding for input components
  - userAction construction and dispatch

  Per LiveView docs on bindings:
  - phx-click for button actions
  - phx-change with phx-debounce for text inputs
  - phx-value-* for passing data to server
  """

  alias A2UI.{Parser, Surface, Binding, Validator, Error}
  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}

  require Logger

  @doc """
  Call this from your LiveView's mount/3 to initialize A2UI state.
  Returns socket with :a2ui_surfaces assign.

  ## Options

  - `:action_callback` - Function called when a user action is triggered.
    Signature: `(user_action, socket) -> any()`
  - `:error_callback` - Function called when a client-side error occurs.
    Signature: `(error, socket) -> any()`

  ## Example

      def mount(_params, _session, socket) do
        socket = A2UI.Live.init(socket,
          action_callback: &handle_action/2,
          error_callback: &handle_error/2
        )
        {:ok, socket}
      end
  """
  @spec init(Phoenix.LiveView.Socket.t(), keyword()) :: Phoenix.LiveView.Socket.t()
  def init(socket, opts \\ []) do
    Phoenix.Component.assign(socket,
      a2ui_surfaces: %{},
      a2ui_action_callback: opts[:action_callback],
      a2ui_error_callback: opts[:error_callback],
      a2ui_last_action: nil,
      a2ui_last_error: nil
    )
  end

  @doc """
  Handle incoming A2UI JSONL messages.
  Call from your LiveView's handle_info/2.

  ## Example

      def handle_info({:a2ui, json_line}, socket) do
        A2UI.Live.handle_a2ui_message({:a2ui, json_line}, socket)
      end
  """
  @spec handle_a2ui_message({:a2ui, String.t()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_a2ui_message({:a2ui, json_line}, socket) do
    case Parser.parse_line(json_line) do
      {:surface_update, %SurfaceUpdate{surface_id: sid} = msg} ->
        case Validator.validate_surface_update(msg) do
          :ok ->
            {:noreply, update_surface(socket, sid, msg)}

          {:error, {:too_many_components, count, max}} ->
            error =
              Error.validation_error(
                "Too many components: #{count} exceeds limit #{max}",
                sid,
                %{"count" => count, "limit" => max}
              )

            Logger.warning("A2UI surfaceUpdate rejected: too_many_components")
            {:noreply, emit_error(socket, error)}

          {:error, {:unknown_component_types, types}} ->
            error = Error.unknown_component(types, sid)

            Logger.warning(
              "A2UI surfaceUpdate rejected: unknown_component_types #{inspect(types)}"
            )

            {:noreply, emit_error(socket, error)}

          {:error, reason} ->
            error = Error.validation_error("Validation failed: #{inspect(reason)}", sid)
            Logger.warning("A2UI surfaceUpdate rejected: #{inspect(reason)}")
            {:noreply, emit_error(socket, error)}
        end

      {:data_model_update, %DataModelUpdate{surface_id: sid} = msg} ->
        {:noreply, update_surface(socket, sid, msg)}

      {:begin_rendering, %BeginRendering{surface_id: sid} = msg} ->
        {:noreply, update_surface(socket, sid, msg)}

      {:delete_surface, %DeleteSurface{surface_id: sid}} ->
        surfaces = Map.delete(socket.assigns.a2ui_surfaces, sid)
        {:noreply, Phoenix.Component.assign(socket, :a2ui_surfaces, surfaces)}

      {:error, {:json_decode, reason}} ->
        error = Error.parse_error("JSON decode failed", reason)
        Logger.warning("A2UI parse error: json_decode")
        {:noreply, emit_error(socket, error)}

      {:error, :unknown_message_type} ->
        error = Error.parse_error("Unknown message type")
        Logger.warning("A2UI parse error: unknown_message_type")
        {:noreply, emit_error(socket, error)}

      {:error, reason} ->
        error = Error.parse_error("Parse failed", reason)
        Logger.warning("A2UI parse error: #{inspect(reason)}")
        {:noreply, emit_error(socket, error)}
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
        A2UI.Live.handle_a2ui_event(event, params, socket)
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
      # Resolve all context bindings against current data model
      resolved_context = resolve_action_context(action_context, surface.data_model, scope_path)

      user_action = %{
        "userAction" => %{
          "name" => action_name,
          "surfaceId" => surface_id,
          "sourceComponentId" => component_id,
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "context" => resolved_context
        }
      }

      # Dispatch to callback if configured
      socket =
        if callback = socket.assigns[:a2ui_action_callback] do
          case callback.(user_action, socket) do
            %Phoenix.LiveView.Socket{} = updated_socket -> updated_socket
            {:noreply, %Phoenix.LiveView.Socket{} = updated_socket} -> updated_socket
            _ -> socket
          end
        else
          socket
        end

      {:noreply, Phoenix.Component.assign(socket, :a2ui_last_action, user_action)}
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

  defp update_surface(socket, surface_id, message) do
    surfaces = socket.assigns.a2ui_surfaces
    surface = Map.get(surfaces, surface_id) || Surface.new(surface_id)
    updated = Surface.apply_message(surface, message)

    case Validator.validate_data_model_size(updated.data_model) do
      :ok ->
        Phoenix.Component.assign(socket, :a2ui_surfaces, Map.put(surfaces, surface_id, updated))

      {:error, {:data_model_too_large, size, max}} ->
        error =
          Error.validation_error(
            "Data model too large: #{size} bytes exceeds #{max}",
            surface_id,
            %{"size" => size, "limit" => max}
          )

        Logger.warning("A2UI data model update rejected: data_model_too_large")
        emit_error(socket, error)

      {:error, reason} ->
        error =
          Error.validation_error("Data model validation failed: #{inspect(reason)}", surface_id)

        Logger.warning("A2UI data model update rejected: #{inspect(reason)}")
        emit_error(socket, error)
    end
  end

  defp update_data_at_path(socket, surface_id, path, value) do
    surfaces = socket.assigns.a2ui_surfaces
    surface = surfaces[surface_id]

    if surface do
      updated = Surface.update_data_at_path(surface, path, value)

      case Validator.validate_data_model_size(updated.data_model) do
        :ok ->
          Phoenix.Component.assign(socket, :a2ui_surfaces, Map.put(surfaces, surface_id, updated))

        {:error, {:data_model_too_large, size, max}} ->
          error =
            Error.validation_error(
              "Data model too large: #{size} bytes exceeds #{max}",
              surface_id,
              %{"size" => size, "limit" => max}
            )

          Logger.warning("A2UI local data model update rejected: data_model_too_large")
          emit_error(socket, error)

        {:error, reason} ->
          error = Error.validation_error("Data validation failed: #{inspect(reason)}", surface_id)
          Logger.warning("A2UI local data model update rejected: #{inspect(reason)}")
          emit_error(socket, error)
      end
    else
      socket
    end
  end

  defp resolve_action_context(context_list, data_model, scope_path) do
    Enum.reduce(context_list, %{}, fn
      %{"key" => key, "value" => bound_value}, acc ->
        resolved = Binding.resolve(bound_value, data_model, scope_path)
        Map.put(acc, key, resolved)

      _, acc ->
        acc
    end)
  end

  # Emits an error to the configured callback and stores in assigns for debugging
  defp emit_error(socket, error_map) do
    socket = Phoenix.Component.assign(socket, :a2ui_last_error, error_map)

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
end
