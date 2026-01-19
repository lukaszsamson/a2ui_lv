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
        value: %{"count" => 42},
        protocol_version: :v0_9
      }

      assert {:ok, updated} = Session.apply_message(session, data_msg)
      assert updated.surfaces["test"].data_model["count"] == 42
    end

    test "v0.8 DataModelUpdate merges at path" do
      session = Session.new()

      {:ok, session} =
        Session.apply_json_line(
          session,
          ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hi"}}}}]}})
        )

      {:ok, session} =
        Session.apply_message(session, %A2UI.Messages.DataModelUpdate{
          surface_id: "test",
          path: "/user",
          value: %{"name" => "Alice", "email" => "old@example.com"},
          protocol_version: :v0_9
        })

      {:ok, updated} =
        Session.apply_json_line(
          session,
          ~s({"dataModelUpdate":{"surfaceId":"test","path":"user","contents":[{"key":"email","valueString":"new@example.com"}]}})
        )

      user = updated.surfaces["test"].data_model["user"]
      assert user["name"] == "Alice"
      assert user["email"] == "new@example.com"
    end

    test "v0.8 DataModelUpdate merges nested maps at path" do
      session = Session.new()

      {:ok, session} =
        Session.apply_json_line(
          session,
          ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hi"}}}}]}})
        )

      {:ok, session} =
        Session.apply_message(session, %A2UI.Messages.DataModelUpdate{
          surface_id: "test",
          path: "/user",
          value: %{
            "name" => "Alice",
            "address" => %{"street" => "123 Main St", "city" => "Oldtown"}
          },
          protocol_version: :v0_9
        })

      {:ok, updated} =
        Session.apply_json_line(
          session,
          ~s({"dataModelUpdate":{"surfaceId":"test","path":"user","contents":[{"key":"address","valueMap":[{"key":"city","valueString":"Newtown"}]}]}})
        )

      user = updated.surfaces["test"].data_model["user"]
      assert user["name"] == "Alice"
      assert user["address"]["street"] == "123 Main St"
      assert user["address"]["city"] == "Newtown"
    end

    test "v0.8 DataModelUpdate overwrites scalar when nested map is required" do
      session = Session.new()

      {:ok, session} =
        Session.apply_json_line(
          session,
          ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hi"}}}}]}})
        )

      # Existing data has a scalar at /user/address, but the update wants /user/address/city.
      {:ok, session} =
        Session.apply_message(session, %A2UI.Messages.DataModelUpdate{
          surface_id: "test",
          path: "/user",
          value: %{"address" => "oops"},
          protocol_version: :v0_9
        })

      {:ok, updated} =
        Session.apply_json_line(
          session,
          ~s({"dataModelUpdate":{"surfaceId":"test","path":"user","contents":[{"key":"address","valueMap":[{"key":"city","valueString":"Newtown"}]}]}})
        )

      address = updated.surfaces["test"].data_model["user"]["address"]
      assert is_map(address)
      assert address["city"] == "Newtown"
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

  describe "catalog resolution on beginRendering" do
    setup do
      session = Session.new()

      # Create a surface first
      surface_json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hi"}}}}]}})

      {:ok, session} = Session.apply_json_line(session, surface_json)
      %{session: session}
    end

    test "nil catalogId resolves to standard catalog", %{session: session} do
      begin_json = ~s({"beginRendering":{"surfaceId":"test","root":"root"}})

      assert {:ok, updated} = Session.apply_json_line(session, begin_json)
      assert updated.surfaces["test"].ready? == true
      assert updated.surfaces["test"].catalog_id == A2UI.V0_8.standard_catalog_id()
      assert updated.surfaces["test"].catalog_status == :ok
    end

    test "standard catalog ID resolves successfully", %{session: session} do
      catalog_id = A2UI.V0_8.standard_catalog_id()

      begin_json =
        ~s({"beginRendering":{"surfaceId":"test","root":"root","catalogId":"#{catalog_id}"}})

      assert {:ok, updated} = Session.apply_json_line(session, begin_json)
      assert updated.surfaces["test"].ready? == true
      assert updated.surfaces["test"].catalog_id == catalog_id
      assert updated.surfaces["test"].catalog_status == :ok
    end

    test "standard catalog alias resolves to canonical ID", %{session: session} do
      alias_id = "a2ui.org:standard_catalog_0_8_0"

      begin_json =
        ~s({"beginRendering":{"surfaceId":"test","root":"root","catalogId":"#{alias_id}"}})

      assert {:ok, updated} = Session.apply_json_line(session, begin_json)
      assert updated.surfaces["test"].ready? == true
      # Resolves to canonical
      assert updated.surfaces["test"].catalog_id == A2UI.V0_8.standard_catalog_id()
      assert updated.surfaces["test"].catalog_status == :ok
    end

    test "unknown catalog returns error and doesn't mark ready", %{session: session} do
      begin_json =
        ~s({"beginRendering":{"surfaceId":"test","root":"root","catalogId":"https://unknown/catalog.json"}})

      assert {:error, error} = Session.apply_json_line(session, begin_json)
      assert error["error"]["type"] == "catalog_error"
      assert error["error"]["message"] =~ "standard catalog"
      assert error["error"]["surfaceId"] == "test"
      assert error["error"]["details"]["catalogId"] == "https://unknown/catalog.json"

      # Session should be unchanged (surface not updated)
      assert session.surfaces["test"].ready? == false
    end

    test "inline catalog returns error", %{session: session} do
      # Create a session with inline catalogs
      inline = %{
        "catalogId" => "inline.custom",
        "components" => %{},
        "styles" => %{}
      }

      caps = A2UI.ClientCapabilities.new(inline_catalogs: [inline])
      session = %{session | client_capabilities: caps}

      begin_json =
        ~s({"beginRendering":{"surfaceId":"test","root":"root","catalogId":"inline.custom"}})

      assert {:error, error} = Session.apply_json_line(session, begin_json)
      assert error["error"]["type"] == "catalog_error"
      assert error["error"]["message"] =~ "Inline"
    end

    test "BeginRendering message with explicit catalog", %{session: session} do
      begin_msg = %A2UI.Messages.BeginRendering{
        surface_id: "test",
        root_id: "root",
        catalog_id: A2UI.V0_8.standard_catalog_id(),
        styles: nil
      }

      assert {:ok, updated} = Session.apply_message(session, begin_msg)
      assert updated.surfaces["test"].ready? == true
      assert updated.surfaces["test"].catalog_status == :ok
    end

    test "BeginRendering message with unknown catalog", %{session: session} do
      begin_msg = %A2UI.Messages.BeginRendering{
        surface_id: "test",
        root_id: "root",
        catalog_id: "unknown.catalog",
        styles: nil
      }

      assert {:error, error} = Session.apply_message(session, begin_msg)
      assert error["error"]["type"] == "catalog_error"
    end
  end

  describe "v0.9 protocol version tracking" do
    setup do
      session = Session.new()

      # Create a surface first
      surface_json =
        ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hi"}}}}]}})

      {:ok, session} = Session.apply_json_line(session, surface_json)
      %{session: session}
    end

    test "v0.8 beginRendering stores protocol_version :v0_8", %{session: session} do
      begin_json = ~s({"beginRendering":{"surfaceId":"test","root":"root"}})

      assert {:ok, updated} = Session.apply_json_line(session, begin_json)
      assert updated.surfaces["test"].protocol_version == :v0_8
    end

    test "v0.9 createSurface stores protocol_version :v0_9", %{session: session} do
      catalog_id = A2UI.V0_8.standard_catalog_id()
      # Use v0.9 createSurface format (requires catalogId)
      begin_json = ~s({"createSurface":{"surfaceId":"test","catalogId":"#{catalog_id}"}})

      assert {:ok, updated} = Session.apply_json_line(session, begin_json)
      assert updated.surfaces["test"].protocol_version == :v0_9
    end

    test "v0.9 nil catalogId returns error (required in v0.9)", %{session: session} do
      # v0.9 createSurface without catalogId should fail
      begin_msg = %A2UI.Messages.BeginRendering{
        surface_id: "test",
        root_id: "root",
        catalog_id: nil,
        styles: nil,
        protocol_version: :v0_9
      }

      assert {:error, error} = Session.apply_message(session, begin_msg)
      assert error["error"]["type"] == "catalog_error"
      assert error["error"]["message"] =~ "required"
    end

    test "v0.9 catalogId resolves successfully", %{session: session} do
      catalog_id = A2UI.V0_8.standard_catalog_id()

      begin_msg = %A2UI.Messages.BeginRendering{
        surface_id: "test",
        root_id: "root",
        catalog_id: catalog_id,
        styles: nil,
        protocol_version: :v0_9
      }

      assert {:ok, updated} = Session.apply_message(session, begin_msg)
      assert updated.surfaces["test"].ready? == true
      assert updated.surfaces["test"].protocol_version == :v0_9
    end
  end
end
