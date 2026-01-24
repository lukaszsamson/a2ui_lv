defmodule A2UI.ClientCapabilitiesTest do
  use ExUnit.Case, async: true

  alias A2UI.ClientCapabilities

  describe "new/1" do
    test "creates capabilities with all v0.8 and v0.9 standard catalog aliases by default" do
      caps = ClientCapabilities.new()

      # Should include all known v0.8 and v0.9 aliases for maximum compatibility
      expected = A2UI.V0_8.standard_catalog_ids() ++ A2UI.V0_9.standard_catalog_ids()
      assert caps.supported_catalog_ids == expected
      assert caps.inline_catalogs == []
    end

    test "accepts custom supported_catalog_ids" do
      caps =
        ClientCapabilities.new(
          supported_catalog_ids: ["https://example.com/catalog1", "https://example.com/catalog2"]
        )

      assert caps.supported_catalog_ids == [
               "https://example.com/catalog1",
               "https://example.com/catalog2"
             ]
    end

    test "accepts inline_catalogs as array of catalog definitions" do
      inline_catalog = %{
        "catalogId" => "https://example.com/inline/custom",
        "components" => %{
          "CustomWidget" => %{"type" => "object", "properties" => %{}}
        },
        "styles" => %{}
      }

      caps = ClientCapabilities.new(inline_catalogs: [inline_catalog])

      assert caps.inline_catalogs == [inline_catalog]
    end
  end

  describe "default/0" do
    test "returns capabilities with all v0.8 and v0.9 standard catalog aliases" do
      caps = ClientCapabilities.default()

      # Should include all known v0.8 and v0.9 aliases for maximum compatibility
      expected = A2UI.V0_8.standard_catalog_ids() ++ A2UI.V0_9.standard_catalog_ids()
      assert caps.supported_catalog_ids == expected
      assert caps.inline_catalogs == []
    end
  end

  describe "supports_catalog?/2" do
    test "returns true for catalog in supported_catalog_ids" do
      caps = ClientCapabilities.new(supported_catalog_ids: ["https://example.com/catalog"])

      assert ClientCapabilities.supports_catalog?(caps, "https://example.com/catalog")
    end

    test "returns false for unknown catalog" do
      caps = ClientCapabilities.new(supported_catalog_ids: ["https://example.com/catalog"])

      refute ClientCapabilities.supports_catalog?(caps, "https://unknown.com/catalog")
    end

    test "returns true for inline catalog by catalogId" do
      inline_catalog = %{
        "catalogId" => "https://example.com/inline/custom",
        "components" => %{}
      }

      caps = ClientCapabilities.new(inline_catalogs: [inline_catalog])

      assert ClientCapabilities.supports_catalog?(caps, "https://example.com/inline/custom")
    end

    test "returns true for standard catalog by default" do
      caps = ClientCapabilities.new()

      assert ClientCapabilities.supports_catalog?(caps, A2UI.V0_8.standard_catalog_id())
    end
  end

  describe "get_inline_catalog/2" do
    test "returns {:ok, catalog} when found" do
      inline_catalog = %{
        "catalogId" => "https://example.com/inline/custom",
        "components" => %{"Widget" => %{}}
      }

      caps = ClientCapabilities.new(inline_catalogs: [inline_catalog])

      assert {:ok, ^inline_catalog} =
               ClientCapabilities.get_inline_catalog(caps, "https://example.com/inline/custom")
    end

    test "returns :error when not found" do
      caps = ClientCapabilities.new(inline_catalogs: [])

      assert :error = ClientCapabilities.get_inline_catalog(caps, "https://unknown.com/catalog")
    end

    test "finds correct catalog among multiple" do
      catalog1 = %{"catalogId" => "https://example.com/c1", "components" => %{"A" => %{}}}
      catalog2 = %{"catalogId" => "https://example.com/c2", "components" => %{"B" => %{}}}

      caps = ClientCapabilities.new(inline_catalogs: [catalog1, catalog2])

      assert {:ok, ^catalog2} =
               ClientCapabilities.get_inline_catalog(caps, "https://example.com/c2")
    end
  end

  describe "to_a2a_metadata/1" do
    test "returns supportedCatalogIds array" do
      caps = ClientCapabilities.new(supported_catalog_ids: ["https://example.com/catalog"])

      metadata = ClientCapabilities.to_a2a_metadata(caps)

      assert metadata["supportedCatalogIds"] == ["https://example.com/catalog"]
    end

    test "omits inlineCatalogs when empty" do
      caps = ClientCapabilities.new()

      metadata = ClientCapabilities.to_a2a_metadata(caps)

      refute Map.has_key?(metadata, "inlineCatalogs")
    end

    test "includes inlineCatalogs as array when present (per v0.8 spec)" do
      inline_catalog = %{
        "catalogId" => "https://example.com/inline/custom",
        "components" => %{"Widget" => %{}},
        "styles" => %{}
      }

      caps = ClientCapabilities.new(inline_catalogs: [inline_catalog])

      metadata = ClientCapabilities.to_a2a_metadata(caps)

      # Per spec: inlineCatalogs is an ARRAY, not a map
      assert is_list(metadata["inlineCatalogs"])
      assert metadata["inlineCatalogs"] == [inline_catalog]
    end

    test "produces spec-compliant A2A metadata structure" do
      # This test verifies the exact structure from the spec example
      inline_catalog = %{
        "catalogId" => "https://my-company.com/inline_catalogs/temp-signature-pad-catalog",
        "components" => %{
          "SignaturePad" => %{
            "type" => "object",
            "properties" => %{"penColor" => %{"type" => "string"}}
          }
        },
        "styles" => %{}
      }

      caps =
        ClientCapabilities.new(
          supported_catalog_ids: [
            A2UI.V0_8.standard_catalog_id(),
            "https://my-company.com/a2ui_catalogs/custom-reporting-catalog-1.2"
          ],
          inline_catalogs: [inline_catalog]
        )

      metadata = ClientCapabilities.to_a2a_metadata(caps)

      # Verify structure matches spec
      assert is_list(metadata["supportedCatalogIds"])
      assert length(metadata["supportedCatalogIds"]) == 2
      assert is_list(metadata["inlineCatalogs"])
      assert length(metadata["inlineCatalogs"]) == 1

      [first_inline] = metadata["inlineCatalogs"]
      assert first_inline["catalogId"] == inline_catalog["catalogId"]
      assert first_inline["components"] == inline_catalog["components"]
    end
  end
end
