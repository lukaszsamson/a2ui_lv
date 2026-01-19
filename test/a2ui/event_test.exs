defmodule A2UI.EventTest do
  use ExUnit.Case, async: true

  alias A2UI.Event

  describe "build_action/2" do
    test "builds v0.8 userAction envelope" do
      event =
        Event.build_action(:v0_8,
          name: "submit",
          surface_id: "main",
          component_id: "btn1",
          context: %{"formData" => %{"name" => "Alice"}}
        )

      assert %{"userAction" => payload} = event
      assert payload["name"] == "submit"
      assert payload["surfaceId"] == "main"
      assert payload["sourceComponentId"] == "btn1"
      assert payload["context"] == %{"formData" => %{"name" => "Alice"}}
      assert is_binary(payload["timestamp"])
    end

    test "builds v0.9 action envelope" do
      event =
        Event.build_action(:v0_9,
          name: "submit",
          surface_id: "main",
          component_id: "btn1",
          context: %{"formData" => %{"name" => "Alice"}}
        )

      assert %{"action" => payload} = event
      assert payload["name"] == "submit"
      assert payload["surfaceId"] == "main"
      assert payload["sourceComponentId"] == "btn1"
      assert payload["context"] == %{"formData" => %{"name" => "Alice"}}
      assert is_binary(payload["timestamp"])
    end

    test "defaults context to empty map" do
      event =
        Event.build_action(:v0_9,
          name: "click",
          surface_id: "main",
          component_id: "btn1"
        )

      assert %{"action" => payload} = event
      assert payload["context"] == %{}
    end

    test "allows custom timestamp" do
      custom_timestamp = "2024-01-15T10:30:00Z"

      event =
        Event.build_action(:v0_9,
          name: "click",
          surface_id: "main",
          component_id: "btn1",
          timestamp: custom_timestamp
        )

      assert %{"action" => payload} = event
      assert payload["timestamp"] == custom_timestamp
    end

    test "defaults to v0.8 for unknown version" do
      event =
        Event.build_action(:unknown,
          name: "click",
          surface_id: "main",
          component_id: "btn1"
        )

      assert %{"userAction" => _} = event
    end
  end

  describe "action_envelope_key/1" do
    test "returns userAction for v0.8" do
      assert "userAction" = Event.action_envelope_key(:v0_8)
    end

    test "returns action for v0.9" do
      assert "action" = Event.action_envelope_key(:v0_9)
    end

    test "defaults to userAction for unknown" do
      assert "userAction" = Event.action_envelope_key(:v0_10)
    end
  end

  describe "validation_failed/3" do
    test "builds VALIDATION_FAILED error envelope" do
      error = Event.validation_failed("main", "/email", "Invalid email format")

      assert %{"error" => payload} = error
      assert payload["code"] == "VALIDATION_FAILED"
      assert payload["surfaceId"] == "main"
      assert payload["path"] == "/email"
      assert payload["message"] == "Invalid email format"
    end

    test "does not include additional fields" do
      error = Event.validation_failed("main", "/email", "Invalid")

      assert %{"error" => payload} = error
      assert map_size(payload) == 4
    end
  end

  describe "generic_error/4" do
    test "builds generic error envelope" do
      error = Event.generic_error("RENDER_ERROR", "main", "Component failed to render")

      assert %{"error" => payload} = error
      assert payload["code"] == "RENDER_ERROR"
      assert payload["surfaceId"] == "main"
      assert payload["message"] == "Component failed to render"
    end

    test "merges additional details" do
      error =
        Event.generic_error("PARSE_ERROR", "main", "Invalid JSON",
          details: %{"line" => 5, "column" => 10}
        )

      assert %{"error" => payload} = error
      assert payload["code"] == "PARSE_ERROR"
      assert payload["surfaceId"] == "main"
      assert payload["message"] == "Invalid JSON"
      assert payload["line"] == 5
      assert payload["column"] == 10
    end

    test "ignores non-map details" do
      error = Event.generic_error("ERROR", "main", "Message", details: "not a map")

      assert %{"error" => payload} = error
      assert map_size(payload) == 3
    end
  end

  describe "detect_version/1" do
    test "detects v0.9 from action envelope" do
      assert :v0_9 = Event.detect_version(%{"action" => %{}})
    end

    test "detects v0.8 from userAction envelope" do
      assert :v0_8 = Event.detect_version(%{"userAction" => %{}})
    end

    test "returns unknown for error envelope" do
      assert :unknown = Event.detect_version(%{"error" => %{}})
    end

    test "returns unknown for unrecognized envelope" do
      assert :unknown = Event.detect_version(%{"other" => %{}})
      assert :unknown = Event.detect_version(%{})
      assert :unknown = Event.detect_version("not a map")
    end
  end

  describe "envelope_type/1" do
    test "returns :action for v0.9 action envelope" do
      assert :action = Event.envelope_type(%{"action" => %{}})
    end

    test "returns :action for v0.8 userAction envelope" do
      assert :action = Event.envelope_type(%{"userAction" => %{}})
    end

    test "returns :error for error envelope" do
      assert :error = Event.envelope_type(%{"error" => %{}})
    end

    test "returns :unknown for other envelopes" do
      assert :unknown = Event.envelope_type(%{"other" => %{}})
      assert :unknown = Event.envelope_type(%{})
    end
  end
end
