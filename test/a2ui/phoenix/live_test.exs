defmodule A2UI.Phoenix.LiveTest do
  use A2uiLvWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias A2UI.Phoenix.Live
  alias A2UI.Transport.Local

  describe "init/2 with event transport" do
    test "stores transport configuration in assigns" do
      {:ok, transport} = Local.start_link(event_handler: fn _ -> :ok end)

      # Create a minimal socket-like struct for testing
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      socket = Live.init(socket, event_transport: transport)

      assert socket.assigns[:a2ui_event_transport] == transport
      assert socket.assigns[:a2ui_event_transport_module] == Local
    end

    test "defaults transport module to Local" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      socket = Live.init(socket)

      assert socket.assigns[:a2ui_event_transport] == nil
      assert socket.assigns[:a2ui_event_transport_module] == Local
    end

    test "accepts custom transport module" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      # Use a custom module (even if it's the same as Local for testing)
      socket = Live.init(socket, event_transport_module: A2UI.Transport.Local)

      assert socket.assigns[:a2ui_event_transport_module] == A2UI.Transport.Local
    end
  end

  describe "event transport integration" do
    test "sends userAction via transport when configured" do
      test_pid = self()

      # Create transport that forwards events to test process
      {:ok, transport} =
        Local.start_link(
          event_handler: fn event ->
            send(test_pid, {:transport_event, event})
            :ok
          end
        )

      # Create socket with transport
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      socket = Live.init(socket, event_transport: transport)

      # Create a surface with a button that has an action
      surface_json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"btn","component":{"Button":{"action":{"name":"test_action","context":[]}}}}]}})

      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, surface_json}, socket)

      begin_json = ~s({"beginRendering":{"surfaceId":"test","root":"btn"}})
      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, begin_json}, socket)

      # Trigger the action
      {:noreply, _socket} =
        Live.handle_a2ui_event(
          "a2ui:action",
          %{"surface-id" => "test", "component-id" => "btn", "scope-path" => ""},
          socket
        )

      # Verify event was sent via transport
      assert_receive {:transport_event, event}
      assert event["userAction"]["name"] == "test_action"
      assert event["userAction"]["surfaceId"] == "test"
      assert event["userAction"]["sourceComponentId"] == "btn"
      assert event["userAction"]["context"] == %{}
      assert event["userAction"]["timestamp"] != nil
    end

    test "sends error via transport when configured" do
      test_pid = self()

      {:ok, transport} =
        Local.start_link(
          event_handler: fn event ->
            send(test_pid, {:transport_event, event})
            :ok
          end
        )

      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      socket = Live.init(socket, event_transport: transport)

      # Send invalid JSON to trigger error
      {:noreply, _socket} = Live.handle_a2ui_message({:a2ui, "invalid json"}, socket)

      # Verify error was sent via transport
      assert_receive {:transport_event, event}
      assert event["error"]["type"] == "parse_error"
      assert event["error"]["message"] =~ "JSON decode"
    end

    test "does not fail when transport is not configured" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      socket = Live.init(socket)

      # Create surface with button
      surface_json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"btn","component":{"Button":{"action":"click"}}}]}})

      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, surface_json}, socket)

      begin_json = ~s({"beginRendering":{"surfaceId":"test","root":"btn"}})
      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, begin_json}, socket)

      # Should not crash when triggering action without transport
      {:noreply, socket} =
        Live.handle_a2ui_event(
          "a2ui:action",
          %{"surface-id" => "test", "component-id" => "btn"},
          socket
        )

      # Action should still be recorded locally
      assert socket.assigns[:a2ui_last_action] != nil
    end

    test "calls callback in addition to transport" do
      test_pid = self()

      {:ok, transport} =
        Local.start_link(
          event_handler: fn event ->
            send(test_pid, {:transport_event, event})
            :ok
          end
        )

      callback = fn action, socket ->
        send(test_pid, {:callback_event, action})
        socket
      end

      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      socket = Live.init(socket, event_transport: transport, action_callback: callback)

      # Create surface with button
      surface_json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"btn","component":{"Button":{"action":"click"}}}]}})

      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, surface_json}, socket)

      begin_json = ~s({"beginRendering":{"surfaceId":"test","root":"btn"}})
      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, begin_json}, socket)

      {:noreply, _socket} =
        Live.handle_a2ui_event(
          "a2ui:action",
          %{"surface-id" => "test", "component-id" => "btn"},
          socket
        )

      # Both transport and callback should receive the event
      assert_receive {:transport_event, _event}
      assert_receive {:callback_event, _action}
    end
  end

  describe "v0.9 action context resolution" do
    test "v0.9 surface uses absolute path scoping in action context" do
      test_pid = self()

      {:ok, transport} =
        Local.start_link(
          event_handler: fn event ->
            send(test_pid, {:transport_event, event})
            :ok
          end
        )

      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      socket = Live.init(socket, event_transport: transport)

      # Set up data model with root and scoped values
      data_json =
        ~s({"updateDataModel":{"surfaceId":"test","value":{"name":"root_name","items":[{"name":"item_name"}]}}})

      # Create v0.9 surface with createSurface
      catalog_id = A2UI.V0_8.standard_catalog_id()
      create_json = ~s({"createSurface":{"surfaceId":"test","catalogId":"#{catalog_id}"}})

      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, create_json}, socket)
      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, data_json}, socket)

      # v0.9 component format with action context that uses absolute path /name
      component_json = ~s({"updateComponents":{"surfaceId":"test","components":[
        {"id":"root","component":"Column","children":["btn"]},
        {"id":"btn","component":"Button","action":{
          "name":"test_action",
          "context":[
            {"key":"abs_name","value":{"path":"/name"}},
            {"key":"rel_name","value":{"path":"name"}}
          ]
        }}
      ]}})

      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, component_json}, socket)

      # Verify the surface has v0.9 protocol version
      surface = socket.assigns.a2ui_surfaces["test"]
      assert surface.protocol_version == :v0_9

      # Trigger action with scope_path /items/0
      {:noreply, _socket} =
        Live.handle_a2ui_event(
          "a2ui:action",
          %{"surface-id" => "test", "component-id" => "btn", "scope-path" => "/items/0"},
          socket
        )

      assert_receive {:transport_event, event}

      # v0.9: /name is absolute -> resolves to root "root_name"
      # v0.9: name (relative) -> scoped to /items/0/name -> "item_name"
      assert event["action"]["context"]["abs_name"] == "root_name"
      assert event["action"]["context"]["rel_name"] == "item_name"
    end

    test "v0.8 surface uses scoped path resolution in action context" do
      test_pid = self()

      {:ok, transport} =
        Local.start_link(
          event_handler: fn event ->
            send(test_pid, {:transport_event, event})
            :ok
          end
        )

      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      socket = Live.init(socket, event_transport: transport)

      # Create v0.8 surface with beginRendering
      begin_json = ~s({"beginRendering":{"surfaceId":"test","root":"btn"}})
      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, begin_json}, socket)

      # Set up data model - set root value and scoped value at /items/0
      root_data_json = ~s({"dataModelUpdate":{"surfaceId":"test","contents":[
        {"key":"name","valueString":"root_name"}
      ]}})
      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, root_data_json}, socket)

      # Use path-based update to set nested value
      nested_data_json = ~s({"dataModelUpdate":{"surfaceId":"test","path":"/items/0","contents":[
        {"key":"name","valueString":"item_name"}
      ]}})
      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, nested_data_json}, socket)

      # Verify data model structure
      surface = socket.assigns.a2ui_surfaces["test"]
      assert surface.data_model["name"] == "root_name"
      # items is a list, so items/0 creates %{"items" => [%{"name" => "item_name"}]}
      assert hd(surface.data_model["items"])["name"] == "item_name"

      # v0.8 component with action context using /name (should be scoped in v0.8)
      component_json = ~s({"surfaceUpdate":{"surfaceId":"test","components":[
        {"id":"btn","component":{"Button":{"action":{
          "name":"test_action",
          "context":[
            {"key":"scoped_name","value":{"path":"/name"}}
          ]
        }}}}
      ]}})

      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, component_json}, socket)

      # Verify the surface has v0.8 protocol version
      assert surface.protocol_version == :v0_8

      # Trigger action with scope_path /items/0
      # In v0.8, /name should be scoped to /items/0/name
      {:noreply, _socket} =
        Live.handle_a2ui_event(
          "a2ui:action",
          %{"surface-id" => "test", "component-id" => "btn", "scope-path" => "/items/0"},
          socket
        )

      assert_receive {:transport_event, event}

      # v0.8 sends userAction envelope
      assert Map.has_key?(event, "userAction")

      # v0.8: /name is scoped -> resolves to /items/0/name -> "item_name"
      assert event["userAction"]["context"]["scoped_name"] == "item_name"
    end

    test "v0.9 sends action envelope instead of userAction" do
      test_pid = self()

      {:ok, transport} =
        Local.start_link(
          event_handler: fn event ->
            send(test_pid, {:transport_event, event})
            :ok
          end
        )

      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      }

      socket = Live.init(socket, event_transport: transport)

      # Create v0.9 surface
      catalog_id = A2UI.V0_8.standard_catalog_id()
      create_json = ~s({"createSurface":{"surfaceId":"test","catalogId":"#{catalog_id}"}})
      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, create_json}, socket)

      # v0.9 component format
      component_json = ~s({"updateComponents":{"surfaceId":"test","components":[
        {"id":"root","component":"Button","action":"click"}
      ]}})

      {:noreply, socket} = Live.handle_a2ui_message({:a2ui, component_json}, socket)

      {:noreply, _socket} =
        Live.handle_a2ui_event(
          "a2ui:action",
          %{"surface-id" => "test", "component-id" => "root"},
          socket
        )

      assert_receive {:transport_event, event}

      # v0.9 uses "action" key, not "userAction"
      assert Map.has_key?(event, "action")
      refute Map.has_key?(event, "userAction")
      assert event["action"]["name"] == "click"
    end
  end

  describe "error callback" do
    test "emits error on JSON parse failure", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

      # Send invalid JSON
      send(view.pid, {:a2ui, "not valid json"})

      # Re-render to process the message
      _html = render(view)

      # Check that error was stored in assigns (visible in debug panel if enabled)
      # The error should be available in the socket assigns
      assert :sys.get_state(view.pid).socket.assigns[:a2ui_last_error] != nil

      error = :sys.get_state(view.pid).socket.assigns[:a2ui_last_error]
      assert error["error"]["type"] == "parse_error"
      assert error["error"]["message"] =~ "JSON decode"
    end

    test "emits error on unknown message type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

      # Send valid JSON but unknown message type
      send(view.pid, {:a2ui, ~s({"unknownMessageType": {}})})

      render(view)

      error = :sys.get_state(view.pid).socket.assigns[:a2ui_last_error]
      assert error["error"]["type"] == "parse_error"
      assert error["error"]["message"] =~ "Unknown message type"
    end

    test "emits error on unknown component type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

      # Send surface update with unknown component type
      send(
        view.pid,
        {:a2ui,
         ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"UnknownWidget":{}}}]}})}
      )

      render(view)

      error = :sys.get_state(view.pid).socket.assigns[:a2ui_last_error]
      assert error["error"]["type"] == "unknown_component"
      assert error["error"]["message"] =~ "UnknownWidget"
      assert error["error"]["surfaceId"] == "test"
      assert "UnknownWidget" in error["error"]["details"]["types"]
    end

    test "emits error on too many components", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

      # Generate more than max_components (1000)
      components =
        1..1001
        |> Enum.map(fn i ->
          ~s({"id":"c#{i}","component":{"Text":{"text":{"literalString":"text"}}}})
        end)
        |> Enum.join(",")

      send(
        view.pid,
        {:a2ui, ~s({"surfaceUpdate":{"surfaceId":"test","components":[#{components}]}})}
      )

      render(view)

      error = :sys.get_state(view.pid).socket.assigns[:a2ui_last_error]
      assert error["error"]["type"] == "validation_error"
      assert error["error"]["message"] =~ "Too many components"
      assert error["error"]["surfaceId"] == "test"
      assert error["error"]["details"]["count"] == 1001
      assert error["error"]["details"]["limit"] == 1000
    end

    test "does not emit error for valid messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

      # Send valid surface update
      send(
        view.pid,
        {:a2ui,
         ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello"}}}}]}})}
      )

      render(view)

      # No error should be set
      assert :sys.get_state(view.pid).socket.assigns[:a2ui_last_error] == nil
    end

    test "error includes timestamp in ISO 8601 format", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

      send(view.pid, {:a2ui, "invalid"})
      render(view)

      error = :sys.get_state(view.pid).socket.assigns[:a2ui_last_error]
      assert {:ok, _, _} = DateTime.from_iso8601(error["error"]["timestamp"])
    end
  end
end
