defmodule A2UI.ErrorTest do
  use ExUnit.Case, async: true

  alias A2UI.Error

  describe "build/3" do
    test "creates error with required fields" do
      error = Error.build(:parse_error, "Test message")

      assert %{"error" => inner} = error
      assert inner["type"] == "parse_error"
      assert inner["message"] == "Test message"
      assert is_binary(inner["timestamp"])
      # Verify ISO 8601 format
      assert {:ok, _, _} = DateTime.from_iso8601(inner["timestamp"])
    end

    test "includes surface_id when provided" do
      error = Error.build(:validation_error, "Test", surface_id: "main")

      assert error["error"]["surfaceId"] == "main"
    end

    test "includes component_id when provided" do
      error = Error.build(:render_error, "Test", component_id: "btn-1")

      assert error["error"]["componentId"] == "btn-1"
    end

    test "includes details when provided" do
      details = %{"count" => 100, "limit" => 50}
      error = Error.build(:validation_error, "Test", details: details)

      assert error["error"]["details"] == details
    end

    test "omits nil optional fields" do
      error = Error.build(:parse_error, "Test")

      refute Map.has_key?(error["error"], "surfaceId")
      refute Map.has_key?(error["error"], "componentId")
      refute Map.has_key?(error["error"], "details")
    end

    test "supports all error types" do
      types = [:parse_error, :validation_error, :binding_error, :render_error, :unknown_component]

      for type <- types do
        error = Error.build(type, "Test")
        assert error["error"]["type"] == to_string(type)
      end
    end
  end

  describe "parse_error/2" do
    test "creates parse error with message only" do
      error = Error.parse_error("JSON decode failed")

      assert error["error"]["type"] == "parse_error"
      assert error["error"]["message"] == "JSON decode failed"
      refute Map.has_key?(error["error"], "details")
    end

    test "includes reason in details when provided" do
      error = Error.parse_error("JSON decode failed", %Jason.DecodeError{position: 5})

      assert error["error"]["type"] == "parse_error"
      assert is_binary(error["error"]["details"]["reason"])
    end

    test "formats string reasons directly" do
      error = Error.parse_error("Parse failed", "unexpected token")

      assert error["error"]["details"]["reason"] == "unexpected token"
    end
  end

  describe "validation_error/3" do
    test "creates validation error with message only" do
      error = Error.validation_error("Too many components")

      assert error["error"]["type"] == "validation_error"
      assert error["error"]["message"] == "Too many components"
    end

    test "includes surface_id when provided" do
      error = Error.validation_error("Depth exceeded", "surface-1")

      assert error["error"]["surfaceId"] == "surface-1"
    end

    test "includes details when provided" do
      error = Error.validation_error("Too large", "s1", %{"size" => 200_000})

      assert error["error"]["details"] == %{"size" => 200_000}
    end
  end

  describe "unknown_component/2" do
    test "creates error for single unknown type" do
      error = Error.unknown_component(["Foo"])

      assert error["error"]["type"] == "unknown_component"
      assert error["error"]["message"] == "Unknown component types: Foo"
      assert error["error"]["details"]["types"] == ["Foo"]
    end

    test "creates error for multiple unknown types" do
      error = Error.unknown_component(["Foo", "Bar", "Baz"])

      assert error["error"]["message"] == "Unknown component types: Foo, Bar, Baz"
      assert error["error"]["details"]["types"] == ["Foo", "Bar", "Baz"]
    end

    test "includes surface_id when provided" do
      error = Error.unknown_component(["Foo"], "main-surface")

      assert error["error"]["surfaceId"] == "main-surface"
    end
  end
end
