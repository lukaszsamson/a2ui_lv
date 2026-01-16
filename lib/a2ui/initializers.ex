defmodule A2UI.Initializers do
  @moduledoc """
  Applies the v0.8 "initializer pass" for `BoundValue`s with both `path` and `literal*`.

  Per the A2UI v0.8 protocol spec (section 4.2 "Data Binding"):

  > If **both** `path` and a `literal*` value are provided, the client MUST:
  > 1. Update the data model at the specified `path` with the provided `literal*` value.
  > 2. Bind the component property to that `path` for rendering and future updates.

  This means the literal value **always overwrites** any existing value at the path.
  This is an "implicit dataModelUpdate" that happens as part of surfaceUpdate processing.

  ## Numeric Segments

  Paths with numeric segments (e.g., `/items/0/name`) are fully supported. In v0.8,
  collections are map-based (the wire format uses `valueMap`, not arrays), so paths
  like `/items/0/name` create `%{"items" => %{"0" => %{"name" => "value"}}}`.

  This matches the v0.8 wire format where template collections use maps with numeric
  string keys rather than JSON arrays.
  """

  alias A2UI.{Binding, Component, JsonPointer}

  @literal_keys ~w(literalString literalNumber literalBoolean literalArray)

  @spec apply(map(), [Component.t()]) :: map()
  def apply(data_model, components) when is_map(data_model) and is_list(components) do
    Enum.reduce(components, data_model, fn %Component{} = component, acc ->
      props = component.props || %{}
      apply_in_term(acc, props, [])
    end)
  end

  defp apply_in_term(data_model, %{} = term, path) do
    cond do
      bound_value_with_literal?(term) ->
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

  defp bound_value_with_literal?(%{"path" => path} = term) when is_binary(path) do
    Enum.any?(@literal_keys, &Map.has_key?(term, &1))
  end

  defp bound_value_with_literal?(_), do: false

  defp initialize(data_model, %{"path" => raw_path} = term) do
    pointer = Binding.expand_path(raw_path, nil)

    # Per spec: always overwrite with the literal value (implicit dataModelUpdate)
    # Use v0.8 semantics: creates maps for missing containers (matches valueMap wire format)
    case literal_value(term) do
      {:ok, value} -> JsonPointer.upsert(data_model, pointer, value, version: :v0_8)
      :error -> data_model
    end
  end

  defp literal_value(term) do
    cond do
      Map.has_key?(term, "literalString") -> {:ok, term["literalString"]}
      Map.has_key?(term, "literalNumber") -> {:ok, term["literalNumber"]}
      Map.has_key?(term, "literalBoolean") -> {:ok, term["literalBoolean"]}
      Map.has_key?(term, "literalArray") -> {:ok, term["literalArray"]}
      true -> :error
    end
  end
end
