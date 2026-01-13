defmodule A2UI.ComponentTest do
  use ExUnit.Case, async: true

  alias A2UI.Component

  describe "from_map/1 (v0.8 format)" do
    test "parses Text component" do
      data = %{
        "id" => "title",
        "component" => %{
          "Text" => %{
            "text" => %{"literalString" => "Hello"}
          }
        }
      }

      comp = Component.from_map(data)
      assert comp.id == "title"
      assert comp.type == "Text"
      assert comp.props == %{"text" => %{"literalString" => "Hello"}}
    end

    test "parses Button component" do
      data = %{
        "id" => "submit",
        "component" => %{
          "Button" => %{
            "child" => "submit_text",
            "primary" => true,
            "action" => %{"name" => "submit_form"}
          }
        }
      }

      comp = Component.from_map(data)
      assert comp.id == "submit"
      assert comp.type == "Button"
      assert comp.props["child"] == "submit_text"
      assert comp.props["primary"] == true
      assert comp.props["action"]["name"] == "submit_form"
    end

    test "parses Column component" do
      data = %{
        "id" => "main",
        "component" => %{
          "Column" => %{
            "children" => %{"explicitList" => ["a", "b", "c"]},
            "distribution" => "start",
            "alignment" => "stretch"
          }
        }
      }

      comp = Component.from_map(data)
      assert comp.id == "main"
      assert comp.type == "Column"
      assert comp.props["children"] == %{"explicitList" => ["a", "b", "c"]}
    end

    test "parses TextField component" do
      data = %{
        "id" => "email_field",
        "component" => %{
          "TextField" => %{
            "label" => %{"literalString" => "Email"},
            "text" => %{"path" => "/form/email"},
            "textFieldType" => "shortText"
          }
        }
      }

      comp = Component.from_map(data)
      assert comp.id == "email_field"
      assert comp.type == "TextField"
      assert comp.props["label"] == %{"literalString" => "Email"}
      assert comp.props["text"] == %{"path" => "/form/email"}
    end

    test "parses Checkbox component" do
      data = %{
        "id" => "subscribe",
        "component" => %{
          "Checkbox" => %{
            "label" => %{"literalString" => "Subscribe to updates"},
            "value" => %{"path" => "/form/subscribe"}
          }
        }
      }

      comp = Component.from_map(data)
      assert comp.id == "subscribe"
      assert comp.type == "Checkbox"
    end

    test "parses Card component" do
      data = %{
        "id" => "card1",
        "component" => %{
          "Card" => %{
            "child" => "card_content"
          }
        }
      }

      comp = Component.from_map(data)
      assert comp.id == "card1"
      assert comp.type == "Card"
      assert comp.props["child"] == "card_content"
    end

    test "parses Row component" do
      data = %{
        "id" => "actions",
        "component" => %{
          "Row" => %{
            "children" => %{"explicitList" => ["btn1", "btn2"]},
            "distribution" => "end"
          }
        }
      }

      comp = Component.from_map(data)
      assert comp.id == "actions"
      assert comp.type == "Row"
    end

    test "parses Divider component" do
      data = %{
        "id" => "sep",
        "component" => %{
          "Divider" => %{
            "axis" => "horizontal"
          }
        }
      }

      comp = Component.from_map(data)
      assert comp.id == "sep"
      assert comp.type == "Divider"
      assert comp.props["axis"] == "horizontal"
    end
  end

  describe "from_map_v09/1 (v0.9 format)" do
    test "parses flattened component format" do
      data = %{
        "id" => "title",
        "component" => "Text",
        "text" => %{"literalString" => "Hello"}
      }

      comp = Component.from_map_v09(data)
      assert comp.id == "title"
      assert comp.type == "Text"
      assert comp.props == %{"text" => %{"literalString" => "Hello"}}
    end

    test "parses component with multiple props" do
      data = %{
        "id" => "email_field",
        "component" => "TextField",
        "label" => %{"literalString" => "Email"},
        "text" => %{"path" => "/form/email"},
        "textFieldType" => "shortText"
      }

      comp = Component.from_map_v09(data)
      assert comp.id == "email_field"
      assert comp.type == "TextField"
      assert comp.props["label"] == %{"literalString" => "Email"}
      assert comp.props["text"] == %{"path" => "/form/email"}
      assert comp.props["textFieldType"] == "shortText"
    end
  end
end
