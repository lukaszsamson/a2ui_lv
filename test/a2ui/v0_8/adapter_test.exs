defmodule A2UI.V0_8.AdapterTest do
  use ExUnit.Case, async: true

  alias A2UI.V0_8.Adapter

  describe "adapt_bound_value/1" do
    test "converts literalString to native string" do
      assert Adapter.adapt_bound_value(%{"literalString" => "Hello"}) == "Hello"
    end

    test "converts literalNumber to native number" do
      assert Adapter.adapt_bound_value(%{"literalNumber" => 42}) == 42
      assert Adapter.adapt_bound_value(%{"literalNumber" => 3.14}) == 3.14
    end

    test "converts literalBoolean to native boolean" do
      assert Adapter.adapt_bound_value(%{"literalBoolean" => true}) == true
      assert Adapter.adapt_bound_value(%{"literalBoolean" => false}) == false
    end

    test "converts literalArray to native array" do
      assert Adapter.adapt_bound_value(%{"literalArray" => [1, 2, 3]}) == [1, 2, 3]
      assert Adapter.adapt_bound_value(%{"literalArray" => []}) == []
    end

    test "preserves pure path binding" do
      assert Adapter.adapt_bound_value(%{"path" => "/name"}) == %{"path" => "/name"}
      assert Adapter.adapt_bound_value(%{"path" => "/user/email"}) == %{"path" => "/user/email"}
    end

    test "converts path with literal to path with _initialValue" do
      assert Adapter.adapt_bound_value(%{"path" => "/name", "literalString" => "default"}) ==
               %{"path" => "/name", "_initialValue" => "default"}

      assert Adapter.adapt_bound_value(%{"path" => "/count", "literalNumber" => 0}) ==
               %{"path" => "/count", "_initialValue" => 0}

      assert Adapter.adapt_bound_value(%{"path" => "/active", "literalBoolean" => false}) ==
               %{"path" => "/active", "_initialValue" => false}
    end

    test "passes through non-BoundValue terms" do
      assert Adapter.adapt_bound_value("string") == "string"
      assert Adapter.adapt_bound_value(42) == 42
      assert Adapter.adapt_bound_value([1, 2, 3]) == [1, 2, 3]
      assert Adapter.adapt_bound_value(%{"other" => "map"}) == %{"other" => "map"}
    end
  end

  describe "adapt_props/1" do
    test "converts literal props to native values" do
      props = %{
        "text" => %{"literalString" => "Hello"},
        "count" => %{"literalNumber" => 42},
        "active" => %{"literalBoolean" => true}
      }

      assert Adapter.adapt_props(props) == %{
               "text" => "Hello",
               "count" => 42,
               "active" => true
             }
    end

    test "converts path bindings" do
      props = %{
        "text" => %{"path" => "/name"},
        "value" => %{"path" => "/count", "literalNumber" => 0}
      }

      assert Adapter.adapt_props(props) == %{
               "text" => %{"path" => "/name"},
               "value" => %{"path" => "/count", "_initialValue" => 0}
             }
    end

    test "preserves children arrays" do
      props = %{
        "children" => ["child1", "child2"]
      }

      assert Adapter.adapt_props(props) == props
    end

    test "recursively adapts nested maps" do
      props = %{
        "action" => %{
          "event" => "submit",
          "payload" => %{"literalString" => "data"}
        }
      }

      assert Adapter.adapt_props(props) == %{
               "action" => %{
                 "event" => "submit",
                 "payload" => "data"
               }
             }
    end

    test "adapts values in arrays" do
      props = %{
        "items" => [
          %{"literalString" => "one"},
          %{"literalString" => "two"}
        ]
      }

      assert Adapter.adapt_props(props) == %{
               "items" => ["one", "two"]
             }
    end
  end

  describe "adapt_component/1" do
    test "converts v0.8 component format to v0.9" do
      v0_8 = %{
        "id" => "title",
        "component" => %{"Text" => %{"text" => %{"literalString" => "Hello"}}}
      }

      assert Adapter.adapt_component(v0_8) == %{
               "id" => "title",
               "component" => "Text",
               "text" => "Hello"
             }
    end

    test "preserves weight" do
      v0_8 = %{
        "id" => "btn",
        "weight" => 2,
        "component" => %{"Button" => %{"label" => %{"literalString" => "Click"}}}
      }

      assert Adapter.adapt_component(v0_8) == %{
               "id" => "btn",
               "weight" => 2,
               "component" => "Button",
               "label" => "Click"
             }
    end

    test "converts all prop types" do
      v0_8 = %{
        "id" => "form",
        "component" => %{
          "Form" => %{
            "title" => %{"literalString" => "Sign Up"},
            "children" => ["field1", "field2"]
          }
        }
      }

      assert Adapter.adapt_component(v0_8) == %{
               "id" => "form",
               "component" => "Form",
               "title" => "Sign Up",
               "children" => ["field1", "field2"]
             }
    end

    test "handles path bindings in props" do
      v0_8 = %{
        "id" => "input",
        "component" => %{
          "TextInput" => %{
            "value" => %{"path" => "/form/name", "literalString" => ""}
          }
        }
      }

      assert Adapter.adapt_component(v0_8) == %{
               "id" => "input",
               "component" => "TextInput",
               "value" => %{"path" => "/form/name", "_initialValue" => ""}
             }
    end
  end

  describe "adapt_surface_update/1" do
    test "converts all components in array" do
      v0_8 = %{
        "surfaceId" => "main",
        "components" => [
          %{"id" => "text1", "component" => %{"Text" => %{"text" => %{"literalString" => "Hello"}}}},
          %{"id" => "text2", "component" => %{"Text" => %{"text" => %{"literalString" => "World"}}}}
        ]
      }

      assert Adapter.adapt_surface_update(v0_8) == %{
               "surfaceId" => "main",
               "components" => [
                 %{"id" => "text1", "component" => "Text", "text" => "Hello"},
                 %{"id" => "text2", "component" => "Text", "text" => "World"}
               ]
             }
    end
  end

  describe "adapt_contents_to_value/1" do
    test "converts valueString entries" do
      contents = [%{"key" => "name", "valueString" => "Alice"}]
      assert Adapter.adapt_contents_to_value(contents) == %{"name" => "Alice"}
    end

    test "converts valueNumber entries" do
      contents = [%{"key" => "age", "valueNumber" => 30}]
      assert Adapter.adapt_contents_to_value(contents) == %{"age" => 30}
    end

    test "converts valueBoolean entries" do
      contents = [%{"key" => "active", "valueBoolean" => true}]
      assert Adapter.adapt_contents_to_value(contents) == %{"active" => true}
    end

    test "converts valueMap entries" do
      contents = [
        %{
          "key" => "user",
          "valueMap" => [
            %{"key" => "name", "valueString" => "Alice"},
            %{"key" => "age", "valueNumber" => 30}
          ]
        }
      ]

      assert Adapter.adapt_contents_to_value(contents) == %{
               "user" => %{"name" => "Alice", "age" => 30}
             }
    end

    test "converts mixed entries" do
      contents = [
        %{"key" => "name", "valueString" => "Alice"},
        %{"key" => "age", "valueNumber" => 30},
        %{"key" => "active", "valueBoolean" => true}
      ]

      assert Adapter.adapt_contents_to_value(contents) == %{
               "name" => "Alice",
               "age" => 30,
               "active" => true
             }
    end

    test "skips invalid entries" do
      contents = [
        %{"key" => "valid", "valueString" => "ok"},
        %{"invalid" => "entry"},
        %{"key" => "also_valid", "valueNumber" => 42}
      ]

      assert Adapter.adapt_contents_to_value(contents) == %{
               "valid" => "ok",
               "also_valid" => 42
             }
    end

    test "returns empty map for non-list input" do
      assert Adapter.adapt_contents_to_value(nil) == %{}
      assert Adapter.adapt_contents_to_value("string") == %{}
    end
  end

  describe "adapt_data_model_update/1" do
    test "converts contents to value at root" do
      v0_8 = %{
        "surfaceId" => "main",
        "contents" => [%{"key" => "name", "valueString" => "Alice"}]
      }

      assert Adapter.adapt_data_model_update(v0_8) == %{
               "surfaceId" => "main",
               "value" => %{"name" => "Alice"}
             }
    end

    test "preserves path" do
      v0_8 = %{
        "surfaceId" => "main",
        "path" => "/user",
        "contents" => [%{"key" => "name", "valueString" => "Alice"}]
      }

      assert Adapter.adapt_data_model_update(v0_8) == %{
               "surfaceId" => "main",
               "path" => "/user",
               "value" => %{"name" => "Alice"}
             }
    end

    test "handles empty contents" do
      v0_8 = %{"surfaceId" => "main"}

      assert Adapter.adapt_data_model_update(v0_8) == %{
               "surfaceId" => "main",
               "value" => %{}
             }
    end
  end
end
