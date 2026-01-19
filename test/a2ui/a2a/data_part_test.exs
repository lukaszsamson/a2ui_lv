defmodule A2UI.A2A.DataPartTest do
  use ExUnit.Case, async: true

  alias A2UI.A2A.DataPart
  alias A2UI.A2A.Protocol
  alias A2UI.ClientCapabilities

  describe "wrap_envelope/1" do
    test "wraps A2UI envelope in DataPart format" do
      envelope = %{"userAction" => %{"name" => "click", "surfaceId" => "main"}}

      result = DataPart.wrap_envelope(envelope)

      assert result == %{
               "data" => envelope,
               "metadata" => %{"mimeType" => "application/json+a2ui"}
             }
    end

    test "wraps different envelope types" do
      envelopes = [
        %{"surfaceUpdate" => %{"surfaceId" => "main", "components" => []}},
        %{"beginRendering" => %{"surfaceId" => "main", "root" => "root"}},
        %{"dataModelUpdate" => %{"surfaceId" => "main", "contents" => []}},
        %{"error" => %{"type" => "parse_error", "message" => "test"}}
      ]

      for envelope <- envelopes do
        result = DataPart.wrap_envelope(envelope)
        assert result["data"] == envelope
        assert result["metadata"]["mimeType"] == Protocol.mime_type()
      end
    end
  end

  describe "unwrap_envelope/1" do
    test "unwraps valid DataPart" do
      envelope = %{"userAction" => %{"name" => "click"}}

      data_part = %{
        "data" => envelope,
        "metadata" => %{"mimeType" => "application/json+a2ui"}
      }

      assert {:ok, ^envelope} = DataPart.unwrap_envelope(data_part)
    end

    test "unwraps DataPart without metadata (lenient)" do
      envelope = %{"userAction" => %{}}
      data_part = %{"data" => envelope}

      assert {:ok, ^envelope} = DataPart.unwrap_envelope(data_part)
    end

    test "returns error for invalid mimeType" do
      data_part = %{
        "data" => %{},
        "metadata" => %{"mimeType" => "application/json"}
      }

      assert {:error, :invalid_mime_type} = DataPart.unwrap_envelope(data_part)
    end

    test "returns error for invalid structure" do
      assert {:error, :invalid_data_part} = DataPart.unwrap_envelope(%{})
      assert {:error, :invalid_data_part} = DataPart.unwrap_envelope("not a map")
    end
  end

  describe "a2ui_data_part?/1" do
    test "returns true for valid A2UI DataPart" do
      data_part = DataPart.wrap_envelope(%{"userAction" => %{}})
      assert DataPart.a2ui_data_part?(data_part)
    end

    test "returns false for non-A2UI mimeType" do
      data_part = %{
        "data" => %{},
        "metadata" => %{"mimeType" => "application/json"}
      }

      refute DataPart.a2ui_data_part?(data_part)
    end

    test "returns false for missing metadata" do
      refute DataPart.a2ui_data_part?(%{"data" => %{}})
      refute DataPart.a2ui_data_part?(%{})
    end
  end

  describe "build_client_message/2" do
    test "builds complete A2A message with capabilities" do
      capabilities = ClientCapabilities.default()
      envelope = %{"userAction" => %{"name" => "submit", "surfaceId" => "main"}}

      result = DataPart.build_client_message(envelope, capabilities)

      assert result["message"]["role"] == "user"
      assert is_map(result["message"]["metadata"]["a2uiClientCapabilities"])
      assert [part] = result["message"]["parts"]
      assert part["data"] == envelope
      assert part["metadata"]["mimeType"] == Protocol.mime_type()
    end

    test "includes supportedCatalogIds in capabilities" do
      capabilities =
        ClientCapabilities.new(supported_catalog_ids: ["custom.catalog.1", "custom.catalog.2"])

      envelope = %{"userAction" => %{}}
      result = DataPart.build_client_message(envelope, capabilities)

      caps = result["message"]["metadata"]["a2uiClientCapabilities"]
      assert caps["supportedCatalogIds"] == ["custom.catalog.1", "custom.catalog.2"]
    end

    test "includes inlineCatalogs when present" do
      inline = %{
        "catalogId" => "inline.test",
        "components" => %{},
        "styles" => %{}
      }

      capabilities = ClientCapabilities.new(inline_catalogs: [inline])
      envelope = %{"userAction" => %{}}
      result = DataPart.build_client_message(envelope, capabilities)

      caps = result["message"]["metadata"]["a2uiClientCapabilities"]
      assert caps["inlineCatalogs"] == [inline]
    end
  end

  describe "build_server_message/1" do
    test "builds A2A message with agent role" do
      envelope = %{"beginRendering" => %{"surfaceId" => "main", "root" => "root"}}

      result = DataPart.build_server_message(envelope)

      assert result["message"]["role"] == "agent"
      assert [part] = result["message"]["parts"]
      assert part["data"] == envelope
    end

    test "does not include client capabilities metadata" do
      envelope = %{"surfaceUpdate" => %{}}
      result = DataPart.build_server_message(envelope)

      refute Map.has_key?(result["message"], "metadata")
    end
  end

  describe "extract_envelopes/1" do
    test "extracts A2UI envelopes from message parts" do
      msg = %{
        "message" => %{
          "parts" => [
            DataPart.wrap_envelope(%{"userAction" => %{"name" => "a"}}),
            DataPart.wrap_envelope(%{"userAction" => %{"name" => "b"}})
          ]
        }
      }

      envelopes = DataPart.extract_envelopes(msg)

      assert length(envelopes) == 2
      assert %{"userAction" => %{"name" => "a"}} in envelopes
      assert %{"userAction" => %{"name" => "b"}} in envelopes
    end

    test "filters out non-A2UI parts" do
      msg = %{
        "message" => %{
          "parts" => [
            DataPart.wrap_envelope(%{"userAction" => %{}}),
            %{"data" => "plain text", "metadata" => %{"mimeType" => "text/plain"}}
          ]
        }
      }

      envelopes = DataPart.extract_envelopes(msg)
      assert length(envelopes) == 1
    end

    test "returns empty list for invalid message" do
      assert DataPart.extract_envelopes(%{}) == []
      assert DataPart.extract_envelopes(%{"message" => %{}}) == []
      assert DataPart.extract_envelopes("not a map") == []
    end
  end

  describe "extract_client_capabilities/1" do
    test "extracts capabilities from message metadata" do
      msg = %{
        "message" => %{
          "metadata" => %{
            "a2uiClientCapabilities" => %{
              "supportedCatalogIds" => ["test.catalog"]
            }
          }
        }
      }

      assert {:ok, caps} = DataPart.extract_client_capabilities(msg)
      assert caps["supportedCatalogIds"] == ["test.catalog"]
    end

    test "returns error when capabilities missing" do
      assert :error = DataPart.extract_client_capabilities(%{"message" => %{}})
      assert :error = DataPart.extract_client_capabilities(%{"message" => %{"metadata" => %{}}})
    end
  end

  describe "parse_client_capabilities/1" do
    test "parses capabilities into struct" do
      msg = %{
        "message" => %{
          "metadata" => %{
            "a2uiClientCapabilities" => %{
              "supportedCatalogIds" => ["catalog.a", "catalog.b"],
              "inlineCatalogs" => [
                %{"catalogId" => "inline.1", "components" => %{}}
              ]
            }
          }
        }
      }

      assert {:ok, %ClientCapabilities{} = caps} = DataPart.parse_client_capabilities(msg)
      assert caps.supported_catalog_ids == ["catalog.a", "catalog.b"]
      assert length(caps.inline_catalogs) == 1
    end

    test "returns error when capabilities missing" do
      assert {:error, :missing_client_capabilities} =
               DataPart.parse_client_capabilities(%{"message" => %{}})
    end
  end
end
