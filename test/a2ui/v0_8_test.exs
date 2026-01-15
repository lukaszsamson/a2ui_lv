defmodule A2UI.V0_8Test do
  use ExUnit.Case, async: true

  describe "standard_catalog_id/0" do
    test "returns the canonical GitHub URL" do
      assert A2UI.V0_8.standard_catalog_id() ==
               "https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json"
    end
  end

  describe "standard_catalog_ids/0" do
    test "returns all known v0.8 aliases" do
      ids = A2UI.V0_8.standard_catalog_ids()

      # Should include the GitHub URL (from protocol spec)
      assert "https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json" in ids

      # Should include the short form (from server_to_client.json schema)
      assert "a2ui.org:standard_catalog_0_8_0" in ids
    end

    test "returns at least 2 aliases" do
      assert length(A2UI.V0_8.standard_catalog_ids()) >= 2
    end
  end

  describe "standard_catalog_id?/1" do
    test "returns true for known aliases" do
      assert A2UI.V0_8.standard_catalog_id?(
               "https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json"
             )

      assert A2UI.V0_8.standard_catalog_id?("a2ui.org:standard_catalog_0_8_0")
    end

    test "returns false for unknown catalog IDs" do
      refute A2UI.V0_8.standard_catalog_id?("https://example.com/unknown-catalog")
      refute A2UI.V0_8.standard_catalog_id?("random-string")
    end
  end
end
