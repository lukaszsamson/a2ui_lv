defmodule A2UI.Props.AdapterTest do
  use ExUnit.Case, async: true

  alias A2UI.Props.Adapter

  describe "row_column_props/2" do
    test "returns v0.9 justify/align props when present" do
      props = %{"justify" => "center", "align" => "end"}
      assert Adapter.row_column_props(props) == {"center", "end"}
    end

    test "returns v0.8 distribution/alignment props when v0.9 not present" do
      props = %{"distribution" => "spaceBetween", "alignment" => "start"}
      assert Adapter.row_column_props(props) == {"spaceBetween", "start"}
    end

    test "v0.9 props take precedence over v0.8 props" do
      props = %{
        "justify" => "center",
        "align" => "end",
        "distribution" => "spaceBetween",
        "alignment" => "start"
      }

      assert Adapter.row_column_props(props) == {"center", "end"}
    end

    test "returns defaults when no props present" do
      assert Adapter.row_column_props(%{}) == {"start", "stretch"}
    end

    test "uses custom default for align" do
      assert Adapter.row_column_props(%{}, "center") == {"start", "center"}
    end

    test "handles all v0.9 justify values" do
      for justify <- [
            "start",
            "center",
            "end",
            "spaceBetween",
            "spaceAround",
            "spaceEvenly",
            "stretch"
          ] do
        props = %{"justify" => justify}
        {result_justify, _} = Adapter.row_column_props(props)
        assert result_justify == justify
      end
    end

    test "handles all v0.9 align values" do
      for align <- ["start", "center", "end", "stretch"] do
        props = %{"align" => align}
        {_, result_align} = Adapter.row_column_props(props)
        assert result_align == align
      end
    end
  end

  describe "modal_props/1" do
    test "returns v0.9 trigger/content props when present" do
      props = %{"trigger" => "open-btn", "content" => "dialog-content"}
      assert Adapter.modal_props(props) == {"open-btn", "dialog-content"}
    end

    test "returns v0.8 entryPointChild/contentChild props when v0.9 not present" do
      props = %{"entryPointChild" => "btn", "contentChild" => "content"}
      assert Adapter.modal_props(props) == {"btn", "content"}
    end

    test "v0.9 props take precedence over v0.8 props" do
      props = %{
        "trigger" => "v09-trigger",
        "content" => "v09-content",
        "entryPointChild" => "v08-entry",
        "contentChild" => "v08-content"
      }

      assert Adapter.modal_props(props) == {"v09-trigger", "v09-content"}
    end

    test "returns nil when no props present" do
      assert Adapter.modal_props(%{}) == {nil, nil}
    end
  end

  describe "tabs_props/1" do
    test "returns v0.9 tabs prop when present" do
      tabs = [%{"title" => "Tab 1", "child" => "content1"}]
      props = %{"tabs" => tabs}
      assert Adapter.tabs_props(props) == tabs
    end

    test "returns v0.8 tabItems prop when v0.9 not present" do
      items = [%{"title" => "Item 1", "child" => "c1"}]
      props = %{"tabItems" => items}
      assert Adapter.tabs_props(props) == items
    end

    test "v0.9 tabs takes precedence over v0.8 tabItems" do
      props = %{
        "tabs" => [%{"title" => "v09"}],
        "tabItems" => [%{"title" => "v08"}]
      }

      assert Adapter.tabs_props(props) == [%{"title" => "v09"}]
    end

    test "returns empty list when no props present" do
      assert Adapter.tabs_props(%{}) == []
    end
  end

  describe "variant_prop/2" do
    test "returns v0.9 variant prop when present" do
      props = %{"variant" => "h1"}
      assert Adapter.variant_prop(props) == "h1"
    end

    test "returns v0.8 usageHint prop when v0.9 not present" do
      props = %{"usageHint" => "caption"}
      assert Adapter.variant_prop(props) == "caption"
    end

    test "v0.9 variant takes precedence over v0.8 usageHint" do
      props = %{"variant" => "h1", "usageHint" => "body"}
      assert Adapter.variant_prop(props) == "h1"
    end

    test "returns default when no props present" do
      assert Adapter.variant_prop(%{}, "body") == "body"
    end

    test "returns nil when no props and no default" do
      assert Adapter.variant_prop(%{}) == nil
    end
  end

  describe "text_field_value_prop/1" do
    test "returns v0.9 value prop when present" do
      props = %{"value" => %{"path" => "/email"}}
      assert Adapter.text_field_value_prop(props) == %{"path" => "/email"}
    end

    test "returns v0.8 text prop when v0.9 not present" do
      props = %{"text" => "hello"}
      assert Adapter.text_field_value_prop(props) == "hello"
    end

    test "v0.9 value takes precedence over v0.8 text" do
      props = %{"value" => "v09-value", "text" => "v08-text"}
      assert Adapter.text_field_value_prop(props) == "v09-value"
    end

    test "returns nil when no props present" do
      assert Adapter.text_field_value_prop(%{}) == nil
    end
  end

  describe "text_field_type_prop/1" do
    test "returns v0.9 variant prop when present" do
      props = %{"variant" => "obscured"}
      assert Adapter.text_field_type_prop(props) == "obscured"
    end

    test "returns v0.8 textFieldType prop when v0.9 not present" do
      props = %{"textFieldType" => "email"}
      assert Adapter.text_field_type_prop(props) == "email"
    end

    test "v0.9 variant takes precedence over v0.8 textFieldType" do
      props = %{"variant" => "obscured", "textFieldType" => "email"}
      assert Adapter.text_field_type_prop(props) == "obscured"
    end

    test "returns shortText default when no props present" do
      assert Adapter.text_field_type_prop(%{}) == "shortText"
    end
  end

  describe "slider_range_props/1" do
    test "returns v0.9 min/max props when present" do
      props = %{"min" => 10, "max" => 90}
      assert Adapter.slider_range_props(props) == {10, 90}
    end

    test "returns v0.8 minValue/maxValue props when v0.9 not present" do
      props = %{"minValue" => 5, "maxValue" => 50}
      assert Adapter.slider_range_props(props) == {5, 50}
    end

    test "v0.9 props take precedence over v0.8 props" do
      props = %{"min" => 10, "max" => 90, "minValue" => 0, "maxValue" => 100}
      assert Adapter.slider_range_props(props) == {10, 90}
    end

    test "returns defaults when no props present" do
      assert Adapter.slider_range_props(%{}) == {0, 100}
    end
  end

  describe "choice_selections_prop/1" do
    test "returns v0.9 value prop when present" do
      props = %{"value" => %{"path" => "/selected"}}
      assert Adapter.choice_selections_prop(props) == %{"path" => "/selected"}
    end

    test "returns v0.8 selections prop when v0.9 not present" do
      props = %{"selections" => ["a", "b"]}
      assert Adapter.choice_selections_prop(props) == ["a", "b"]
    end

    test "v0.9 value takes precedence over v0.8 selections" do
      props = %{"value" => ["v09"], "selections" => ["v08"]}
      assert Adapter.choice_selections_prop(props) == ["v09"]
    end

    test "returns nil when no props present" do
      assert Adapter.choice_selections_prop(%{}) == nil
    end
  end

  describe "choice_single_select?/1" do
    test "returns true for v0.9 mutuallyExclusive variant" do
      props = %{"variant" => "mutuallyExclusive"}
      assert Adapter.choice_single_select?(props) == true
    end

    test "returns false for v0.9 multipleSelection variant" do
      props = %{"variant" => "multipleSelection"}
      assert Adapter.choice_single_select?(props) == false
    end

    test "returns true for v0.8 maxAllowedSelections = 1" do
      props = %{"maxAllowedSelections" => 1}
      assert Adapter.choice_single_select?(props) == true
    end

    test "returns false for v0.8 maxAllowedSelections > 1" do
      props = %{"maxAllowedSelections" => 3}
      assert Adapter.choice_single_select?(props) == false
    end

    test "v0.9 variant takes precedence over v0.8 maxAllowedSelections" do
      # v0.9 says multipleSelection, v0.8 says 1 - v0.9 wins
      props = %{"variant" => "multipleSelection", "maxAllowedSelections" => 1}
      assert Adapter.choice_single_select?(props) == false
    end

    test "returns false when no props present (defaults to multi)" do
      assert Adapter.choice_single_select?(%{}) == false
    end
  end
end
