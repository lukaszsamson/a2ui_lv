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
