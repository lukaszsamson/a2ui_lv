defmodule A2UI.V0_8.Adapter do
  @moduledoc """
  Adapts v0.8 wire format to v0.9-native internal representation.

  This module converts v0.8 wire format elements to v0.9-native equivalents at parse time,
  allowing downstream code to work with a single canonical internal representation.

  ## Conversion Rules

  ### BoundValue Conversion
  - `{"literalString" => "x"}` → `"x"` (native string)
  - `{"literalNumber" => 42}` → `42` (native number)
  - `{"literalBoolean" => true}` → `true` (native boolean)
  - `{"literalArray" => [...]}` → `[...]` (native array)
  - `{"path" => "/x"}` → `{"path" => "/x"}` (unchanged)
  - `{"path" => "/x", "literalString" => "default"}` → `{"path" => "/x", "_initialValue" => "default"}`

  ### Component Conversion
  - v0.8: `{"id" => "x", "component" => %{"Text" => %{...}}}`
  - v0.9: `{"id" => "x", "component" => "Text", ...props}`

  ### DataModelUpdate Conversion
  - v0.8: Adjacency-list `contents` with typed values
  - v0.9: Native JSON `value`
  """

  alias A2UI.BoundValue

  # ============================================
  # Component Adaptation
  # ============================================

  @doc """
  Converts a v0.8 component map to v0.9 format.

  v0.8 format: `{"id" => "x", "component" => %{"Text" => %{"text" => {...}}}}`
  v0.9 format: `{"id" => "x", "component" => "Text", "text" => {...}}`

  ## Examples

      iex> A2UI.V0_8.Adapter.adapt_component(%{"id" => "title", "component" => %{"Text" => %{"text" => %{"literalString" => "Hello"}}}})
      %{"id" => "title", "component" => "Text", "text" => "Hello"}

      iex> A2UI.V0_8.Adapter.adapt_component(%{"id" => "btn", "weight" => 1, "component" => %{"Button" => %{"label" => %{"literalString" => "Click"}}}})
      %{"id" => "btn", "weight" => 1, "component" => "Button", "label" => "Click"}
  """
  @spec adapt_component(map()) :: map()
  def adapt_component(%{"id" => id, "component" => %{} = wrapper} = data) do
    [{type, props}] = Map.to_list(wrapper)
    adapted_props = adapt_props(props)

    base = %{"id" => id, "component" => type}

    base =
      case Map.get(data, "weight") do
        nil -> base
        weight -> Map.put(base, "weight", weight)
      end

    Map.merge(base, adapted_props)
  end

  # ============================================
  # SurfaceUpdate Adaptation
  # ============================================

  @doc """
  Adapts a v0.8 surfaceUpdate message to v0.9 format.

  Converts each component in the components array.
  """
  @spec adapt_surface_update(map()) :: map()
  def adapt_surface_update(%{"surfaceId" => sid, "components" => comps}) do
    adapted_components = Enum.map(comps, &adapt_component/1)
    %{"surfaceId" => sid, "components" => adapted_components}
  end

  # ============================================
  # DataModelUpdate Adaptation
  # ============================================

  @doc """
  Adapts a v0.8 dataModelUpdate message to v0.9 format.

  Converts adjacency-list `contents` to native JSON `value`.

  ## Examples

      iex> A2UI.V0_8.Adapter.adapt_data_model_update(%{"surfaceId" => "main", "contents" => [%{"key" => "name", "valueString" => "Alice"}]})
      %{"surfaceId" => "main", "value" => %{"name" => "Alice"}}

      iex> A2UI.V0_8.Adapter.adapt_data_model_update(%{"surfaceId" => "main", "path" => "/user", "contents" => [%{"key" => "name", "valueString" => "Alice"}]})
      %{"surfaceId" => "main", "path" => "/user", "value" => %{"name" => "Alice"}}
  """
  @spec adapt_data_model_update(map()) :: map()
  def adapt_data_model_update(%{"surfaceId" => sid} = data) do
    contents = Map.get(data, "contents", [])
    value = adapt_contents_to_value(contents)

    result = %{"surfaceId" => sid, "value" => value}

    case Map.get(data, "path") do
      nil -> result
      path -> Map.put(result, "path", path)
    end
  end

  @doc """
  Converts v0.8 adjacency-list contents to a native JSON value (map).

  ## v0.8 Contents Format

  Each entry has a `key` and one of: `valueString`, `valueNumber`, `valueBoolean`, `valueMap`.

  ## Examples

      iex> A2UI.V0_8.Adapter.adapt_contents_to_value([%{"key" => "name", "valueString" => "Alice"}])
      %{"name" => "Alice"}

      iex> A2UI.V0_8.Adapter.adapt_contents_to_value([
      ...>   %{"key" => "name", "valueString" => "Alice"},
      ...>   %{"key" => "age", "valueNumber" => 30}
      ...> ])
      %{"name" => "Alice", "age" => 30}
  """
  @spec adapt_contents_to_value(list()) :: map()
  def adapt_contents_to_value(contents) when is_list(contents) do
    Enum.reduce(contents, %{}, fn entry, acc ->
      case decode_contents_entry(entry) do
        {:ok, {key, value}} -> Map.put(acc, key, value)
        :error -> acc
      end
    end)
  end

  def adapt_contents_to_value(_), do: %{}

  # ============================================
  # BoundValue Adaptation
  # ============================================

  @doc """
  Converts a v0.8 BoundValue to v0.9 format.

  ## Conversion Rules

  - Pure literal: `{"literalString" => "x"}` → `"x"`
  - Pure path: `{"path" => "/x"}` → `{"path" => "/x"}` (unchanged)
  - Path with default: `{"path" => "/x", "literalString" => "y"}` → `{"path" => "/x", "_initialValue" => "y"}`

  ## Examples

      iex> A2UI.V0_8.Adapter.adapt_bound_value(%{"literalString" => "Hello"})
      "Hello"

      iex> A2UI.V0_8.Adapter.adapt_bound_value(%{"literalNumber" => 42})
      42

      iex> A2UI.V0_8.Adapter.adapt_bound_value(%{"path" => "/name"})
      %{"path" => "/name"}

      iex> A2UI.V0_8.Adapter.adapt_bound_value(%{"path" => "/name", "literalString" => "default"})
      %{"path" => "/name", "_initialValue" => "default"}
  """
  @spec adapt_bound_value(map()) :: term()
  def adapt_bound_value(%{"path" => path} = term) when is_binary(path) do
    # Has a path binding - check for initial value
    case BoundValue.extract_literal(term) do
      {:ok, initial_value} ->
        %{"path" => path, "_initialValue" => initial_value}

      :error ->
        %{"path" => path}
    end
  end

  def adapt_bound_value(%{} = term) do
    # No path - check if it's a pure literal
    case BoundValue.extract_literal(term) do
      {:ok, value} -> value
      :error -> term
    end
  end

  def adapt_bound_value(term), do: term

  # ============================================
  # Props Adaptation
  # ============================================

  @doc """
  Recursively adapts v0.8 props to v0.9 format.

  Walks through the props map and converts any BoundValue terms.

  ## Examples

      iex> A2UI.V0_8.Adapter.adapt_props(%{"text" => %{"literalString" => "Hello"}})
      %{"text" => "Hello"}

      iex> A2UI.V0_8.Adapter.adapt_props(%{"text" => %{"path" => "/name", "literalString" => "default"}})
      %{"text" => %{"path" => "/name", "_initialValue" => "default"}}

      iex> A2UI.V0_8.Adapter.adapt_props(%{"children" => ["child1", "child2"]})
      %{"children" => ["child1", "child2"]}
  """
  @spec adapt_props(map()) :: map()
  def adapt_props(props) when is_map(props) do
    Map.new(props, fn {key, value} ->
      {key, adapt_prop_value(value)}
    end)
  end

  def adapt_props(term), do: term

  # ============================================
  # Private: Prop Value Adaptation
  # ============================================

  defp adapt_prop_value(%{} = term) do
    if bound_value?(term) do
      adapt_bound_value(term)
    else
      # Not a BoundValue, recurse into nested maps
      adapt_props(term)
    end
  end

  defp adapt_prop_value(term) when is_list(term) do
    Enum.map(term, &adapt_prop_value/1)
  end

  defp adapt_prop_value(term), do: term

  # ============================================
  # Private: BoundValue Detection and Extraction
  # ============================================

  defp bound_value?(%{"path" => path}) when is_binary(path), do: true

  defp bound_value?(term) when is_map(term) do
    Enum.any?(BoundValue.literal_keys(), &Map.has_key?(term, &1))
  end

  defp bound_value?(_), do: false

  # ============================================
  # Private: Contents Decoding
  # ============================================

  defp decode_contents_entry(%{"key" => key} = entry) when is_binary(key) do
    cond do
      Map.has_key?(entry, "valueString") and is_binary(entry["valueString"]) ->
        {:ok, {key, entry["valueString"]}}

      Map.has_key?(entry, "valueNumber") and is_number(entry["valueNumber"]) ->
        {:ok, {key, entry["valueNumber"]}}

      Map.has_key?(entry, "valueBoolean") and is_boolean(entry["valueBoolean"]) ->
        {:ok, {key, entry["valueBoolean"]}}

      Map.has_key?(entry, "valueMap") and is_list(entry["valueMap"]) ->
        {:ok, {key, decode_value_map(entry["valueMap"])}}

      true ->
        :error
    end
  end

  defp decode_contents_entry(_), do: :error

  # v0.8 valueMap entries only support scalar typed values (no nested valueMap)
  defp decode_value_map(entries) when is_list(entries) do
    Enum.reduce(entries, %{}, fn entry, acc ->
      case decode_value_map_entry(entry) do
        {:ok, {key, value}} -> Map.put(acc, key, value)
        :error -> acc
      end
    end)
  end

  defp decode_value_map_entry(%{"key" => key} = entry) when is_binary(key) do
    cond do
      Map.has_key?(entry, "valueString") and is_binary(entry["valueString"]) ->
        {:ok, {key, entry["valueString"]}}

      Map.has_key?(entry, "valueNumber") and is_number(entry["valueNumber"]) ->
        {:ok, {key, entry["valueNumber"]}}

      Map.has_key?(entry, "valueBoolean") and is_boolean(entry["valueBoolean"]) ->
        {:ok, {key, entry["valueBoolean"]}}

      true ->
        :error
    end
  end

  defp decode_value_map_entry(_), do: :error
end
