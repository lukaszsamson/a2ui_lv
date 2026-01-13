defmodule A2UI.ParserTest do
  use ExUnit.Case, async: true

  alias A2UI.Parser
  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}

  describe "parse_line/1" do
    test "parses v0.8 surfaceUpdate" do
      json = ~s({"surfaceUpdate":{"surfaceId":"main","components":[]}})
      assert {:surface_update, %SurfaceUpdate{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
      assert msg.components == []
    end

    test "parses v0.8 surfaceUpdate with components" do
      json =
        ~s({"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello"}}}}]}})

      assert {:surface_update, %SurfaceUpdate{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
      assert length(msg.components) == 1
      [comp] = msg.components
      assert comp.id == "root"
      assert comp.type == "Text"
      assert comp.props == %{"text" => %{"literalString" => "Hello"}}
    end

    test "parses v0.8 dataModelUpdate" do
      json =
        ~s({"dataModelUpdate":{"surfaceId":"main","contents":[{"key":"name","valueString":"Alice"}]}})

      assert {:data_model_update, %DataModelUpdate{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
      assert msg.path == nil
      assert msg.contents == [%{"key" => "name", "valueString" => "Alice"}]
    end

    test "parses v0.8 dataModelUpdate with path" do
      json =
        ~s({"dataModelUpdate":{"surfaceId":"main","path":"/form","contents":[{"key":"email","valueString":"test@example.com"}]}})

      assert {:data_model_update, %DataModelUpdate{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
      assert msg.path == "/form"
    end

    test "parses v0.8 beginRendering" do
      json = ~s({"beginRendering":{"surfaceId":"main","root":"root"}})
      assert {:begin_rendering, %BeginRendering{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
      assert msg.root_id == "root"
      assert msg.catalog_id == nil
      assert msg.styles == nil
    end

    test "parses v0.8 beginRendering with catalogId and styles" do
      json =
        ~s({"beginRendering":{"surfaceId":"main","root":"root","catalogId":"standard","styles":{"theme":"dark"}}})

      assert {:begin_rendering, %BeginRendering{} = msg} = Parser.parse_line(json)
      assert msg.catalog_id == "standard"
      assert msg.styles == %{"theme" => "dark"}
    end

    test "parses v0.8 deleteSurface" do
      json = ~s({"deleteSurface":{"surfaceId":"main"}})
      assert {:delete_surface, %DeleteSurface{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
    end

    test "returns error for invalid JSON" do
      assert {:error, {:json_decode, %Jason.DecodeError{}}} = Parser.parse_line("not json")
    end

    test "returns error for unknown message type" do
      json = ~s({"unknownType":{"data":"value"}})
      assert {:error, :unknown_message_type} = Parser.parse_line(json)
    end

    test "returns error for empty object" do
      json = ~s({})
      assert {:error, :unknown_message_type} = Parser.parse_line(json)
    end
  end
end
