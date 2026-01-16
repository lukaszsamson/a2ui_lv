defmodule A2UI.A2A.ProtocolTest do
  use ExUnit.Case, async: true

  alias A2UI.A2A.Protocol

  describe "mime_type/0" do
    test "returns the A2UI MIME type" do
      assert Protocol.mime_type() == "application/json+a2ui"
    end
  end

  describe "extension_uri/0 and extension_uri/1" do
    test "returns v0.8 extension URI by default" do
      assert Protocol.extension_uri() == "https://a2ui.org/a2a-extension/a2ui/v0.8"
    end

    test "returns v0.8 extension URI" do
      assert Protocol.extension_uri(:v0_8) == "https://a2ui.org/a2a-extension/a2ui/v0.8"
    end

    test "returns v0.9 extension URI" do
      assert Protocol.extension_uri(:v0_9) == "https://a2ui.org/a2a-extension/a2ui/v0.9"
    end
  end

  describe "extension_uris/0" do
    test "returns all known extension URIs" do
      uris = Protocol.extension_uris()
      assert length(uris) == 2
      assert "https://a2ui.org/a2a-extension/a2ui/v0.8" in uris
      assert "https://a2ui.org/a2a-extension/a2ui/v0.9" in uris
    end
  end

  describe "metadata keys" do
    test "client_capabilities_key" do
      assert Protocol.client_capabilities_key() == "a2uiClientCapabilities"
    end

    test "supported_catalog_ids_key" do
      assert Protocol.supported_catalog_ids_key() == "supportedCatalogIds"
    end

    test "inline_catalogs_key" do
      assert Protocol.inline_catalogs_key() == "inlineCatalogs"
    end
  end

  describe "roles" do
    test "client_role" do
      assert Protocol.client_role() == "user"
    end

    test "server_role" do
      assert Protocol.server_role() == "agent"
    end
  end
end
