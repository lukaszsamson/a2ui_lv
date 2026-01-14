defmodule A2UI.ValidatorTest do
  use ExUnit.Case, async: true

  alias A2UI.Validator
  alias A2UI.Component

  describe "validate_surface_update/1" do
    test "accepts valid update with few components" do
      components = [
        %Component{id: "a", type: "Text", props: %{}},
        %Component{id: "b", type: "Button", props: %{}}
      ]

      assert :ok = Validator.validate_surface_update(%{components: components})
    end

    test "accepts all allowed component types" do
      types = Validator.allowed_types()

      components =
        Enum.with_index(types)
        |> Enum.map(fn {type, idx} ->
          %Component{id: "comp_#{idx}", type: type, props: %{}}
        end)

      assert :ok = Validator.validate_surface_update(%{components: components})
    end
  end

  describe "validate_count/1" do
    test "accepts components under limit" do
      components =
        Enum.map(1..100, fn i ->
          %Component{id: "#{i}", type: "Text", props: %{}}
        end)

      assert :ok = Validator.validate_count(components)
    end

    test "accepts exactly max components" do
      components =
        Enum.map(1..Validator.max_components(), fn i ->
          %Component{id: "#{i}", type: "Text", props: %{}}
        end)

      assert :ok = Validator.validate_count(components)
    end

    test "rejects components over limit" do
      components =
        Enum.map(1..(Validator.max_components() + 1), fn i ->
          %Component{id: "#{i}", type: "Text", props: %{}}
        end)

      assert {:error, {:too_many_components, count, max}} = Validator.validate_count(components)
      assert count == Validator.max_components() + 1
      assert max == Validator.max_components()
    end
  end

  describe "validate_types/1" do
    test "accepts all allowed types" do
      for type <- Validator.allowed_types() do
        components = [%Component{id: "test", type: type, props: %{}}]
        assert :ok = Validator.validate_types(components)
      end
    end

    test "rejects unknown types" do
      components = [
        %Component{id: "a", type: "Text", props: %{}},
        %Component{id: "b", type: "UnknownWidget", props: %{}},
        %Component{id: "c", type: "CustomThing", props: %{}}
      ]

      assert {:error, {:unknown_component_types, types}} = Validator.validate_types(components)
      assert "UnknownWidget" in types
      assert "CustomThing" in types
      assert length(types) == 2
    end
  end

  describe "validate_depth/1" do
    test "accepts depth under limit" do
      assert :ok = Validator.validate_depth(10)
      assert :ok = Validator.validate_depth(0)
    end

    test "accepts exactly max depth" do
      assert :ok = Validator.validate_depth(Validator.max_depth())
    end

    test "rejects depth over limit" do
      over_limit = Validator.max_depth() + 1

      assert {:error, {:max_depth_exceeded, ^over_limit, max}} =
               Validator.validate_depth(over_limit)

      assert max == Validator.max_depth()
    end
  end

  describe "validate_template_items/1" do
    test "accepts items under limit" do
      assert :ok = Validator.validate_template_items(50)
    end

    test "accepts exactly max items" do
      assert :ok = Validator.validate_template_items(Validator.max_template_items())
    end

    test "rejects items over limit" do
      over_limit = Validator.max_template_items() + 1

      assert {:error, {:too_many_template_items, ^over_limit, max}} =
               Validator.validate_template_items(over_limit)

      assert max == Validator.max_template_items()
    end
  end

  describe "validate_data_model_size/1" do
    test "accepts small data model" do
      data = %{"name" => "Alice", "items" => [1, 2, 3]}
      assert :ok = Validator.validate_data_model_size(data)
    end

    test "accepts empty data model" do
      assert :ok = Validator.validate_data_model_size(%{})
    end
  end
end
