defmodule A2UI.SurfaceTest do
  use ExUnit.Case, async: true

  alias A2UI.Surface
  alias A2UI.Component
  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering}

  describe "new/1" do
    test "creates empty surface with ID" do
      surface = Surface.new("test")
      assert surface.id == "test"
      assert surface.components == %{}
      assert surface.data_model == %{}
      assert surface.ready? == false
      assert surface.root_id == nil
      assert surface.catalog_id == nil
      assert surface.styles == nil
    end
  end

  describe "apply_message/2 with SurfaceUpdate" do
    test "adds new components" do
      surface = Surface.new("test")

      update = %SurfaceUpdate{
        surface_id: "test",
        components: [
          %Component{id: "a", type: "Text", props: %{"text" => %{"literalString" => "hello"}}}
        ]
      }

      surface = Surface.apply_message(surface, update)
      assert Map.has_key?(surface.components, "a")
      assert surface.components["a"].type == "Text"
    end

    test "merges components by ID (updates existing)" do
      surface = Surface.new("test")

      # Add initial component
      update1 = %SurfaceUpdate{
        surface_id: "test",
        components: [
          %Component{id: "a", type: "Text", props: %{"text" => %{"literalString" => "hello"}}}
        ]
      }

      surface = Surface.apply_message(surface, update1)
      assert surface.components["a"].props == %{"text" => %{"literalString" => "hello"}}

      # Update same component
      update2 = %SurfaceUpdate{
        surface_id: "test",
        components: [
          %Component{id: "a", type: "Text", props: %{"text" => %{"literalString" => "world"}}}
        ]
      }

      surface = Surface.apply_message(surface, update2)
      assert surface.components["a"].props == %{"text" => %{"literalString" => "world"}}
    end

    test "adds multiple components" do
      surface = Surface.new("test")

      update = %SurfaceUpdate{
        surface_id: "test",
        components: [
          %Component{id: "a", type: "Text", props: %{}},
          %Component{id: "b", type: "Button", props: %{}},
          %Component{id: "c", type: "Column", props: %{}}
        ]
      }

      surface = Surface.apply_message(surface, update)
      assert Map.keys(surface.components) |> Enum.sort() == ["a", "b", "c"]
    end

    test "initializer pass sets data model defaults for path+literal bound values" do
      surface = Surface.new("test")

      update = %SurfaceUpdate{
        surface_id: "test",
        components: [
          %Component{
            id: "name_field",
            type: "TextField",
            props: %{
              "text" => %{"path" => "/form/name", "literalString" => "Alice"}
            }
          }
        ]
      }

      surface = Surface.apply_message(surface, update)
      assert surface.data_model == %{"form" => %{"name" => "Alice"}}
    end

    test "initializer pass overwrites existing data model values (per v0.8 spec)" do
      # Per A2UI v0.8 spec section 4.2: path+literal is an implicit dataModelUpdate
      # that MUST update the data model at the path with the literal value
      surface = %Surface{id: "test", data_model: %{"form" => %{"name" => "Bob"}}}

      update = %SurfaceUpdate{
        surface_id: "test",
        components: [
          %Component{
            id: "name_field",
            type: "TextField",
            props: %{
              "text" => %{"path" => "/form/name", "literalString" => "Alice"}
            }
          }
        ]
      }

      surface = Surface.apply_message(surface, update)
      # "Alice" overwrites "Bob" per spec
      assert surface.data_model == %{"form" => %{"name" => "Alice"}}
    end

    test "initializer pass skips pointers with numeric segments" do
      surface = Surface.new("test")

      update = %SurfaceUpdate{
        surface_id: "test",
        components: [
          %Component{
            id: "name",
            type: "Text",
            props: %{
              "text" => %{"path" => "/items/0/name", "literalString" => "Alice"}
            }
          }
        ]
      }

      surface = Surface.apply_message(surface, update)
      assert surface.data_model == %{}
    end

    test "initializer pass works with root path" do
      surface = Surface.new("test")

      update = %SurfaceUpdate{
        surface_id: "test",
        components: [
          %Component{
            id: "status",
            type: "Text",
            props: %{
              "text" => %{"path" => "/status", "literalString" => "ready"}
            }
          }
        ]
      }

      surface = Surface.apply_message(surface, update)
      assert surface.data_model == %{"status" => "ready"}
    end
  end

  describe "apply_message/2 with DataModelUpdate" do
    test "updates data model at root" do
      surface = Surface.new("test")

      update = %DataModelUpdate{
        surface_id: "test",
        path: nil,
        contents: [
          %{"key" => "name", "valueString" => "Alice"},
          %{"key" => "age", "valueNumber" => 30}
        ]
      }

      surface = Surface.apply_message(surface, update)
      assert surface.data_model == %{"name" => "Alice", "age" => 30}
    end

    test "replaces the entire data model when path is omitted" do
      surface = %Surface{id: "test", data_model: %{"old" => "value"}}

      update = %DataModelUpdate{
        surface_id: "test",
        path: nil,
        contents: [%{"key" => "name", "valueString" => "Alice"}]
      }

      surface = Surface.apply_message(surface, update)
      assert surface.data_model == %{"name" => "Alice"}
    end

    test "replaces the entire data model when path is '/'" do
      surface = %Surface{id: "test", data_model: %{"old" => "value"}}

      update = %DataModelUpdate{
        surface_id: "test",
        path: "/",
        contents: [%{"key" => "name", "valueString" => "Alice"}]
      }

      surface = Surface.apply_message(surface, update)
      assert surface.data_model == %{"name" => "Alice"}
    end

    test "updates data model at path" do
      surface = Surface.new("test")

      update = %DataModelUpdate{
        surface_id: "test",
        path: "/form",
        contents: [
          %{"key" => "email", "valueString" => "test@example.com"}
        ]
      }

      surface = Surface.apply_message(surface, update)
      assert surface.data_model == %{"form" => %{"email" => "test@example.com"}}
    end

    test "handles valueMap" do
      surface = Surface.new("test")

      update = %DataModelUpdate{
        surface_id: "test",
        path: nil,
        contents: [
          %{
            "key" => "user",
            "valueMap" => [
              %{"key" => "name", "valueString" => "Alice"},
              %{"key" => "email", "valueString" => "alice@example.com"}
            ]
          }
        ]
      }

      surface = Surface.apply_message(surface, update)

      assert surface.data_model == %{
               "user" => %{
                 "name" => "Alice",
                 "email" => "alice@example.com"
               }
             }
    end

    test "ignores out-of-schema valueArray entries" do
      surface = Surface.new("test")

      update = %DataModelUpdate{
        surface_id: "test",
        path: nil,
        contents: [
          %{
            "key" => "items",
            "valueArray" => [
              %{"valueString" => "a"},
              %{"valueString" => "b"}
            ]
          }
        ]
      }

      surface = Surface.apply_message(surface, update)
      assert surface.data_model == %{}
    end

    test "handles valueBoolean" do
      surface = Surface.new("test")

      update = %DataModelUpdate{
        surface_id: "test",
        path: nil,
        contents: [
          %{"key" => "active", "valueBoolean" => true},
          %{"key" => "disabled", "valueBoolean" => false}
        ]
      }

      surface = Surface.apply_message(surface, update)
      assert surface.data_model == %{"active" => true, "disabled" => false}
    end
  end

  describe "apply_message/2 with BeginRendering" do
    test "sets ready flag and root_id" do
      surface = Surface.new("test")

      render = %BeginRendering{
        surface_id: "test",
        root_id: "root",
        catalog_id: nil,
        styles: nil,
        protocol_version: :v0_8
      }

      surface = Surface.apply_message(surface, render)
      assert surface.ready? == true
      assert surface.root_id == "root"
      assert surface.styles == nil
    end

    test "sets catalog_id" do
      surface = Surface.new("test")

      render = %BeginRendering{
        surface_id: "test",
        root_id: "root",
        catalog_id: "standard",
        styles: nil,
        protocol_version: :v0_8
      }

      surface = Surface.apply_message(surface, render)
      assert surface.catalog_id == "standard"
      assert surface.styles == nil
    end

    test "stores protocol_version from v0.8 message" do
      surface = Surface.new("test")

      render = %BeginRendering{
        surface_id: "test",
        root_id: "root",
        catalog_id: nil,
        styles: nil,
        protocol_version: :v0_8
      }

      surface = Surface.apply_message(surface, render)
      assert surface.protocol_version == :v0_8
    end

    test "stores protocol_version from v0.9 message" do
      surface = Surface.new("test")

      render = %BeginRendering{
        surface_id: "test",
        root_id: "root",
        catalog_id: "test.catalog",
        styles: nil,
        protocol_version: :v0_9
      }

      surface = Surface.apply_message(surface, render)
      assert surface.protocol_version == :v0_9
    end
  end

  describe "update_data_at_path/3" do
    test "updates simple path" do
      surface = %Surface{
        id: "test",
        data_model: %{"form" => %{"name" => ""}}
      }

      surface = Surface.update_data_at_path(surface, "/form/name", "Alice")
      assert surface.data_model == %{"form" => %{"name" => "Alice"}}
    end

    test "creates path if missing" do
      surface = %Surface{
        id: "test",
        data_model: %{}
      }

      surface = Surface.update_data_at_path(surface, "/form/name", "Alice")
      assert surface.data_model == %{"form" => %{"name" => "Alice"}}
    end

    test "updates array element" do
      surface = %Surface{
        id: "test",
        data_model: %{"items" => ["a", "b", "c"]}
      }

      surface = Surface.update_data_at_path(surface, "/items/1", "x")
      assert surface.data_model == %{"items" => ["a", "x", "c"]}
    end

    test "updates boolean value" do
      surface = %Surface{
        id: "test",
        data_model: %{"form" => %{"subscribe" => false}}
      }

      surface = Surface.update_data_at_path(surface, "/form/subscribe", true)
      assert surface.data_model == %{"form" => %{"subscribe" => true}}
    end
  end
end
