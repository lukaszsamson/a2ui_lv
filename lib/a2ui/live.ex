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

  alias A2UI.{Parser, Surface, Binding}
  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}

  require Logger

  @doc """
  Call this from your LiveView's mount/3 to initialize A2UI state.
  Returns socket with :a2ui_surfaces assign.

  ## Options

  - `:action_callback` - Function called when a user action is triggered.
    Signature: `(user_action, socket) -> any()`

  ## Example

      def mount(_params, _session, socket) do
        socket = A2UI.Live.init(socket, action_callback: &handle_action/2)
        {:ok, socket}
      end
  """
  @spec init(Phoenix.LiveView.Socket.t(), keyword()) :: Phoenix.LiveView.Socket.t()
  def init(socket, opts \\ []) do
    Phoenix.Component.assign(socket,
      a2ui_surfaces: %{},
      a2ui_action_callback: opts[:action_callback],
      a2ui_last_action: nil
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
        {:noreply, update_surface(socket, sid, msg)}

      {:data_model_update, %DataModelUpdate{surface_id: sid} = msg} ->
        {:noreply, update_surface(socket, sid, msg)}

      {:begin_rendering, %BeginRendering{surface_id: sid} = msg} ->
        {:noreply, update_surface(socket, sid, msg)}

      {:delete_surface, %DeleteSurface{surface_id: sid}} ->
        surfaces = Map.delete(socket.assigns.a2ui_surfaces, sid)
        {:noreply, Phoenix.Component.assign(socket, :a2ui_surfaces, surfaces)}

      {:error, reason} ->
        Logger.warning("A2UI parse error: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @doc """
  Handle A2UI user events.
  Call from your LiveView's handle_event/3.

  ## Events

  - `"a2ui:action"` - Button clicks, triggers action callback with resolved context
  - `"a2ui:input"` - TextField changes, updates data model
  - `"a2ui:toggle"` - Checkbox changes, updates data model

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

    if action do
      action_name = action["name"]
      action_context = action["context"] || []

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
      if callback = socket.assigns[:a2ui_action_callback] do
        callback.(user_action, socket)
      end

      {:noreply, Phoenix.Component.assign(socket, :a2ui_last_action, user_action)}
    else
      Logger.warning("A2UI action event for component without action: #{component_id}")
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

  # Private helpers

  defp update_surface(socket, surface_id, message) do
    surfaces = socket.assigns.a2ui_surfaces
    surface = Map.get(surfaces, surface_id) || Surface.new(surface_id)
    updated = Surface.apply_message(surface, message)
    Phoenix.Component.assign(socket, :a2ui_surfaces, Map.put(surfaces, surface_id, updated))
  end

  defp update_data_at_path(socket, surface_id, path, value) do
    surfaces = socket.assigns.a2ui_surfaces
    surface = surfaces[surface_id]

    if surface do
      updated = Surface.update_data_at_path(surface, path, value)
      Phoenix.Component.assign(socket, :a2ui_surfaces, Map.put(surfaces, surface_id, updated))
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
end
