defmodule A2UI.ParserTest do
  use ExUnit.Case, async: true

  alias A2UI.Parser
  alias A2UI.Parser.{V0_8, V0_9}
  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}

  describe "parse_line/1 (v0.8)" do
    test "parses v0.8 surfaceUpdate" do
      json = ~s({"surfaceUpdate":{"surfaceId":"main","components":[]}})
      assert {:surface_update, %SurfaceUpdate{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
      assert msg.components == []
    end

    test "parses v0.8 surfaceUpdate with components" do
      # v0.8 wire format is adapted to v0.9-native internal representation
      json =
        ~s({"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello"}}}}]}})

      assert {:surface_update, %SurfaceUpdate{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
      assert length(msg.components) == 1
      [comp] = msg.components
      assert comp.id == "root"
      assert comp.type == "Text"
      # Props are adapted: literalString unwrapped to native string
      assert comp.props == %{"text" => "Hello"}
    end

    test "parses v0.8 dataModelUpdate" do
      # v0.8 wire format is adapted to v0.9-native internal representation
      json =
        ~s({"dataModelUpdate":{"surfaceId":"main","contents":[{"key":"name","valueString":"Alice"}]}})

      assert {:data_model_update, %DataModelUpdate{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
      assert msg.path == nil
      # Contents adapted to native JSON value
      assert msg.value == %{"name" => "Alice"}
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
      assert msg.protocol_version == :v0_8
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

    test "returns error when parsing raises an exception" do
      json =
        ~s({"surfaceUpdate":{"surfaceId":"main","components":[{"id":"broken","component":{}}]}})

      assert {:error, {:parse_exception, _}} = Parser.parse_line(json)
    end
  end

  describe "parse_line/1 (v0.9)" do
    test "parses v0.9 createSurface" do
      json = ~s({"createSurface":{"surfaceId":"main","catalogId":"test.catalog"}})
      assert {:begin_rendering, %BeginRendering{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
      assert msg.root_id == "root"
      assert msg.catalog_id == "test.catalog"
      assert msg.broadcast_data_model? == false
      assert msg.protocol_version == :v0_9
    end

    test "parses v0.9 createSurface with broadcastDataModel" do
      json =
        ~s({"createSurface":{"surfaceId":"main","catalogId":"test","broadcastDataModel":true}})

      assert {:begin_rendering, %BeginRendering{} = msg} = Parser.parse_line(json)
      assert msg.broadcast_data_model? == true
    end

    test "parses v0.9 updateComponents" do
      json = ~s({"updateComponents":{"surfaceId":"main","components":[]}})
      assert {:surface_update, %SurfaceUpdate{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
      assert msg.components == []
    end

    test "parses v0.9 updateComponents with components" do
      # v0.9 uses discriminator format: "component": "Text"
      json =
        ~s({"updateComponents":{"surfaceId":"main","components":[{"id":"root","component":"Text","text":"Hello"}]}})

      assert {:surface_update, %SurfaceUpdate{} = msg} = Parser.parse_line(json)
      assert length(msg.components) == 1
      [comp] = msg.components
      assert comp.id == "root"
      assert comp.type == "Text"
      assert comp.props == %{"text" => "Hello"}
    end

    test "parses v0.9 updateDataModel with value" do
      json = ~s({"updateDataModel":{"surfaceId":"main","path":"/user/name","value":"Alice"}})
      assert {:data_model_update, %DataModelUpdate{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
      assert msg.path == "/user/name"
      assert msg.value == "Alice"
    end

    test "parses v0.9 updateDataModel root replacement" do
      json = ~s({"updateDataModel":{"surfaceId":"main","value":{"name":"Alice"}}})
      assert {:data_model_update, %DataModelUpdate{} = msg} = Parser.parse_line(json)
      assert msg.path == nil
      assert msg.value == %{"name" => "Alice"}
    end

    test "parses v0.9 updateDataModel delete (no value)" do
      json = ~s({"updateDataModel":{"surfaceId":"main","path":"/user/temp"}})
      assert {:data_model_update, %DataModelUpdate{} = msg} = Parser.parse_line(json)
      assert msg.path == "/user/temp"
      assert msg.value == :delete
    end

    test "parses v0.9 deleteSurface" do
      json = ~s({"deleteSurface":{"surfaceId":"main"}})
      assert {:delete_surface, %DeleteSurface{} = msg} = Parser.parse_line(json)
      assert msg.surface_id == "main"
    end
  end

  describe "detect_version/1" do
    test "detects v0.8 messages" do
      assert Parser.detect_version(%{"surfaceUpdate" => %{}}) == :v0_8
      assert Parser.detect_version(%{"dataModelUpdate" => %{}}) == :v0_8
      assert Parser.detect_version(%{"beginRendering" => %{}}) == :v0_8
      assert Parser.detect_version(%{"deleteSurface" => %{}}) == :v0_8
    end

    test "detects v0.9 messages" do
      assert Parser.detect_version(%{"createSurface" => %{}}) == :v0_9
      assert Parser.detect_version(%{"updateComponents" => %{}}) == :v0_9
      assert Parser.detect_version(%{"updateDataModel" => %{}}) == :v0_9
    end

    test "returns unknown for unrecognized messages" do
      assert Parser.detect_version(%{"unknown" => %{}}) == :unknown
      assert Parser.detect_version(%{}) == :unknown
      assert Parser.detect_version("string") == :unknown
    end
  end

  describe "V0_8.v0_8_message?/1" do
    test "returns true for v0.8 messages" do
      assert V0_8.v0_8_message?(%{"surfaceUpdate" => %{}})
      assert V0_8.v0_8_message?(%{"dataModelUpdate" => %{}})
      assert V0_8.v0_8_message?(%{"beginRendering" => %{}})
      assert V0_8.v0_8_message?(%{"deleteSurface" => %{}})
    end

    test "returns false for v0.9 messages" do
      refute V0_8.v0_8_message?(%{"createSurface" => %{}})
      refute V0_8.v0_8_message?(%{"updateComponents" => %{}})
      refute V0_8.v0_8_message?(%{"updateDataModel" => %{}})
    end

    test "returns false for non-map" do
      refute V0_8.v0_8_message?("string")
      refute V0_8.v0_8_message?(nil)
    end
  end

  describe "V0_9.v0_9_message?/1" do
    test "returns true for v0.9 messages" do
      assert V0_9.v0_9_message?(%{"createSurface" => %{}})
      assert V0_9.v0_9_message?(%{"updateComponents" => %{}})
      assert V0_9.v0_9_message?(%{"updateDataModel" => %{}})
      assert V0_9.v0_9_message?(%{"deleteSurface" => %{}})
    end

    test "returns false for v0.8-only messages" do
      refute V0_9.v0_9_message?(%{"surfaceUpdate" => %{}})
      refute V0_9.v0_9_message?(%{"dataModelUpdate" => %{}})
      refute V0_9.v0_9_message?(%{"beginRendering" => %{}})
    end

    test "returns false for non-map" do
      refute V0_9.v0_9_message?("string")
      refute V0_9.v0_9_message?(nil)
    end
  end
end
