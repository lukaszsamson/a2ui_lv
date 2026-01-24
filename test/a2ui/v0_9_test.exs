defmodule A2UI.V0_9Test do
  use ExUnit.Case, async: true

  describe "standard_catalog_id/0" do
    test "returns the canonical v0.9 catalog ID" do
      assert A2UI.V0_9.standard_catalog_id() ==
               "https://a2ui.dev/specification/v0_9/standard_catalog.json"
    end
  end

  describe "standard_catalog_ids/0" do
    test "returns the single v0.9 catalog ID" do
      ids = A2UI.V0_9.standard_catalog_ids()

      assert ids == ["https://a2ui.dev/specification/v0_9/standard_catalog.json"]
    end

    test "returns exactly 1 ID (v0.9 has no aliases)" do
      assert length(A2UI.V0_9.standard_catalog_ids()) == 1
    end
  end

  describe "standard_catalog_id?/1" do
    test "returns true for the v0.9 catalog ID" do
      assert A2UI.V0_9.standard_catalog_id?(
               "https://a2ui.dev/specification/v0_9/standard_catalog.json"
             )
    end

    test "returns false for v0.8 catalog IDs" do
      refute A2UI.V0_9.standard_catalog_id?(
               "https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json"
             )

      refute A2UI.V0_9.standard_catalog_id?("a2ui.org:standard_catalog_0_8_0")
    end

    test "returns false for unknown catalog IDs" do
      refute A2UI.V0_9.standard_catalog_id?("https://example.com/unknown-catalog")
      refute A2UI.V0_9.standard_catalog_id?("random-string")
    end
  end
end
