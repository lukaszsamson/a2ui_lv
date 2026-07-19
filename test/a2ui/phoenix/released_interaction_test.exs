defmodule A2UI.Phoenix.ReleasedInteractionTest do
  use ExUnit.Case, async: true

  alias A2UI.{Component, Session, Surface}
  alias A2UI.Phoenix.Live

  test "mutually exclusive ChoicePicker keeps an array value" do
    surface = %Surface{
      id: "main",
      protocol_version: :v0_9_1,
      data_model: %{"choice" => []},
      components: %{}
    }

    socket = socket_with_surface(surface)

    params = %{
      "a2ui_input" => %{
        "surface_id" => "main",
        "path" => "/choice",
        "values" => ["", "email"],
        "is_single" => "true"
      }
    }

    assert {:noreply, socket} = Live.handle_a2ui_event("a2ui:choice", params, socket)
    assert socket.assigns.a2ui_surfaces["main"].data_model["choice"] == ["email"]
  end

  test "released local function actions execute without dispatching an event" do
    surface = %Surface{
      id: "main",
      protocol_version: :v0_9_1,
      data_model: %{"enabled" => false},
      components: %{
        "button" => %Component{
          id: "button",
          type: "Button",
          props: %{
            "action" => %{
              "functionCall" => %{
                "call" => "not",
                "args" => %{"value" => %{"path" => "/enabled"}},
                "returnType" => "boolean"
              }
            }
          }
        }
      }
    }

    socket = socket_with_surface(surface)

    assert {:noreply, socket} =
             Live.handle_a2ui_event(
               "a2ui:action",
               %{"surface-id" => "main", "component-id" => "button", "scope-path" => ""},
               socket
             )

    assert socket.assigns.a2ui_last_function_result == true
    assert socket.assigns.a2ui_last_action == nil
  end

  defp socket_with_surface(surface) do
    session = %{Session.new() | surfaces: %{surface.id => surface}}

    %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    |> Live.init()
    |> Phoenix.Component.assign(:a2ui_session, session)
    |> Phoenix.Component.assign(:a2ui_surfaces, session.surfaces)
  end
end
