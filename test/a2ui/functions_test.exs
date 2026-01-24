defmodule A2UI.FunctionsTest do
  use ExUnit.Case, async: true

  alias A2UI.Functions

  describe "required/1" do
    test "returns true for non-empty string" do
      assert Functions.required("hello") == true
    end

    test "returns false for empty string" do
      assert Functions.required("") == false
    end

    test "returns false for nil" do
      assert Functions.required(nil) == false
    end

    test "returns false for empty list" do
      assert Functions.required([]) == false
    end

    test "returns false for empty map" do
      assert Functions.required(%{}) == false
    end

    test "returns true for non-empty list" do
      assert Functions.required([1, 2, 3]) == true
    end

    test "returns true for non-empty map" do
      assert Functions.required(%{"key" => "value"}) == true
    end

    test "returns true for zero" do
      assert Functions.required(0) == true
    end

    test "returns false for false boolean (unchecked checkbox)" do
      # false represents unchecked checkbox, which fails required
      assert Functions.required(false) == false
    end

    test "returns true for true boolean (checked checkbox)" do
      assert Functions.required(true) == true
    end

    test "returns true for whitespace-only string" do
      # Whitespace is considered "present" - not empty
      assert Functions.required("   ") == true
    end
  end

  describe "regex/2" do
    test "returns true when value matches pattern" do
      assert Functions.regex("hello123", "^[a-z]+\\d+$") == true
    end

    test "returns false when value does not match pattern" do
      assert Functions.regex("hello", "^\\d+$") == false
    end

    test "returns false for nil value" do
      assert Functions.regex(nil, ".*") == false
    end

    test "returns false for invalid regex pattern" do
      assert Functions.regex("test", "[invalid(") == false
    end

    test "handles case-sensitive matching" do
      assert Functions.regex("Hello", "^hello$") == false
      assert Functions.regex("Hello", "^[Hh]ello$") == true
    end

    test "converts non-string values to string" do
      assert Functions.regex(123, "^\\d+$") == true
    end

    test "matches partial strings without anchors" do
      assert Functions.regex("hello world", "world") == true
    end
  end

  describe "length/2" do
    test "returns true when string length meets min constraint" do
      assert Functions.length("hello", min: 3) == true
    end

    test "returns false when string length is below min" do
      assert Functions.length("hi", min: 3) == false
    end

    test "returns true when string length meets max constraint" do
      assert Functions.length("hello", max: 10) == true
    end

    test "returns false when string length exceeds max" do
      assert Functions.length("hello world", max: 5) == false
    end

    test "returns true when length is within min and max" do
      assert Functions.length("hello", min: 3, max: 10) == true
    end

    test "returns false when length is outside min and max" do
      assert Functions.length("hi", min: 3, max: 10) == false
      assert Functions.length("hello world!", min: 3, max: 10) == false
    end

    test "returns false for nil value" do
      assert Functions.length(nil, min: 0) == false
    end

    test "works with lists" do
      assert Functions.length([1, 2, 3], min: 2) == true
      assert Functions.length([1], min: 2) == false
      assert Functions.length([1, 2, 3], max: 5) == true
      assert Functions.length([1, 2, 3, 4, 5, 6], max: 5) == false
    end

    test "handles unicode characters correctly" do
      # "héllo" has 5 characters (not 6 bytes)
      assert Functions.length("héllo", min: 5, max: 5) == true
    end

    test "returns true with no constraints" do
      assert Functions.length("anything", []) == true
    end
  end

  describe "numeric/2" do
    test "returns true when number meets min constraint" do
      assert Functions.numeric(5, min: 0) == true
    end

    test "returns false when number is below min" do
      assert Functions.numeric(-1, min: 0) == false
    end

    test "returns true when number meets max constraint" do
      assert Functions.numeric(5, max: 10) == true
    end

    test "returns false when number exceeds max" do
      assert Functions.numeric(15, max: 10) == false
    end

    test "returns true when number is within min and max" do
      assert Functions.numeric(5, min: 0, max: 10) == true
    end

    test "returns false when number is outside min and max" do
      assert Functions.numeric(-1, min: 0, max: 10) == false
      assert Functions.numeric(15, min: 0, max: 10) == false
    end

    test "returns false for nil value" do
      assert Functions.numeric(nil, min: 0) == false
    end

    test "works with floats" do
      assert Functions.numeric(3.14, min: 3.0, max: 4.0) == true
      assert Functions.numeric(2.5, min: 3.0) == false
    end

    test "parses string numbers" do
      assert Functions.numeric("5", min: 0, max: 10) == true
      assert Functions.numeric("3.14", min: 3.0, max: 4.0) == true
    end

    test "returns false for non-numeric strings" do
      assert Functions.numeric("abc", min: 0) == false
    end

    test "inclusive bounds" do
      assert Functions.numeric(0, min: 0) == true
      assert Functions.numeric(10, max: 10) == true
    end
  end

  describe "email/1" do
    test "returns true for valid email" do
      assert Functions.email("test@example.com") == true
    end

    test "returns true for email with subdomain" do
      assert Functions.email("user@mail.example.com") == true
    end

    test "returns true for email with plus tag" do
      assert Functions.email("user+tag@example.com") == true
    end

    test "returns true for email with dots in local part" do
      assert Functions.email("first.last@example.com") == true
    end

    test "returns true for email with country TLD" do
      assert Functions.email("user@domain.co.uk") == true
    end

    test "returns false for nil" do
      assert Functions.email(nil) == false
    end

    test "returns false for empty string" do
      assert Functions.email("") == false
    end

    test "returns false for string without @" do
      assert Functions.email("invalid") == false
    end

    test "returns false for string with @ but no domain" do
      assert Functions.email("user@") == false
    end

    test "returns false for string starting with @" do
      assert Functions.email("@domain.com") == false
    end

    test "returns false for string with spaces" do
      assert Functions.email("user @example.com") == false
    end

    test "returns false for non-string value" do
      assert Functions.email(123) == false
    end
  end

  describe "string_format/4 - basic interpolation" do
    test "returns empty string for nil template" do
      assert Functions.string_format(nil, %{}, nil) == ""
    end

    test "returns empty string for empty template" do
      assert Functions.string_format("", %{}, nil) == ""
    end

    test "returns template as-is when no expressions" do
      assert Functions.string_format("Hello, world!", %{}, nil) == "Hello, world!"
    end

    test "interpolates absolute path" do
      data = %{"name" => "Alice"}
      assert Functions.string_format("Hello, ${/name}!", data, nil) == "Hello, Alice!"
    end

    test "interpolates relative path with scope" do
      data = %{"items" => [%{"name" => "Item 1"}]}
      assert Functions.string_format("Name: ${name}", data, "/items/0") == "Name: Item 1"
    end

    test "interpolates multiple expressions" do
      data = %{"first" => "John", "last" => "Doe"}
      assert Functions.string_format("${/first} ${/last}", data, nil) == "John Doe"
    end

    test "handles missing paths as empty string" do
      data = %{}
      assert Functions.string_format("Value: ${/missing}", data, nil) == "Value: "
    end

    test "handles escaped ${ as literal" do
      assert Functions.string_format("Use \\${var} syntax", %{}, nil) == "Use ${var} syntax"
    end

    test "interpolates numbers" do
      data = %{"count" => 42}
      assert Functions.string_format("Count: ${/count}", data, nil) == "Count: 42"
    end

    test "interpolates booleans" do
      data = %{"active" => true, "disabled" => false}

      assert Functions.string_format("Active: ${/active}, Disabled: ${/disabled}", data, nil) ==
               "Active: true, Disabled: false"
    end

    test "interpolates nested paths" do
      data = %{"user" => %{"profile" => %{"name" => "Alice"}}}
      assert Functions.string_format("Name: ${/user/profile/name}", data, nil) == "Name: Alice"
    end
  end

  describe "string_format/4 - v0.9 path scoping" do
    test "v0.9 treats /path as absolute even with scope" do
      data = %{"name" => "root", "items" => [%{"name" => "item"}]}
      # In v0.9, /name is absolute -> "root"
      assert Functions.string_format("${/name}", data, "/items/0", version: :v0_9) == "root"
    end

    test "v0.9 treats path without / as relative" do
      data = %{"name" => "root", "items" => [%{"name" => "item"}]}
      # In v0.9, name (no leading /) is relative -> scoped to /items/0/name
      assert Functions.string_format("${name}", data, "/items/0", version: :v0_9) == "item"
    end

    test "v0.8 treats /path as scoped in template context" do
      data = %{"name" => "root", "items" => [%{"name" => "item"}]}
      # In v0.8, /name is scoped -> /items/0/name -> "item"
      assert Functions.string_format("${/name}", data, "/items/0", version: :v0_8) == "item"
    end
  end

  describe "string_format/4 - function calls" do
    test "calls required function" do
      data = %{"value" => "hello"}
      assert Functions.string_format("${required(${/value})}", data, nil) == "true"

      data_empty = %{"value" => ""}
      assert Functions.string_format("${required(${/value})}", data_empty, nil) == "false"
    end

    test "calls email function" do
      data = %{"email" => "test@example.com"}
      assert Functions.string_format("${email(${/email})}", data, nil) == "true"

      data_invalid = %{"email" => "invalid"}
      assert Functions.string_format("${email(${/email})}", data_invalid, nil) == "false"
    end

    test "calls regex function with pattern" do
      data = %{"phone" => "123-456-7890"}

      assert Functions.string_format("${regex(${/phone}, '^\\d{3}-\\d{3}-\\d{4}$')}", data, nil) ==
               "true"
    end

    test "handles literal string arguments" do
      assert Functions.string_format("${required('hello')}", %{}, nil) == "true"
      assert Functions.string_format("${required('')}", %{}, nil) == "false"
    end

    test "handles literal number arguments" do
      assert Functions.string_format("${numeric(5, 0, 10)}", %{}, nil) == "true"
      assert Functions.string_format("${numeric(15, 0, 10)}", %{}, nil) == "false"
    end

    test "handles unknown functions as empty" do
      assert Functions.string_format("${unknownFunc()}", %{}, nil) == ""
      assert Functions.string_format("${unknownFunc('arg')}", %{}, nil) == ""
    end

    test "handles nested string_format call" do
      data = %{"template" => "Hi ${/name}", "name" => "Bob"}
      assert Functions.string_format("${string_format(${/template})}", data, nil) == "Hi Bob"
    end

    test "calls now() function - returns ISO 8601 timestamp" do
      result = Functions.string_format("${now()}", %{}, nil)
      # Should be an ISO 8601 timestamp
      assert is_binary(result)
      assert String.contains?(result, "T")
      assert String.contains?(result, "Z") or String.contains?(result, "+")
      # Verify it's a valid timestamp
      assert {:ok, _, _} = DateTime.from_iso8601(result)
    end

    test "calls now() function - in mixed template" do
      result = Functions.string_format("Generated at: ${now()}", %{}, nil)
      assert String.starts_with?(result, "Generated at: 20")
      # Extract the timestamp part and verify it's valid
      timestamp = String.replace_prefix(result, "Generated at: ", "")
      assert {:ok, _, _} = DateTime.from_iso8601(timestamp)
    end

    test "calls now() function - combined with path interpolation" do
      data = %{"name" => "Report"}
      result = Functions.string_format("${/name} - ${now()}", data, nil)
      assert String.starts_with?(result, "Report - 20")
    end
  end

  describe "string_format/4 - edge cases" do
    test "handles unclosed expression gracefully" do
      # Unclosed ${ should be output as literal
      assert Functions.string_format("Start ${unclosed", %{}, nil) == "Start ${unclosed"
    end

    test "handles nested braces in expressions" do
      data = %{"obj" => %{"key" => "value"}}
      assert Functions.string_format("${/obj}", data, nil) == ~s({"key":"value"})
    end

    test "handles arrays in interpolation" do
      data = %{"items" => [1, 2, 3]}
      assert Functions.string_format("Items: ${/items}", data, nil) == "Items: [1,2,3]"
    end

    test "handles special characters in paths" do
      data = %{"a/b" => "slash", "c~d" => "tilde"}
      # JSON Pointer escaping: ~1 for /, ~0 for ~
      assert Functions.string_format("${/a~1b}", data, nil) == "slash"
      assert Functions.string_format("${/c~0d}", data, nil) == "tilde"
    end

    test "handles mixed content" do
      data = %{"name" => "World", "count" => 3}

      result =
        Functions.string_format(
          "Hello ${/name}! You have ${/count} messages. \\${escaped}",
          data,
          nil
        )

      assert result == "Hello World! You have 3 messages. ${escaped}"
    end
  end
end
