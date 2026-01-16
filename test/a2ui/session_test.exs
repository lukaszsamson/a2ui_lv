defmodule A2UI.SessionTest do
  use ExUnit.Case, async: true

  alias A2UI.Session

  describe "new/1" do
    test "creates empty session with default capabilities" do
      session = Session.new()
      assert session.surfaces == %{}
      # Defaults to ClientCapabilities.default() with v0.8 standard catalogs
      assert %A2UI.ClientCapabilities{} = session.client_capabilities
      assert session.client_capabilities.supported_catalog_ids == A2UI.V0_8.standard_catalog_ids()
    end

    test "accepts client_capabilities option" do
      caps = A2UI.ClientCapabilities.new(supported_catalog_ids: ["custom.catalog"])
      session = Session.new(client_capabilities: caps)
      assert session.client_capabilities == caps
      assert session.client_capabilities.supported_catalog_ids == ["custom.catalog"]
    end
  end

  describe "apply_json_line/2" do
    test "applies valid surfaceUpdate" do
      session = Session.new()

      json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello"}}}}]}})

      assert {:ok, updated} = Session.apply_json_line(session, json)
      assert Map.has_key?(updated.surfaces, "test")
      assert updated.surfaces["test"].components["root"] != nil
    end

    test "applies valid dataModelUpdate" do
      session = Session.new()

      # First create a surface
      surface_json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello"}}}}]}})

      {:ok, session} = Session.apply_json_line(session, surface_json)

      # Then update data model
      data_json =
        ~s({"dataModelUpdate":{"surfaceId":"test","contents":[{"key":"name","valueString":"Alice"}]}})

      assert {:ok, updated} = Session.apply_json_line(session, data_json)
      assert updated.surfaces["test"].data_model["name"] == "Alice"
    end

    test "applies valid beginRendering" do
      session = Session.new()

      # First create a surface
      surface_json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello"}}}}]}})

      {:ok, session} = Session.apply_json_line(session, surface_json)

      # Then begin rendering
      begin_json = ~s({"beginRendering":{"surfaceId":"test","root":"root"}})

      assert {:ok, updated} = Session.apply_json_line(session, begin_json)
      assert updated.surfaces["test"].ready? == true
      assert updated.surfaces["test"].root_id == "root"
    end

    test "applies deleteSurface" do
      session = Session.new()

      # First create a surface
      surface_json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello"}}}}]}})

      {:ok, session} = Session.apply_json_line(session, surface_json)
      assert Map.has_key?(session.surfaces, "test")

      # Then delete it
      delete_json = ~s({"deleteSurface":{"surfaceId":"test"}})

      assert {:ok, updated} = Session.apply_json_line(session, delete_json)
      refute Map.has_key?(updated.surfaces, "test")
    end

    test "returns error for invalid JSON" do
      session = Session.new()

      assert {:error, error} = Session.apply_json_line(session, "not valid json")
      assert error["error"]["type"] == "parse_error"
      assert error["error"]["message"] =~ "JSON decode"
    end

    test "returns error for unknown message type" do
      session = Session.new()

      assert {:error, error} = Session.apply_json_line(session, ~s({"unknownType":{}}))
      assert error["error"]["type"] == "parse_error"
      assert error["error"]["message"] =~ "Unknown message type"
    end

    test "returns error for unknown component types" do
      session = Session.new()

      json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"UnknownWidget":{}}}]}})

      assert {:error, error} = Session.apply_json_line(session, json)
      assert error["error"]["type"] == "unknown_component"
      assert "UnknownWidget" in error["error"]["details"]["types"]
    end

    test "returns error for too many components" do
      session = Session.new()

      # Generate 1001 components to exceed limit
      components =
        1..1001
        |> Enum.map(fn i ->
          ~s({"id":"c#{i}","component":{"Text":{"text":{"literalString":"text"}}}})
        end)
        |> Enum.join(",")

      json = ~s({"surfaceUpdate":{"surfaceId":"test","components":[#{components}]}})

      assert {:error, error} = Session.apply_json_line(session, json)
      assert error["error"]["type"] == "validation_error"
      assert error["error"]["message"] =~ "Too many components"
    end
  end

  describe "apply_message/2" do
    test "applies SurfaceUpdate message" do
      session = Session.new()

      # Use from_map to properly create components
      msg =
        A2UI.Messages.SurfaceUpdate.from_map(%{
          "surfaceId" => "test",
          "components" => [
            %{
              "id" => "root",
              "component" => %{"Text" => %{"text" => %{"literalString" => "Hello"}}}
            }
          ]
        })

      assert {:ok, updated} = Session.apply_message(session, msg)
      assert Map.has_key?(updated.surfaces, "test")
    end

    test "applies DataModelUpdate message" do
      session = Session.new()

      # First create surface using from_map
      surface_msg =
        A2UI.Messages.SurfaceUpdate.from_map(%{
          "surfaceId" => "test",
          "components" => [
            %{"id" => "root", "component" => %{"Text" => %{"text" => %{"literalString" => "Hi"}}}}
          ]
        })

      {:ok, session} = Session.apply_message(session, surface_msg)

      # Then update data
      data_msg = %A2UI.Messages.DataModelUpdate{
        surface_id: "test",
        path: nil,
        contents: [%{"key" => "count", "valueNumber" => 42}]
      }

      assert {:ok, updated} = Session.apply_message(session, data_msg)
      assert updated.surfaces["test"].data_model["count"] == 42
    end

    test "applies BeginRendering message" do
      session = Session.new()

      # First create surface using from_map
      surface_msg =
        A2UI.Messages.SurfaceUpdate.from_map(%{
          "surfaceId" => "test",
          "components" => [
            %{"id" => "root", "component" => %{"Text" => %{"text" => %{"literalString" => "Hi"}}}}
          ]
        })

      {:ok, session} = Session.apply_message(session, surface_msg)

      # Then begin rendering
      begin_msg = %A2UI.Messages.BeginRendering{
        surface_id: "test",
        root_id: "root",
        catalog_id: nil,
        styles: %{"primaryColor" => "#4f46e5"}
      }

      assert {:ok, updated} = Session.apply_message(session, begin_msg)
      assert updated.surfaces["test"].ready? == true
      assert updated.surfaces["test"].styles == %{"primaryColor" => "#4f46e5"}
    end

    test "applies DeleteSurface message" do
      session = Session.new()

      # First create surface using from_map
      surface_msg =
        A2UI.Messages.SurfaceUpdate.from_map(%{
          "surfaceId" => "test",
          "components" => [
            %{"id" => "root", "component" => %{"Text" => %{"text" => %{"literalString" => "Hi"}}}}
          ]
        })

      {:ok, session} = Session.apply_message(session, surface_msg)

      # Then delete
      delete_msg = %A2UI.Messages.DeleteSurface{surface_id: "test"}

      assert {:ok, updated} = Session.apply_message(session, delete_msg)
      refute Map.has_key?(updated.surfaces, "test")
    end
  end

  describe "get_surface/2" do
    test "returns surface when it exists" do
      session = Session.new()

      json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello"}}}}]}})

      {:ok, session} = Session.apply_json_line(session, json)

      assert {:ok, surface} = Session.get_surface(session, "test")
      assert surface.id == "test"
    end

    test "returns error when surface doesn't exist" do
      session = Session.new()
      assert {:error, :not_found} = Session.get_surface(session, "nonexistent")
    end
  end

  describe "list_surface_ids/1" do
    test "returns empty list for new session" do
      session = Session.new()
      assert Session.list_surface_ids(session) == []
    end

    test "returns all surface IDs" do
      session = Session.new()

      json1 =
        ~s({"surfaceUpdate":{"surfaceId":"surface-1","components":[{"id":"root","component":{"Text":{"text":{"literalString":"1"}}}}]}})

      json2 =
        ~s({"surfaceUpdate":{"surfaceId":"surface-2","components":[{"id":"root","component":{"Text":{"text":{"literalString":"2"}}}}]}})

      {:ok, session} = Session.apply_json_line(session, json1)
      {:ok, session} = Session.apply_json_line(session, json2)

      ids = Session.list_surface_ids(session)
      assert length(ids) == 2
      assert "surface-1" in ids
      assert "surface-2" in ids
    end
  end

  describe "delete_surface/2" do
    test "removes existing surface" do
      session = Session.new()

      json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello"}}}}]}})

      {:ok, session} = Session.apply_json_line(session, json)
      assert Session.surface_count(session) == 1

      updated = Session.delete_surface(session, "test")
      assert Session.surface_count(updated) == 0
    end

    test "returns unchanged session for nonexistent surface" do
      session = Session.new()
      updated = Session.delete_surface(session, "nonexistent")
      assert updated == session
    end
  end

  describe "update_data_at_path/4" do
    test "updates data at path" do
      session = Session.new()

      json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello"}}}}]}})

      {:ok, session} = Session.apply_json_line(session, json)

      assert {:ok, updated} = Session.update_data_at_path(session, "test", "/name", "Bob")
      assert updated.surfaces["test"].data_model["name"] == "Bob"
    end

    test "creates nested paths" do
      session = Session.new()

      json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello"}}}}]}})

      {:ok, session} = Session.apply_json_line(session, json)

      assert {:ok, updated} = Session.update_data_at_path(session, "test", "/user/name", "Alice")
      assert get_in(updated.surfaces["test"].data_model, ["user", "name"]) == "Alice"
    end

    test "returns ok for nonexistent surface (no-op)" do
      session = Session.new()
      assert {:ok, ^session} = Session.update_data_at_path(session, "nonexistent", "/foo", "bar")
    end
  end

  describe "surface_count/1" do
    test "returns 0 for new session" do
      session = Session.new()
      assert Session.surface_count(session) == 0
    end

    test "returns correct count" do
      session = Session.new()

      json1 =
        ~s({"surfaceUpdate":{"surfaceId":"s1","components":[{"id":"root","component":{"Text":{"text":{"literalString":"1"}}}}]}})

      json2 =
        ~s({"surfaceUpdate":{"surfaceId":"s2","components":[{"id":"root","component":{"Text":{"text":{"literalString":"2"}}}}]}})

      {:ok, session} = Session.apply_json_line(session, json1)
      assert Session.surface_count(session) == 1

      {:ok, session} = Session.apply_json_line(session, json2)
      assert Session.surface_count(session) == 2
    end
  end
end
