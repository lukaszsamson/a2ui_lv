defmodule A2UI.Transport.A2A.AgentCardTest do
  use ExUnit.Case, async: true

  alias A2UI.Transport.A2A.AgentCard
  alias A2UI.A2A.Protocol

  describe "parse/1" do
    test "parses valid agent card JSON" do
      json = %{
        "name" => "Test Agent",
        "url" => "http://localhost:3002",
        "description" => "A test agent"
      }

      assert {:ok, card} = AgentCard.parse(json)
      assert card.name == "Test Agent"
      assert card.url == "http://localhost:3002"
      assert card.description == "A test agent"
    end

    test "parses agent card with A2UI extension" do
      json = %{
        "name" => "A2UI Agent",
        "url" => "http://localhost:3002",
        "capabilities" => %{
          "extensions" => [
            %{
              "uri" => Protocol.extension_uri(:v0_8),
              "params" => %{
                "supportedCatalogIds" => ["https://example.com/catalog.json"],
                "acceptsInlineCatalogs" => true
              }
            }
          ]
        }
      }

      assert {:ok, card} = AgentCard.parse(json)
      assert length(card.extensions) == 1

      [ext] = card.extensions
      assert ext.uri == Protocol.extension_uri(:v0_8)
      assert ext.params["acceptsInlineCatalogs"] == true
    end

    test "returns error for missing required fields" do
      assert {:error, :missing_required_fields} = AgentCard.parse(%{})
      assert {:error, :missing_required_fields} = AgentCard.parse(%{"name" => "Test"})
      assert {:error, :missing_required_fields} = AgentCard.parse(%{"url" => "http://localhost"})
    end

    test "parses JSON string" do
      json_str = ~s({"name": "Test", "url": "http://localhost:3002"})
      assert {:ok, card} = AgentCard.parse(json_str)
      assert card.name == "Test"
    end

    test "returns error for invalid JSON string" do
      assert {:error, :invalid_json} = AgentCard.parse("not json")
    end
  end

  describe "supports_a2ui?/2" do
    test "returns true when A2UI v0.8 extension is present" do
      card = %AgentCard{
        name: "Test",
        url: "http://localhost",
        extensions: [
          %{uri: Protocol.extension_uri(:v0_8), params: %{}}
        ]
      }

      assert AgentCard.supports_a2ui?(card, :v0_8) == true
    end

    test "returns false when no extensions" do
      card = %AgentCard{name: "Test", url: "http://localhost", extensions: []}
      assert AgentCard.supports_a2ui?(card) == false
    end

    test "returns false when different extension" do
      card = %AgentCard{
        name: "Test",
        url: "http://localhost",
        extensions: [
          %{uri: "https://other-extension.com", params: %{}}
        ]
      }

      assert AgentCard.supports_a2ui?(card) == false
    end

    test "defaults to v0_8" do
      card = %AgentCard{
        name: "Test",
        url: "http://localhost",
        extensions: [
          %{uri: Protocol.extension_uri(:v0_8), params: %{}}
        ]
      }

      assert AgentCard.supports_a2ui?(card) == true
    end
  end

  describe "accepts_inline_catalogs?/1" do
    test "returns true when acceptsInlineCatalogs is true" do
      card = %AgentCard{
        name: "Test",
        url: "http://localhost",
        extensions: [
          %{
            uri: Protocol.extension_uri(:v0_8),
            params: %{"acceptsInlineCatalogs" => true}
          }
        ]
      }

      assert AgentCard.accepts_inline_catalogs?(card) == true
    end

    test "returns false when acceptsInlineCatalogs is false" do
      card = %AgentCard{
        name: "Test",
        url: "http://localhost",
        extensions: [
          %{
            uri: Protocol.extension_uri(:v0_8),
            params: %{"acceptsInlineCatalogs" => false}
          }
        ]
      }

      assert AgentCard.accepts_inline_catalogs?(card) == false
    end

    test "returns false when not set" do
      card = %AgentCard{
        name: "Test",
        url: "http://localhost",
        extensions: [
          %{uri: Protocol.extension_uri(:v0_8), params: %{}}
        ]
      }

      assert AgentCard.accepts_inline_catalogs?(card) == false
    end
  end

  describe "supported_catalog_ids/1" do
    test "returns catalog IDs from extension params" do
      card = %AgentCard{
        name: "Test",
        url: "http://localhost",
        extensions: [
          %{
            uri: Protocol.extension_uri(:v0_8),
            params: %{
              "supportedCatalogIds" => ["https://a2ui.org/catalog.json", "https://custom.com/catalog.json"]
            }
          }
        ]
      }

      ids = AgentCard.supported_catalog_ids(card)
      assert length(ids) == 2
      assert "https://a2ui.org/catalog.json" in ids
    end

    test "returns empty list when no extension" do
      card = %AgentCard{name: "Test", url: "http://localhost", extensions: []}
      assert AgentCard.supported_catalog_ids(card) == []
    end
  end

  describe "tasks_url/1" do
    test "builds task URL from base URL" do
      card = %AgentCard{name: "Test", url: "http://localhost:3002"}
      assert AgentCard.tasks_url(card) == "http://localhost:3002/a2a/tasks"
    end

    test "handles URL with existing path" do
      card = %AgentCard{name: "Test", url: "http://localhost:3002/api/v1"}
      assert AgentCard.tasks_url(card) == "http://localhost:3002/api/v1/a2a/tasks"
    end
  end

  describe "task_url/2" do
    test "builds specific task URL" do
      card = %AgentCard{name: "Test", url: "http://localhost:3002"}
      assert AgentCard.task_url(card, "abc-123") == "http://localhost:3002/a2a/tasks/abc-123"
    end
  end
end
