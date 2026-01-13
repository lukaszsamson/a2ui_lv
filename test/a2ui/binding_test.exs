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

  describe "expand_path/2" do
    test "returns normalized path when scope is nil" do
      assert Binding.expand_path("/user/name", nil) == "/user/name"
      assert Binding.expand_path("user/name", nil) == "/user/name"
    end

    test "joins relative path with scope" do
      assert Binding.expand_path("name", "/items/0") == "/items/0/name"
    end

    test "joins absolute path with scope (v0.8 template style)" do
      assert Binding.expand_path("/name", "/items/0") == "/items/0/name"
    end

    test "handles ./ relative paths" do
      assert Binding.expand_path("./details/price", "/items/0") == "/items/0/details/price"
    end

    test "returns scope for empty path" do
      assert Binding.expand_path("", "/items/0") == "/items/0"
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
end
