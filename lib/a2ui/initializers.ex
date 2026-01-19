defmodule A2UI.Initializers do
  @moduledoc """
  Applies initializers from surfaceUpdate components to the data model.

  Per A2UI spec section 4.2: BoundValues with both path and literal are
  implicit dataModelUpdates that must set the path to the literal value.

  ## Internal Representation

  After v0.8 adapter conversion, BoundValues with initial values use the
  `_initialValue` key:

      # v0.9-native format (after adapter conversion)
      %{"path" => "/form/name", "_initialValue" => "Alice"}

  ## Example

      # Component with path + initial value binding
      props = %{
        "text" => %{"path" => "/form/name", "_initialValue" => "Alice"}
      }

      # After apply, data_model will have:
      %{"form" => %{"name" => "Alice"}}
  """

  alias A2UI.{Binding, Component, JsonPointer}

  @spec apply(map(), [Component.t()]) :: map()
  def apply(data_model, components) when is_map(data_model) and is_list(components) do
    Enum.reduce(components, data_model, fn %Component{} = component, acc ->
      props = component.props || %{}
      apply_in_term(acc, props, [])
    end)
  end

  defp apply_in_term(data_model, %{} = term, path) do
    cond do
      bound_value_with_initial?(term) ->
        initialize(data_model, term)

      true ->
        Enum.reduce(term, data_model, fn
          {"action", _value}, acc ->
            acc

          {key, value}, acc ->
            apply_in_term(acc, value, [key | path])
        end)
    end
  end

  defp apply_in_term(data_model, term, path) when is_list(term) do
    Enum.reduce(term, data_model, fn value, acc ->
      apply_in_term(acc, value, path)
    end)
  end

  defp apply_in_term(data_model, _term, _path), do: data_model

  # After adapter conversion, path bindings with initial values have _initialValue
  defp bound_value_with_initial?(%{"path" => path, "_initialValue" => _}) when is_binary(path) do
    true
  end

  defp bound_value_with_initial?(_), do: false

  defp initialize(data_model, %{"path" => raw_path, "_initialValue" => value}) do
    pointer = Binding.expand_path(raw_path, nil)

    # Per spec: always overwrite with the initial value (implicit dataModelUpdate)
    JsonPointer.upsert(data_model, pointer, value)
  end
end
