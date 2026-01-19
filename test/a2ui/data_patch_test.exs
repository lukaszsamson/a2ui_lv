defmodule A2UI.DataPatchTest do
  use ExUnit.Case, async: true

  alias A2UI.DataPatch

  describe "apply/2 with :replace_root" do
    test "replaces entire data model with map" do
      data = %{"old" => "data"}

      assert DataPatch.apply_patch(data, {:replace_root, %{"new" => "data"}}) == %{
               "new" => "data"
             }
    end

    test "replaces empty data model" do
      assert DataPatch.apply_patch(%{}, {:replace_root, %{"name" => "Alice"}}) == %{
               "name" => "Alice"
             }
    end

    test "non-map replace_root returns empty map" do
      assert DataPatch.apply_patch(%{"old" => "data"}, {:replace_root, "string"}) == %{}
      assert DataPatch.apply_patch(%{"old" => "data"}, {:replace_root, 42}) == %{}
      assert DataPatch.apply_patch(%{"old" => "data"}, {:replace_root, nil}) == %{}
    end
  end

  describe "apply/2 with :set_at" do
    test "sets value at simple path" do
      data = %{"user" => %{"name" => "Alice"}}
      result = DataPatch.apply_patch(data, {:set_at, "/user/name", "Bob"})
      assert result == %{"user" => %{"name" => "Bob"}}
    end

    test "sets value at nested path creating intermediate maps" do
      result = DataPatch.apply_patch(%{}, {:set_at, "/user/profile/name", "Alice"})
      assert result == %{"user" => %{"profile" => %{"name" => "Alice"}}}
    end

    test "sets any JSON value type" do
      assert DataPatch.apply_patch(%{}, {:set_at, "/str", "hello"}) == %{"str" => "hello"}
      assert DataPatch.apply_patch(%{}, {:set_at, "/num", 42}) == %{"num" => 42}
      assert DataPatch.apply_patch(%{}, {:set_at, "/bool", true}) == %{"bool" => true}
      assert DataPatch.apply_patch(%{}, {:set_at, "/arr", [1, 2, 3]}) == %{"arr" => [1, 2, 3]}
      assert DataPatch.apply_patch(%{}, {:set_at, "/obj", %{"a" => 1}}) == %{"obj" => %{"a" => 1}}
      assert DataPatch.apply_patch(%{}, {:set_at, "/null", nil}) == %{"null" => nil}
    end

    test "overwrites existing value" do
      data = %{"count" => 10}
      assert DataPatch.apply_patch(data, {:set_at, "/count", 20}) == %{"count" => 20}
    end

    test "creates list containers for numeric segments" do
      result = DataPatch.apply_patch(%{}, {:set_at, "/items/0", "first"})
      assert result == %{"items" => ["first"]}
    end
  end

  describe "apply_patch/2 with :delete_at" do
    test "deletes key at path" do
      data = %{"user" => %{"name" => "Alice", "age" => 30}}
      result = DataPatch.apply_patch(data, {:delete_at, "/user/name"})
      assert result == %{"user" => %{"age" => 30}}
    end

    test "deletes top-level key" do
      data = %{"a" => 1, "b" => 2}
      result = DataPatch.apply_patch(data, {:delete_at, "/a"})
      assert result == %{"b" => 2}
    end

    test "deleting missing key is no-op" do
      data = %{"a" => 1}
      result = DataPatch.apply_patch(data, {:delete_at, "/missing"})
      assert result == %{"a" => 1}
    end

    test "deletes element from list" do
      data = %{"items" => ["a", "b", "c"]}
      result = DataPatch.apply_patch(data, {:delete_at, "/items/1"})
      assert result == %{"items" => ["a", "c"]}
    end
  end

  describe "apply_all/2" do
    test "applies patches in order" do
      patches = [
        {:set_at, "/user/name", "Alice"},
        {:set_at, "/user/age", 30}
      ]

      result = DataPatch.apply_all(%{}, patches)
      assert result == %{"user" => %{"name" => "Alice", "age" => 30}}
    end

    test "later patches override earlier ones" do
      patches = [
        {:set_at, "/name", "Alice"},
        {:set_at, "/name", "Bob"}
      ]

      result = DataPatch.apply_all(%{}, patches)
      assert result == %{"name" => "Bob"}
    end

    test "empty patch list returns original data" do
      data = %{"existing" => "data"}
      assert DataPatch.apply_all(data, []) == data
    end

    test "combines different patch types" do
      patches = [
        {:replace_root, %{"base" => "data"}},
        {:set_at, "/user/name", "Alice"}
      ]

      result = DataPatch.apply_all(%{}, patches)

      assert result == %{
               "base" => "data",
               "user" => %{"name" => "Alice"}
             }
    end
  end

  describe "from_update/2" do
    test "root path with map produces replace_root" do
      assert DataPatch.from_update(nil, %{"name" => "Alice"}) ==
               {:replace_root, %{"name" => "Alice"}}

      assert DataPatch.from_update("", %{"name" => "Alice"}) ==
               {:replace_root, %{"name" => "Alice"}}

      assert DataPatch.from_update("/", %{"name" => "Alice"}) ==
               {:replace_root, %{"name" => "Alice"}}
    end

    test "root path with non-map wraps in _root" do
      assert DataPatch.from_update(nil, "string") ==
               {:replace_root, %{"_root" => "string"}}

      assert DataPatch.from_update(nil, 42) ==
               {:replace_root, %{"_root" => 42}}
    end

    test "nested path produces set_at" do
      assert DataPatch.from_update("/user", %{"name" => "Alice"}) ==
               {:set_at, "/user", %{"name" => "Alice"}}

      assert DataPatch.from_update("/user/name", "Alice") ==
               {:set_at, "/user/name", "Alice"}
    end

    test "supports all JSON value types at nested paths" do
      assert DataPatch.from_update("/str", "hello") == {:set_at, "/str", "hello"}
      assert DataPatch.from_update("/num", 42) == {:set_at, "/num", 42}
      assert DataPatch.from_update("/bool", true) == {:set_at, "/bool", true}
      assert DataPatch.from_update("/arr", [1, 2]) == {:set_at, "/arr", [1, 2]}
      assert DataPatch.from_update("/obj", %{"a" => 1}) == {:set_at, "/obj", %{"a" => 1}}
      assert DataPatch.from_update("/null", nil) == {:set_at, "/null", nil}
    end

    test "normalizes path without leading slash" do
      assert DataPatch.from_update("user/name", "Alice") ==
               {:set_at, "/user/name", "Alice"}
    end

    test ":delete at root produces empty replace_root" do
      assert DataPatch.from_update(nil, :delete) == {:replace_root, %{}}
      assert DataPatch.from_update("", :delete) == {:replace_root, %{}}
      assert DataPatch.from_update("/", :delete) == {:replace_root, %{}}
    end

    test ":delete at nested path produces delete_at" do
      assert DataPatch.from_update("/user/name", :delete) == {:delete_at, "/user/name"}
      assert DataPatch.from_update("/temp", :delete) == {:delete_at, "/temp"}
    end
  end
end
