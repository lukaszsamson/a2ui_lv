defmodule A2UI.DataPatchTest do
  use ExUnit.Case, async: true

  alias A2UI.DataPatch

  describe "apply/2 with :replace_root" do
    test "replaces entire data model with map" do
      data = %{"old" => "data"}
      assert DataPatch.apply_patch(data, {:replace_root, %{"new" => "data"}}) == %{"new" => "data"}
    end

    test "replaces empty data model" do
      assert DataPatch.apply_patch(%{}, {:replace_root, %{"name" => "Alice"}}) == %{"name" => "Alice"}
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
  end

  describe "apply/2 with :merge_at" do
    test "merges map at path" do
      data = %{"user" => %{"name" => "Alice"}}
      result = DataPatch.apply_patch(data, {:merge_at, "/user", %{"age" => 30}})
      assert result == %{"user" => %{"name" => "Alice", "age" => 30}}
    end

    test "overwrites existing keys during merge" do
      data = %{"user" => %{"name" => "Alice", "age" => 25}}
      result = DataPatch.apply_patch(data, {:merge_at, "/user", %{"age" => 30}})
      assert result == %{"user" => %{"name" => "Alice", "age" => 30}}
    end

    test "creates path if missing" do
      result = DataPatch.apply_patch(%{}, {:merge_at, "/user", %{"name" => "Alice"}})
      assert result == %{"user" => %{"name" => "Alice"}}
    end

    test "replaces non-map with merged value" do
      data = %{"user" => "old_string"}
      result = DataPatch.apply_patch(data, {:merge_at, "/user", %{"name" => "Alice"}})
      assert result == %{"user" => %{"name" => "Alice"}}
    end

    test "non-map merge value is a no-op" do
      data = %{"user" => %{"name" => "Alice"}}
      assert DataPatch.apply_patch(data, {:merge_at, "/user", "string"}) == data
      assert DataPatch.apply_patch(data, {:merge_at, "/user", 42}) == data
      assert DataPatch.apply_patch(data, {:merge_at, "/user", nil}) == data
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
        {:set_at, "/user/name", "Alice"},
        {:merge_at, "/user", %{"email" => "alice@example.com"}}
      ]

      result = DataPatch.apply_all(%{}, patches)

      assert result == %{
               "base" => "data",
               "user" => %{"name" => "Alice", "email" => "alice@example.com"}
             }
    end
  end

  describe "from_v0_8_contents/2" do
    test "root path produces replace_root patch" do
      contents = [%{"key" => "name", "valueString" => "Alice"}]

      assert DataPatch.from_v0_8_contents(nil, contents) ==
               {:replace_root, %{"name" => "Alice"}}

      assert DataPatch.from_v0_8_contents("", contents) ==
               {:replace_root, %{"name" => "Alice"}}

      assert DataPatch.from_v0_8_contents("/", contents) ==
               {:replace_root, %{"name" => "Alice"}}
    end

    test "nested path produces merge_at patch" do
      contents = [%{"key" => "name", "valueString" => "Alice"}]

      assert DataPatch.from_v0_8_contents("/user", contents) ==
               {:merge_at, "/user", %{"name" => "Alice"}}
    end

    test "decodes valueString" do
      contents = [%{"key" => "name", "valueString" => "Alice"}]
      {:replace_root, result} = DataPatch.from_v0_8_contents(nil, contents)
      assert result == %{"name" => "Alice"}
    end

    test "decodes valueNumber" do
      contents = [%{"key" => "age", "valueNumber" => 30}]
      {:replace_root, result} = DataPatch.from_v0_8_contents(nil, contents)
      assert result == %{"age" => 30}
    end

    test "decodes valueBoolean" do
      contents = [%{"key" => "active", "valueBoolean" => true}]
      {:replace_root, result} = DataPatch.from_v0_8_contents(nil, contents)
      assert result == %{"active" => true}
    end

    test "decodes valueMap with nested scalar entries" do
      contents = [
        %{
          "key" => "profile",
          "valueMap" => [
            %{"key" => "name", "valueString" => "Alice"},
            %{"key" => "age", "valueNumber" => 30}
          ]
        }
      ]

      {:replace_root, result} = DataPatch.from_v0_8_contents(nil, contents)
      assert result == %{"profile" => %{"name" => "Alice", "age" => 30}}
    end

    test "decodes multiple entries" do
      contents = [
        %{"key" => "name", "valueString" => "Alice"},
        %{"key" => "age", "valueNumber" => 30},
        %{"key" => "active", "valueBoolean" => true}
      ]

      {:replace_root, result} = DataPatch.from_v0_8_contents(nil, contents)
      assert result == %{"name" => "Alice", "age" => 30, "active" => true}
    end

    test "skips invalid entries" do
      contents = [
        %{"key" => "valid", "valueString" => "value"},
        %{"invalid" => "no key"},
        %{"key" => "also_valid", "valueNumber" => 42}
      ]

      {:replace_root, result} = DataPatch.from_v0_8_contents(nil, contents)
      assert result == %{"valid" => "value", "also_valid" => 42}
    end

    test "skips entries with multiple value types" do
      contents = [
        %{"key" => "ambiguous", "valueString" => "str", "valueNumber" => 42}
      ]

      {:replace_root, result} = DataPatch.from_v0_8_contents(nil, contents)
      assert result == %{}
    end

    test "skips entries with no value type" do
      contents = [%{"key" => "no_value"}]
      {:replace_root, result} = DataPatch.from_v0_8_contents(nil, contents)
      assert result == %{}
    end

    test "non-list contents returns empty replace_root" do
      assert DataPatch.from_v0_8_contents(nil, "not a list") == {:replace_root, %{}}
      assert DataPatch.from_v0_8_contents(nil, nil) == {:replace_root, %{}}
    end

    test "normalizes path without leading slash" do
      contents = [%{"key" => "name", "valueString" => "Alice"}]
      assert DataPatch.from_v0_8_contents("user", contents) == {:merge_at, "/user", %{"name" => "Alice"}}
    end
  end

  describe "from_v0_9_update/2" do
    test "root path with map produces replace_root" do
      assert DataPatch.from_v0_9_update(nil, %{"name" => "Alice"}) ==
               {:replace_root, %{"name" => "Alice"}}

      assert DataPatch.from_v0_9_update("", %{"name" => "Alice"}) ==
               {:replace_root, %{"name" => "Alice"}}

      assert DataPatch.from_v0_9_update("/", %{"name" => "Alice"}) ==
               {:replace_root, %{"name" => "Alice"}}
    end

    test "root path with non-map wraps in _root" do
      assert DataPatch.from_v0_9_update(nil, "string") ==
               {:replace_root, %{"_root" => "string"}}

      assert DataPatch.from_v0_9_update(nil, 42) ==
               {:replace_root, %{"_root" => 42}}
    end

    test "nested path produces set_at" do
      assert DataPatch.from_v0_9_update("/user", %{"name" => "Alice"}) ==
               {:set_at, "/user", %{"name" => "Alice"}}

      assert DataPatch.from_v0_9_update("/user/name", "Alice") ==
               {:set_at, "/user/name", "Alice"}
    end

    test "supports all JSON value types at nested paths" do
      assert DataPatch.from_v0_9_update("/str", "hello") == {:set_at, "/str", "hello"}
      assert DataPatch.from_v0_9_update("/num", 42) == {:set_at, "/num", 42}
      assert DataPatch.from_v0_9_update("/bool", true) == {:set_at, "/bool", true}
      assert DataPatch.from_v0_9_update("/arr", [1, 2]) == {:set_at, "/arr", [1, 2]}
      assert DataPatch.from_v0_9_update("/obj", %{"a" => 1}) == {:set_at, "/obj", %{"a" => 1}}
      assert DataPatch.from_v0_9_update("/null", nil) == {:set_at, "/null", nil}
    end

    test "normalizes path without leading slash" do
      assert DataPatch.from_v0_9_update("user/name", "Alice") ==
               {:set_at, "/user/name", "Alice"}
    end

    test ":delete at root produces empty replace_root" do
      assert DataPatch.from_v0_9_update(nil, :delete) == {:replace_root, %{}}
      assert DataPatch.from_v0_9_update("", :delete) == {:replace_root, %{}}
      assert DataPatch.from_v0_9_update("/", :delete) == {:replace_root, %{}}
    end

    test ":delete at nested path produces delete_at" do
      assert DataPatch.from_v0_9_update("/user/name", :delete) == {:delete_at, "/user/name"}
      assert DataPatch.from_v0_9_update("/temp", :delete) == {:delete_at, "/temp"}
    end
  end
end
