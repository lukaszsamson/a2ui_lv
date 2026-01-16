defmodule A2UI.BindingTest do
  use ExUnit.Case, async: true

  alias A2UI.Binding

  describe "resolve/3" do
    test "resolves literal string" do
      assert Binding.resolve(%{"literalString" => "hello"}, %{}, nil) == "hello"
    end

    test "resolves literal number" do
      assert Binding.resolve(%{"literalNumber" => 42}, %{}, nil) == 42
    end

    test "resolves literal boolean" do
      assert Binding.resolve(%{"literalBoolean" => true}, %{}, nil) == true
      assert Binding.resolve(%{"literalBoolean" => false}, %{}, nil) == false
    end

    test "resolves literal array" do
      assert Binding.resolve(%{"literalArray" => [1, 2, 3]}, %{}, nil) == [1, 2, 3]
    end

    test "resolves path against data model" do
      data = %{"user" => %{"name" => "Alice"}}
      assert Binding.resolve(%{"path" => "/user/name"}, data, nil) == "Alice"
    end

    test "resolves nested path" do
      data = %{"form" => %{"contact" => %{"email" => "test@example.com"}}}
      assert Binding.resolve(%{"path" => "/form/contact/email"}, data, nil) == "test@example.com"
    end

    test "returns nil for missing path" do
      assert Binding.resolve(%{"path" => "/missing"}, %{}, nil) == nil
    end

    test "returns nil for partial missing path" do
      data = %{"user" => %{"name" => "Alice"}}
      assert Binding.resolve(%{"path" => "/user/missing/deep"}, data, nil) == nil
    end

    test "returns literal fallback when path is nil" do
      bound = %{"path" => "/missing", "literalString" => "default"}
      assert Binding.resolve(bound, %{}, nil) == "default"
    end

    test "returns literal array fallback when path is nil" do
      bound = %{"path" => "/missing", "literalArray" => [1, 2, 3]}
      assert Binding.resolve(bound, %{}, nil) == [1, 2, 3]
    end

    test "returns path value when both path and literal exist" do
      data = %{"user" => %{"name" => "Alice"}}
      bound = %{"path" => "/user/name", "literalString" => "default"}
      assert Binding.resolve(bound, data, nil) == "Alice"
    end

    test "resolves relative path with scope_path (v0.9 style)" do
      data = %{"items" => [%{"name" => "first"}, %{"name" => "second"}]}
      assert Binding.resolve(%{"path" => "name"}, data, "/items/0") == "first"
      assert Binding.resolve(%{"path" => "name"}, data, "/items/1") == "second"
    end

    test "resolves absolute path in scope context (v0.8 template style)" do
      data = %{"items" => [%{"name" => "first"}, %{"name" => "second"}]}
      assert Binding.resolve(%{"path" => "/name"}, data, "/items/0") == "first"
      assert Binding.resolve(%{"path" => "/name"}, data, "/items/1") == "second"
    end

    test "resolves ./ relative path" do
      data = %{"items" => [%{"details" => %{"price" => 100}}]}
      assert Binding.resolve(%{"path" => "./details/price"}, data, "/items/0") == 100
    end

    test "passes through direct string values" do
      assert Binding.resolve("direct string", %{}, nil) == "direct string"
    end

    test "passes through direct number values" do
      assert Binding.resolve(42, %{}, nil) == 42
    end

    test "passes through direct boolean values" do
      assert Binding.resolve(true, %{}, nil) == true
    end

    test "passes through nil" do
      assert Binding.resolve(nil, %{}, nil) == nil
    end
  end

  describe "resolve/4 with version options" do
    test "v0.8: path starting with / is scoped in template context" do
      data = %{"items" => [%{"name" => "scoped_value"}], "name" => "root_value"}

      # v0.8: /name in scope /items/0 resolves to /items/0/name
      bound = %{"path" => "/name"}
      assert Binding.resolve(bound, data, "/items/0", version: :v0_8) == "scoped_value"
    end

    test "v0.9: path starting with / is absolute even in template context" do
      data = %{"items" => [%{"name" => "scoped_value"}], "name" => "root_value"}

      # v0.9: /name in scope /items/0 still resolves to root /name
      bound = %{"path" => "/name"}
      assert Binding.resolve(bound, data, "/items/0", version: :v0_9) == "root_value"
    end

    test "v0.9: relative path (no /) is scoped in template context" do
      data = %{"items" => [%{"name" => "scoped_value"}], "name" => "root_value"}

      # v0.9: name (no /) in scope /items/0 resolves to /items/0/name
      bound = %{"path" => "name"}
      assert Binding.resolve(bound, data, "/items/0", version: :v0_9) == "scoped_value"
    end

    test "version defaults to v0_8 when not specified" do
      data = %{"items" => [%{"name" => "scoped_value"}], "name" => "root_value"}

      # Default (v0.8): /name in scope /items/0 resolves to /items/0/name
      bound = %{"path" => "/name"}
      assert Binding.resolve(bound, data, "/items/0") == "scoped_value"
    end

    test "falls back to literal when path not found in v0.9" do
      data = %{"items" => [%{"name" => "scoped_value"}]}

      # v0.9: /missing is absolute, not found, so fall back to literal
      bound = %{"path" => "/missing", "literalString" => "default"}
      assert Binding.resolve(bound, data, "/items/0", version: :v0_9) == "default"
    end
  end

  describe "get_at_pointer/2" do
    test "handles empty pointer" do
      data = %{"key" => "value"}
      assert Binding.get_at_pointer(data, "") == data
    end

    test "handles simple object traversal" do
      data = %{"user" => %{"name" => "Alice"}}
      assert Binding.get_at_pointer(data, "/user/name") == "Alice"
    end

    test "handles array indexing" do
      data = %{"items" => ["a", "b", "c"]}
      assert Binding.get_at_pointer(data, "/items/0") == "a"
      assert Binding.get_at_pointer(data, "/items/1") == "b"
      assert Binding.get_at_pointer(data, "/items/2") == "c"
    end

    test "handles RFC 6901 unescaping ~1 to /" do
      data = %{"a/b" => "value"}
      assert Binding.get_at_pointer(data, "/a~1b") == "value"
    end

    test "handles RFC 6901 unescaping ~0 to ~" do
      data = %{"a~b" => "value"}
      assert Binding.get_at_pointer(data, "/a~0b") == "value"
    end

    test "handles combined escaping" do
      data = %{"a/b" => %{"c~d" => "value"}}
      assert Binding.get_at_pointer(data, "/a~1b/c~0d") == "value"
    end

    test "handles nested array in object" do
      data = %{"users" => [%{"name" => "Alice"}, %{"name" => "Bob"}]}
      assert Binding.get_at_pointer(data, "/users/0/name") == "Alice"
      assert Binding.get_at_pointer(data, "/users/1/name") == "Bob"
    end

    # v0.8 canonical array encoding: numeric-key maps
    test "handles v0.8 canonical array encoding (numeric-key map)" do
      # v0.8 wire format encodes arrays as maps with numeric string keys
      data = %{"items" => %{"0" => "a", "1" => "b", "2" => "c"}}
      assert Binding.get_at_pointer(data, "/items/0") == "a"
      assert Binding.get_at_pointer(data, "/items/1") == "b"
      assert Binding.get_at_pointer(data, "/items/2") == "c"
    end

    test "handles nested objects in v0.8 canonical array encoding" do
      # v0.8 wire format: array of objects as numeric-key map
      data = %{
        "users" => %{
          "0" => %{"name" => "Alice", "age" => 30},
          "1" => %{"name" => "Bob", "age" => 25}
        }
      }

      assert Binding.get_at_pointer(data, "/users/0/name") == "Alice"
      assert Binding.get_at_pointer(data, "/users/1/name") == "Bob"
      assert Binding.get_at_pointer(data, "/users/0/age") == 30
    end

    test "returns nil for invalid array index" do
      data = %{"items" => ["a", "b"]}
      assert Binding.get_at_pointer(data, "/items/invalid") == nil
    end

    test "returns nil for negative array index format" do
      data = %{"items" => ["a", "b"]}
      # Integer.parse("-1") returns {-1, ""} but we check >= 0
      assert Binding.get_at_pointer(data, "/items/-1") == nil
    end

    test "returns nil for out of bounds array index" do
      data = %{"items" => ["a", "b"]}
      assert Binding.get_at_pointer(data, "/items/10") == nil
    end
  end

  describe "set_at_pointer/3" do
    test "sets value at simple path" do
      data = %{"user" => %{"name" => "Alice"}}
      result = Binding.set_at_pointer(data, "/user/name", "Bob")
      assert result == %{"user" => %{"name" => "Bob"}}
    end

    test "sets value in array" do
      data = %{"items" => ["a", "b", "c"]}
      result = Binding.set_at_pointer(data, "/items/1", "x")
      assert result == %{"items" => ["a", "x", "c"]}
    end

    test "creates nested path if missing" do
      data = %{}
      result = Binding.set_at_pointer(data, "/user/name", "Alice")
      assert result == %{"user" => %{"name" => "Alice"}}
    end

    test "replaces entire data on empty path" do
      data = %{"old" => "data"}
      result = Binding.set_at_pointer(data, "", "new value")
      assert result == "new value"
    end

    test "handles deeply nested paths" do
      data = %{"a" => %{"b" => %{"c" => "old"}}}
      result = Binding.set_at_pointer(data, "/a/b/c", "new")
      assert result == %{"a" => %{"b" => %{"c" => "new"}}}
    end
  end

  describe "expand_path/2 (v0.8 default)" do
    test "returns normalized path when scope is nil" do
      assert Binding.expand_path("/user/name", nil) == "/user/name"
      assert Binding.expand_path("user/name", nil) == "/user/name"
    end

    test "joins relative path with scope" do
      assert Binding.expand_path("name", "/items/0") == "/items/0/name"
    end

    test "joins absolute path with scope (v0.8 template style)" do
      # v0.8: paths starting with / are scoped when inside templates
      assert Binding.expand_path("/name", "/items/0") == "/items/0/name"
    end

    test "handles ./ relative paths" do
      assert Binding.expand_path("./details/price", "/items/0") == "/items/0/details/price"
    end

    test "returns scope for empty path" do
      assert Binding.expand_path("", "/items/0") == "/items/0"
    end
  end

  describe "expand_path/3 (version-aware)" do
    test "v0.8: absolute paths are scoped in template context" do
      # In v0.8, /name inside a template scope becomes scope_path/name
      assert Binding.expand_path("/name", "/items/0", version: :v0_8) == "/items/0/name"
      assert Binding.expand_path("/user/email", "/products/5", version: :v0_8) == "/products/5/user/email"
    end

    test "v0.9: absolute paths stay absolute even in template context" do
      # In v0.9, /name stays /name regardless of scope
      assert Binding.expand_path("/name", "/items/0", version: :v0_9) == "/name"
      assert Binding.expand_path("/user/email", "/products/5", version: :v0_9) == "/user/email"
    end

    test "v0.9: relative paths (no leading /) are scoped" do
      # Both versions scope relative paths without leading /
      assert Binding.expand_path("name", "/items/0", version: :v0_9) == "/items/0/name"
      assert Binding.expand_path("details/price", "/products/5", version: :v0_9) == "/products/5/details/price"
    end

    test "v0.9: ./ relative paths are scoped" do
      assert Binding.expand_path("./name", "/items/0", version: :v0_9) == "/items/0/name"
    end

    test "both versions: nil scope returns normalized path" do
      assert Binding.expand_path("/name", nil, version: :v0_8) == "/name"
      assert Binding.expand_path("/name", nil, version: :v0_9) == "/name"
      assert Binding.expand_path("name", nil, version: :v0_8) == "/name"
      assert Binding.expand_path("name", nil, version: :v0_9) == "/name"
    end

    test "both versions: empty path returns scope" do
      assert Binding.expand_path("", "/items/0", version: :v0_8) == "/items/0"
      assert Binding.expand_path("", "/items/0", version: :v0_9) == "/items/0"
    end

    test "defaults to v0.8 behavior" do
      # When version is not specified, should behave like v0.8
      assert Binding.expand_path("/name", "/items/0", []) == "/items/0/name"
    end
  end

  describe "resolve_path/4 (version-aware)" do
    test "v0.8: resolves scoped absolute path" do
      data = %{"items" => %{"0" => %{"name" => "scoped_value"}, "1" => %{"name" => "other"}}}

      # v0.8: /name in scope /items/0 resolves to /items/0/name
      assert Binding.resolve_path("/name", data, "/items/0", version: :v0_8) == "scoped_value"
    end

    test "v0.9: resolves absolute path from root" do
      data = %{
        "name" => "root_value",
        "items" => %{"0" => %{"name" => "scoped_value"}}
      }

      # v0.9: /name in scope /items/0 still resolves to /name (root)
      assert Binding.resolve_path("/name", data, "/items/0", version: :v0_9) == "root_value"
    end

    test "v0.9: resolves relative path from scope" do
      data = %{
        "name" => "root_value",
        "items" => %{"0" => %{"name" => "scoped_value"}}
      }

      # v0.9: relative path "name" in scope /items/0 resolves to /items/0/name
      assert Binding.resolve_path("name", data, "/items/0", version: :v0_9) == "scoped_value"
    end
  end

  describe "get_path/1" do
    test "extracts path from bound value" do
      assert Binding.get_path(%{"path" => "/form/name"}) == "/form/name"
    end

    test "returns nil for literal-only bound value" do
      assert Binding.get_path(%{"literalString" => "static"}) == nil
    end

    test "returns nil for non-map" do
      assert Binding.get_path("string") == nil
      assert Binding.get_path(42) == nil
      assert Binding.get_path(nil) == nil
    end
  end

  describe "delete_at_pointer/2" do
    test "deletes key from map" do
      data = %{"a" => 1, "b" => 2}
      assert Binding.delete_at_pointer(data, "/a") == %{"b" => 2}
    end

    test "deletes nested key" do
      data = %{"user" => %{"name" => "Alice", "age" => 30}}
      assert Binding.delete_at_pointer(data, "/user/name") == %{"user" => %{"age" => 30}}
    end

    test "deletes deeply nested key" do
      data = %{"a" => %{"b" => %{"c" => 1, "d" => 2}}}
      assert Binding.delete_at_pointer(data, "/a/b/c") == %{"a" => %{"b" => %{"d" => 2}}}
    end

    test "empty path clears entire data" do
      data = %{"a" => 1, "b" => 2}
      assert Binding.delete_at_pointer(data, "") == %{}
    end

    test "root slash clears entire data" do
      data = %{"a" => 1, "b" => 2}
      assert Binding.delete_at_pointer(data, "/") == %{}
    end

    test "deleting missing key is no-op" do
      data = %{"a" => 1}
      assert Binding.delete_at_pointer(data, "/missing") == %{"a" => 1}
    end

    test "deleting from array" do
      data = %{"items" => ["a", "b", "c"]}
      assert Binding.delete_at_pointer(data, "/items/1") == %{"items" => ["a", "c"]}
    end

    test "handles invalid path gracefully" do
      data = %{"a" => 1}
      assert Binding.delete_at_pointer(data, "no_slash") == %{"a" => 1}
    end
  end
end
