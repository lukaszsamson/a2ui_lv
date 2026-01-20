defmodule A2UI.DynamicValueTest do
  use ExUnit.Case, async: true

  alias A2UI.DynamicValue

  describe "evaluate/4 - literal values" do
    test "returns string literal" do
      assert DynamicValue.evaluate("hello", %{}, nil, []) == "hello"
    end

    test "returns number literal" do
      assert DynamicValue.evaluate(42, %{}, nil, []) == 42
      assert DynamicValue.evaluate(3.14, %{}, nil, []) == 3.14
    end

    test "returns boolean literal" do
      assert DynamicValue.evaluate(true, %{}, nil, []) == true
      assert DynamicValue.evaluate(false, %{}, nil, []) == false
    end

    test "returns nil" do
      assert DynamicValue.evaluate(nil, %{}, nil, []) == nil
    end

    test "returns list literal" do
      assert DynamicValue.evaluate([1, 2, 3], %{}, nil, []) == [1, 2, 3]
    end
  end

  describe "evaluate/4 - v0.8 literal wrappers" do
    test "unwraps literalString" do
      assert DynamicValue.evaluate(%{"literalString" => "hello"}, %{}, nil, []) == "hello"
    end

    test "unwraps literalNumber" do
      assert DynamicValue.evaluate(%{"literalNumber" => 42}, %{}, nil, []) == 42
    end

    test "unwraps literalBoolean" do
      assert DynamicValue.evaluate(%{"literalBoolean" => true}, %{}, nil, []) == true
    end

    test "unwraps literalArray" do
      assert DynamicValue.evaluate(%{"literalArray" => [1, 2]}, %{}, nil, []) == [1, 2]
    end
  end

  describe "evaluate/4 - path binding" do
    test "resolves absolute path" do
      data = %{"user" => %{"name" => "Alice"}}
      assert DynamicValue.evaluate(%{"path" => "/user/name"}, data, nil, []) == "Alice"
    end

    test "resolves relative path with scope" do
      data = %{"items" => [%{"name" => "first"}, %{"name" => "second"}]}
      assert DynamicValue.evaluate(%{"path" => "name"}, data, "/items/0", version: :v0_9) == "first"
    end

    test "returns nil for missing path" do
      assert DynamicValue.evaluate(%{"path" => "/missing"}, %{}, nil, []) == nil
    end

    test "returns literal fallback when path is nil" do
      value = %{"path" => "/missing", "literalString" => "default"}
      assert DynamicValue.evaluate(value, %{}, nil, []) == "default"
    end
  end

  describe "evaluate/4 - FunctionCall" do
    test "evaluates required function" do
      value = %{"call" => "required", "args" => %{"value" => "hello"}, "returnType" => "boolean"}
      assert DynamicValue.evaluate(value, %{}, nil, []) == true

      value_empty = %{"call" => "required", "args" => %{"value" => ""}, "returnType" => "boolean"}
      assert DynamicValue.evaluate(value_empty, %{}, nil, []) == false
    end

    test "evaluates email function" do
      value = %{"call" => "email", "args" => %{"value" => "test@example.com"}, "returnType" => "boolean"}
      assert DynamicValue.evaluate(value, %{}, nil, []) == true

      value_invalid = %{"call" => "email", "args" => %{"value" => "invalid"}, "returnType" => "boolean"}
      assert DynamicValue.evaluate(value_invalid, %{}, nil, []) == false
    end

    test "evaluates regex function" do
      value = %{
        "call" => "regex",
        "args" => %{"value" => "123", "pattern" => "^\\d+$"},
        "returnType" => "boolean"
      }
      assert DynamicValue.evaluate(value, %{}, nil, []) == true
    end

    test "evaluates length function with min/max" do
      value = %{
        "call" => "length",
        "args" => %{"value" => "hello", "min" => 3, "max" => 10},
        "returnType" => "boolean"
      }
      assert DynamicValue.evaluate(value, %{}, nil, []) == true

      value_short = %{
        "call" => "length",
        "args" => %{"value" => "hi", "min" => 3},
        "returnType" => "boolean"
      }
      assert DynamicValue.evaluate(value_short, %{}, nil, []) == false
    end

    test "evaluates numeric function with min/max" do
      value = %{
        "call" => "numeric",
        "args" => %{"value" => 5, "min" => 0, "max" => 10},
        "returnType" => "boolean"
      }
      assert DynamicValue.evaluate(value, %{}, nil, []) == true

      value_out = %{
        "call" => "numeric",
        "args" => %{"value" => 15, "max" => 10},
        "returnType" => "boolean"
      }
      assert DynamicValue.evaluate(value_out, %{}, nil, []) == false
    end

    test "evaluates string_format function" do
      value = %{
        "call" => "string_format",
        "args" => %{"template" => "Hello, ${/name}!"},
        "returnType" => "string"
      }
      data = %{"name" => "Alice"}
      assert DynamicValue.evaluate(value, data, nil, []) == "Hello, Alice!"
    end

    test "evaluates now function" do
      value = %{"call" => "now", "returnType" => "string"}
      result = DynamicValue.evaluate(value, %{}, nil, [])
      # Should be an ISO 8601 timestamp
      assert is_binary(result)
      assert String.contains?(result, "T")
      assert String.contains?(result, "Z") or String.contains?(result, "+")
    end

    test "returns nil for unknown function" do
      value = %{"call" => "unknownFunc", "args" => %{}, "returnType" => "string"}
      assert DynamicValue.evaluate(value, %{}, nil, []) == nil
    end
  end

  describe "evaluate/4 - nested FunctionCall args" do
    test "resolves path binding in args" do
      value = %{
        "call" => "required",
        "args" => %{"value" => %{"path" => "/name"}},
        "returnType" => "boolean"
      }
      data = %{"name" => "Alice"}
      assert DynamicValue.evaluate(value, data, nil, []) == true

      data_empty = %{"name" => ""}
      assert DynamicValue.evaluate(value, data_empty, nil, []) == false
    end

    test "resolves nested FunctionCall in args" do
      # string_format with a path binding inside
      value = %{
        "call" => "required",
        "args" => %{
          "value" => %{
            "call" => "string_format",
            "args" => %{"template" => "${/greeting}"},
            "returnType" => "string"
          }
        },
        "returnType" => "boolean"
      }
      data = %{"greeting" => "Hello"}
      assert DynamicValue.evaluate(value, data, nil, []) == true

      data_empty = %{"greeting" => ""}
      assert DynamicValue.evaluate(value, data_empty, nil, []) == false
    end

    test "handles mixed literal and path args" do
      value = %{
        "call" => "length",
        "args" => %{
          "value" => %{"path" => "/text"},
          "min" => 3,
          "max" => 10
        },
        "returnType" => "boolean"
      }
      data = %{"text" => "hello"}
      assert DynamicValue.evaluate(value, data, nil, []) == true
    end
  end

  describe "evaluate/4 - version-aware path scoping" do
    test "v0.9 treats /path as absolute even with scope" do
      value = %{"path" => "/name"}
      data = %{"name" => "root", "items" => [%{"name" => "item"}]}
      assert DynamicValue.evaluate(value, data, "/items/0", version: :v0_9) == "root"
    end

    test "v0.8 treats /path as scoped in template context" do
      value = %{"path" => "/name"}
      data = %{"name" => "root", "items" => [%{"name" => "item"}]}
      assert DynamicValue.evaluate(value, data, "/items/0", version: :v0_8) == "item"
    end
  end

  describe "function_call?/1" do
    test "returns true for FunctionCall maps" do
      assert DynamicValue.function_call?(%{"call" => "now"}) == true
      assert DynamicValue.function_call?(%{"call" => "required", "args" => %{}}) == true
    end

    test "returns false for path bindings" do
      assert DynamicValue.function_call?(%{"path" => "/name"}) == false
    end

    test "returns false for literals" do
      assert DynamicValue.function_call?("hello") == false
      assert DynamicValue.function_call?(42) == false
      assert DynamicValue.function_call?(true) == false
    end
  end

  describe "Binding.resolve/4 integration" do
    test "Binding.resolve delegates FunctionCall to DynamicValue" do
      value = %{
        "call" => "string_format",
        "args" => %{"template" => "Count: ${/count}"},
        "returnType" => "string"
      }
      data = %{"count" => 42}
      assert A2UI.Binding.resolve(value, data, nil, []) == "Count: 42"
    end

    test "Binding.resolve handles FunctionCall with path args" do
      value = %{
        "call" => "required",
        "args" => %{"value" => %{"path" => "/email"}},
        "returnType" => "boolean"
      }
      data = %{"email" => "test@example.com"}
      assert A2UI.Binding.resolve(value, data, nil, []) == true
    end
  end

  describe "Text component integration (DynamicString with FunctionCall)" do
    @moduledoc """
    Tests that simulate how the Text component resolves its text prop.
    Text component calls: Binding.resolve(props["text"], data_model, scope_path, opts)
    When text prop is a FunctionCall, it should be evaluated.
    """

    test "string_format FunctionCall in text prop" do
      # Simulates: {"text": {"call": "string_format", "args": {"template": "Hello, ${/name}!"}, "returnType": "string"}}
      text_prop = %{
        "call" => "string_format",
        "args" => %{"template" => "Hello, ${/name}!"},
        "returnType" => "string"
      }
      data_model = %{"name" => "Alice"}

      # This is what Text component does:
      result = A2UI.Binding.resolve(text_prop, data_model, nil, [])
      assert result == "Hello, Alice!"
    end

    test "string_format FunctionCall with scoped path in template context" do
      # Simulates rendering Text inside a template with scope_path
      text_prop = %{
        "call" => "string_format",
        "args" => %{"template" => "Item: ${name}"},
        "returnType" => "string"
      }
      data_model = %{"items" => [%{"name" => "First"}, %{"name" => "Second"}]}

      # v0.9: relative path "name" is scoped to template item
      result = A2UI.Binding.resolve(text_prop, data_model, "/items/0", version: :v0_9)
      assert result == "Item: First"

      result = A2UI.Binding.resolve(text_prop, data_model, "/items/1", version: :v0_9)
      assert result == "Item: Second"
    end

    test "now FunctionCall in text prop" do
      # Simulates: {"text": {"call": "now", "returnType": "string"}}
      text_prop = %{
        "call" => "now",
        "returnType" => "string"
      }

      result = A2UI.Binding.resolve(text_prop, %{}, nil, [])
      assert is_binary(result)
      assert String.contains?(result, "T")
      # Verify it's a valid ISO 8601 timestamp
      assert {:ok, _, _} = DateTime.from_iso8601(result)
    end

    test "nested FunctionCall: required wrapping string_format" do
      # Simulates a validation-like pattern with nested calls
      text_prop = %{
        "call" => "string_format",
        "args" => %{
          "template" => "Status: ${/status} - Valid: ${/isValid}"
        },
        "returnType" => "string"
      }
      data_model = %{"status" => "active", "isValid" => true}

      result = A2UI.Binding.resolve(text_prop, data_model, nil, [])
      assert result == "Status: active - Valid: true"
    end

    test "FunctionCall with multiple path interpolations" do
      text_prop = %{
        "call" => "string_format",
        "args" => %{
          "template" => "${/user/firstName} ${/user/lastName} <${/user/email}>"
        },
        "returnType" => "string"
      }
      data_model = %{
        "user" => %{
          "firstName" => "John",
          "lastName" => "Doe",
          "email" => "john@example.com"
        }
      }

      result = A2UI.Binding.resolve(text_prop, data_model, nil, [])
      assert result == "John Doe <john@example.com>"
    end
  end
end
