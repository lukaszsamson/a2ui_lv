defmodule A2UI.Transport.EventsTest do
  use ExUnit.Case, async: true

  alias A2UI.Transport.Events

  describe "validate_envelope/1" do
    test "accepts valid v0.8 userAction envelope" do
      envelope = %{
        "userAction" => %{
          "name" => "click",
          "surfaceId" => "test",
          "sourceComponentId" => "btn",
          "timestamp" => "2024-01-15T10:00:00Z",
          "context" => %{}
        }
      }

      assert :ok = Events.validate_envelope(envelope)
    end

    test "accepts valid v0.9 action envelope" do
      envelope = %{
        "action" => %{
          "name" => "click",
          "surfaceId" => "test",
          "sourceComponentId" => "btn",
          "timestamp" => "2024-01-15T10:00:00Z",
          "context" => %{}
        }
      }

      assert :ok = Events.validate_envelope(envelope)
    end

    test "accepts valid error envelope" do
      envelope = %{
        "error" => %{
          "type" => "validation_error",
          "message" => "Something went wrong",
          "surfaceId" => "test",
          "timestamp" => "2024-01-15T10:00:00Z"
        }
      }

      assert :ok = Events.validate_envelope(envelope)
    end

    test "accepts valid v0.9 VALIDATION_FAILED error envelope" do
      envelope = %{
        "error" => %{
          "code" => "VALIDATION_FAILED",
          "surfaceId" => "test",
          "path" => "/email",
          "message" => "Invalid email format"
        }
      }

      assert :ok = Events.validate_envelope(envelope)
    end

    test "rejects envelope with multiple keys" do
      envelope = %{
        "userAction" => %{"name" => "click"},
        "error" => %{"type" => "error"}
      }

      assert {:error, :multiple_envelope_keys} = Events.validate_envelope(envelope)
    end

    test "rejects empty envelope" do
      assert {:error, :multiple_envelope_keys} = Events.validate_envelope(%{})
    end

    test "rejects envelope with unknown type" do
      envelope = %{"unknownType" => %{"data" => "value"}}

      assert {:error, :invalid_envelope_type} = Events.validate_envelope(envelope)
    end

    test "rejects non-map envelope" do
      assert {:error, :not_a_map} = Events.validate_envelope("not a map")
      assert {:error, :not_a_map} = Events.validate_envelope(nil)
      assert {:error, :not_a_map} = Events.validate_envelope([])
    end
  end

  describe "envelope_type/1" do
    test "returns :action for v0.8 userAction envelope" do
      envelope = %{"userAction" => %{"name" => "click"}}
      assert :action = Events.envelope_type(envelope)
    end

    test "returns :action for v0.9 action envelope" do
      envelope = %{"action" => %{"name" => "click"}}
      assert :action = Events.envelope_type(envelope)
    end

    test "returns :error for error envelope" do
      envelope = %{"error" => %{"type" => "validation_error"}}
      assert :error = Events.envelope_type(envelope)
    end

    test "returns :unknown for other envelopes" do
      assert :unknown = Events.envelope_type(%{"other" => %{}})
      assert :unknown = Events.envelope_type(%{})
      assert :unknown = Events.envelope_type("not a map")
    end
  end
end
