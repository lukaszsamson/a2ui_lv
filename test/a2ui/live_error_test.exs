defmodule A2UI.LiveErrorTest do
  use A2uiLvWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "error callback" do
    test "emits error on JSON parse failure", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

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
      {:ok, view, _html} = live(conn, "/demo")

      # Send valid JSON but unknown message type
      send(view.pid, {:a2ui, ~s({"unknownMessageType": {}})})

      render(view)

      error = :sys.get_state(view.pid).socket.assigns[:a2ui_last_error]
      assert error["error"]["type"] == "parse_error"
      assert error["error"]["message"] =~ "Unknown message type"
    end

    test "emits error on unknown component type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

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
      {:ok, view, _html} = live(conn, "/demo")

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
      {:ok, view, _html} = live(conn, "/demo")

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
      {:ok, view, _html} = live(conn, "/demo")

      send(view.pid, {:a2ui, "invalid"})
      render(view)

      error = :sys.get_state(view.pid).socket.assigns[:a2ui_last_error]
      assert {:ok, _, _} = DateTime.from_iso8601(error["error"]["timestamp"])
    end
  end
end
