defmodule A2UI.Catalog.ResolverTest do
  use ExUnit.Case, async: true

  alias A2UI.Catalog.Resolver
  alias A2UI.ClientCapabilities

  describe "resolve/3 with v0.8" do
    test "nil catalogId defaults to standard catalog" do
      caps = ClientCapabilities.default()

      assert {:ok, catalog_id} = Resolver.resolve(nil, caps, :v0_8)
      assert catalog_id == A2UI.V0_8.standard_catalog_id()
    end

    test "standard catalog ID (canonical) resolves successfully" do
      caps = ClientCapabilities.default()
      catalog_id = A2UI.V0_8.standard_catalog_id()

      assert {:ok, resolved} = Resolver.resolve(catalog_id, caps, :v0_8)
      assert resolved == A2UI.V0_8.standard_catalog_id()
    end

    test "standard catalog ID (alias) resolves to canonical" do
      caps = ClientCapabilities.default()
      catalog_id = "a2ui.org:standard_catalog_0_8_0"

      assert {:ok, resolved} = Resolver.resolve(catalog_id, caps, :v0_8)
      assert resolved == A2UI.V0_8.standard_catalog_id()
    end

    test "unknown catalog ID returns error" do
      caps = ClientCapabilities.default()

      assert {:error, :unsupported_catalog} =
               Resolver.resolve("https://unknown/catalog.json", caps, :v0_8)
    end

    test "catalog in capabilities but not standard returns error" do
      # Client claims to support a custom catalog, but we don't
      caps = ClientCapabilities.new(supported_catalog_ids: ["custom.catalog"])

      assert {:error, :unsupported_catalog} = Resolver.resolve("custom.catalog", caps, :v0_8)
    end

    test "inline catalog returns error" do
      inline = %{
        "catalogId" => "inline.custom",
        "components" => %{},
        "styles" => %{}
      }

      caps = ClientCapabilities.new(inline_catalogs: [inline])

      assert {:error, :inline_catalog_not_supported} =
               Resolver.resolve("inline.custom", caps, :v0_8)
    end

    test "standard catalog not in capabilities returns error" do
      # Client has no supported catalogs
      caps = ClientCapabilities.new(supported_catalog_ids: [])
      catalog_id = A2UI.V0_8.standard_catalog_id()

      assert {:error, :catalog_not_in_capabilities} =
               Resolver.resolve(catalog_id, caps, :v0_8)
    end
  end

  describe "resolve/3 with v0.9" do
    test "nil catalogId returns error (required in v0.9)" do
      caps = ClientCapabilities.default()

      assert {:error, :missing_catalog_id} = Resolver.resolve(nil, caps, :v0_9)
    end

    test "standard catalog still resolves in v0.9 mode" do
      caps = ClientCapabilities.default()
      catalog_id = A2UI.V0_8.standard_catalog_id()

      assert {:ok, resolved} = Resolver.resolve(catalog_id, caps, :v0_9)
      assert resolved == A2UI.V0_8.standard_catalog_id()
    end
  end

  describe "format_error/1" do
    test "formats all error types" do
      assert Resolver.format_error(:missing_catalog_id) =~ "required"
      assert Resolver.format_error(:unsupported_catalog) =~ "standard catalog"
      assert Resolver.format_error(:inline_catalog_not_supported) =~ "Inline"
      assert Resolver.format_error(:catalog_not_in_capabilities) =~ "not in client"
    end
  end

  describe "error_details/2" do
    test "includes catalog ID and supported catalogs" do
      details = Resolver.error_details("test.catalog", :unsupported_catalog)

      assert details["catalogId"] == "test.catalog"
      assert details["reason"] == "unsupported_catalog"
      assert is_list(details["supportedCatalogIds"])
      assert A2UI.V0_8.standard_catalog_id() in details["supportedCatalogIds"]
    end

    test "handles nil catalog ID" do
      details = Resolver.error_details(nil, :missing_catalog_id)

      assert details["catalogId"] == nil
      assert details["reason"] == "missing_catalog_id"
    end
  end
end
