defmodule A2UI.JsonPointerTest do
  use ExUnit.Case, async: true

  alias A2UI.JsonPointer

  describe "upsert/3" do
    test "creates maps for non-numeric segments" do
      assert JsonPointer.upsert(%{}, "/user/name", "Alice") ==
               %{"user" => %{"name" => "Alice"}}
    end

    test "creates lists for numeric segments" do
      assert JsonPointer.upsert(%{}, "/items/0", "first") ==
               %{"items" => ["first"]}
    end

    test "creates nested list for numeric next segment" do
      assert JsonPointer.upsert(%{}, "/items/0/name", "Widget") ==
               %{"items" => [%{"name" => "Widget"}]}
    end

    test "creates list with padding for non-zero index" do
      assert JsonPointer.upsert(%{}, "/items/2", "third") ==
               %{"items" => [nil, nil, "third"]}
    end

    test "preserves existing list structure" do
      existing = %{"items" => ["a", "b", "c"]}

      result = JsonPointer.upsert(existing, "/items/1", "updated")

      assert result == %{"items" => ["a", "updated", "c"]}
    end

    test "extends list when index exceeds length" do
      existing = %{"items" => ["a", "b"]}

      result = JsonPointer.upsert(existing, "/items/4", "e")

      assert result == %{"items" => ["a", "b", nil, nil, "e"]}
    end

    test "preserves existing map structure" do
      existing = %{"user" => %{"name" => "Alice", "age" => 30}}

      result = JsonPointer.upsert(existing, "/user/name", "Bob")

      assert result == %{"user" => %{"name" => "Bob", "age" => 30}}
    end

    test "creates nested structures with mixed types" do
      result = JsonPointer.upsert(%{}, "/data/items/0/tags/0", "first-tag")

      assert result == %{"data" => %{"items" => [%{"tags" => ["first-tag"]}]}}
    end

    test "handles empty path (replace root)" do
      assert JsonPointer.upsert(%{"old" => "data"}, "", %{"new" => "data"}) ==
               %{"new" => "data"}
    end

    test "handles nil root" do
      assert JsonPointer.upsert(nil, "/items/0", "first") ==
               %{"items" => ["first"]}
    end

    test "handles nested map updates" do
      existing = %{"items" => %{"0" => %{"name" => "Old", "price" => 10}}}

      result = JsonPointer.upsert(existing, "/items/0/name", "New")

      assert result == %{"items" => %{"0" => %{"name" => "New", "price" => 10}}}
    end
  end

  describe "delete/2" do
    test "deletes key from map" do
      data = %{"a" => 1, "b" => 2}
      assert JsonPointer.delete(data, "/a") == %{"b" => 2}
    end

    test "deletes nested key from map" do
      data = %{"user" => %{"name" => "Alice", "age" => 30}}
      assert JsonPointer.delete(data, "/user/name") == %{"user" => %{"age" => 30}}
    end

    test "deletes element from list" do
      data = %{"items" => ["a", "b", "c"]}
      assert JsonPointer.delete(data, "/items/1") == %{"items" => ["a", "c"]}
    end

    test "deletes nested element within list" do
      data = %{"items" => [%{"name" => "Alice", "age" => 30}]}

      result = JsonPointer.delete(data, "/items/0/age")

      assert result == %{"items" => [%{"name" => "Alice"}]}
    end

    test "returns data unchanged for missing path" do
      data = %{"a" => 1}
      assert JsonPointer.delete(data, "/missing/path") == data
    end

    test "clears root on empty path" do
      data = %{"a" => 1, "b" => 2}
      assert JsonPointer.delete(data, "") == %{}
    end

    test "handles nil root" do
      assert JsonPointer.delete(nil, "/a") == %{}
    end

    test "deletes key with numeric name from map" do
      data = %{"items" => %{"0" => "first", "1" => "second"}}
      assert JsonPointer.delete(data, "/items/0") == %{"items" => %{"1" => "second"}}
    end
  end

  describe "pointer escaping" do
    test "handles escaped slashes in segment" do
      data = %{"a/b" => %{"c" => 1}}
      # ~1 is escaped /
      assert JsonPointer.upsert(data, "/a~1b/c", 2) == %{"a/b" => %{"c" => 2}}
    end

    test "handles escaped tildes in segment" do
      data = %{"a~b" => %{"c" => 1}}
      # ~0 is escaped ~
      assert JsonPointer.upsert(data, "/a~0b/c", 2) == %{"a~b" => %{"c" => 2}}
    end
  end
end
