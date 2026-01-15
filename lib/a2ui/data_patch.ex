defmodule A2UI.DataPatch do
  @moduledoc """
  Internal abstraction for data model updates.

  This module provides a version-agnostic representation of data model changes,
  allowing the renderer to work with a single internal format regardless of
  whether updates arrive in v0.8 or v0.9 wire format.

  ## Patch Operations

  - `{:replace_root, value}` - Replace the entire data model
  - `{:set_at, pointer, value}` - Set any JSON value at a path
  - `{:merge_at, pointer, map_value}` - Deep merge a map at a path

  ## Wire Format Support

  - v0.8: Adjacency-list `contents` with typed values (`valueString`, etc.)
  - v0.9: Native JSON `value` at `path`

  ## Examples

      # Create patch from v0.8 wire format
      patch = DataPatch.from_v0_8_contents(nil, [
        %{"key" => "name", "valueString" => "Alice"}
      ])
      #=> {:replace_root, %{"name" => "Alice"}}

      # Create patch from v0.9 wire format (future)
      patch = DataPatch.from_v0_9_update("/user", %{"name" => "Alice"})
      #=> {:set_at, "/user", %{"name" => "Alice"}}

      # Apply patch to data model
      new_data = DataPatch.apply(%{}, patch)
  """

  alias A2UI.Binding

  @type json_value :: String.t() | number() | boolean() | map() | list() | nil
  @type pointer :: String.t()

  @type patch ::
          {:replace_root, json_value()}
          | {:set_at, pointer(), json_value()}
          | {:merge_at, pointer(), map()}

  # ============================================
  # Patch Application
  # ============================================

  @doc """
  Applies a patch operation to a data model.

  ## Patch Types

  - `{:replace_root, value}` - Replaces the entire data model with `value`
  - `{:set_at, pointer, value}` - Sets `value` at the JSON Pointer path
  - `{:merge_at, pointer, map}` - Merges `map` into the existing map at path

  ## Examples

      iex> A2UI.DataPatch.apply_patch(%{}, {:replace_root, %{"name" => "Alice"}})
      %{"name" => "Alice"}

      iex> A2UI.DataPatch.apply_patch(%{"user" => %{"age" => 30}}, {:set_at, "/user/name", "Alice"})
      %{"user" => %{"age" => 30, "name" => "Alice"}}

      iex> A2UI.DataPatch.apply_patch(%{"user" => %{"age" => 30}}, {:merge_at, "/user", %{"name" => "Alice"}})
      %{"user" => %{"age" => 30, "name" => "Alice"}}
  """
  @spec apply_patch(map(), patch()) :: map()
  def apply_patch(_data_model, {:replace_root, value}) when is_map(value) do
    value
  end

  def apply_patch(_data_model, {:replace_root, _value}) do
    # Non-map replace_root results in empty map (safety)
    %{}
  end

  def apply_patch(data_model, {:set_at, pointer, value}) do
    Binding.set_at_pointer(data_model, pointer, value)
  end

  def apply_patch(data_model, {:merge_at, pointer, map_value}) when is_map(map_value) do
    existing = Binding.get_at_pointer(data_model, pointer)
    existing_map = if is_map(existing), do: existing, else: %{}
    merged = Map.merge(existing_map, map_value)
    Binding.set_at_pointer(data_model, pointer, merged)
  end

  def apply_patch(data_model, {:merge_at, _pointer, _non_map}) do
    # merge_at with non-map is a no-op
    data_model
  end

  @doc """
  Applies a list of patches in order.

  ## Example

      iex> patches = [
      ...>   {:set_at, "/user/name", "Alice"},
      ...>   {:set_at, "/user/age", 30}
      ...> ]
      iex> A2UI.DataPatch.apply_all(%{}, patches)
      %{"user" => %{"name" => "Alice", "age" => 30}}
  """
  @spec apply_all(map(), [patch()]) :: map()
  def apply_all(data_model, patches) when is_list(patches) do
    Enum.reduce(patches, data_model, &apply_patch(&2, &1))
  end

  # ============================================
  # v0.8 Wire Format Decoder
  # ============================================

  @doc """
  Creates a patch from v0.8 `dataModelUpdate` wire format.

  ## Parameters

  - `path` - The path from the wire message (can be `nil`, `""`, `"/"`, or a pointer)
  - `contents` - The adjacency-list contents array

  ## v0.8 Wire Format

  The v0.8 format uses typed value entries:
  ```json
  {"dataModelUpdate": {
    "path": "/user",
    "contents": [
      {"key": "name", "valueString": "Alice"},
      {"key": "age", "valueNumber": 30}
    ]
  }}
  ```

  ## Examples

      iex> A2UI.DataPatch.from_v0_8_contents(nil, [%{"key" => "name", "valueString" => "Alice"}])
      {:replace_root, %{"name" => "Alice"}}

      iex> A2UI.DataPatch.from_v0_8_contents("/user", [%{"key" => "name", "valueString" => "Alice"}])
      {:merge_at, "/user", %{"name" => "Alice"}}
  """
  @spec from_v0_8_contents(String.t() | nil, list()) :: patch()
  def from_v0_8_contents(path, contents) when is_list(contents) do
    decoded = decode_v0_8_contents(contents)
    pointer = normalize_pointer(path)

    case pointer do
      p when p in ["", "/"] ->
        {:replace_root, decoded}

      _ ->
        {:merge_at, pointer, decoded}
    end
  end

  def from_v0_8_contents(_path, _contents) do
    {:replace_root, %{}}
  end

  # ============================================
  # v0.9 Wire Format Decoder (Prep)
  # ============================================

  @doc """
  Creates a patch from v0.9 `updateDataModel` wire format.

  ## Parameters

  - `path` - The path from the wire message (can be `nil` or a pointer)
  - `value` - The native JSON value

  ## v0.9 Wire Format

  The v0.9 format uses native JSON values:
  ```json
  {"updateDataModel": {
    "surfaceId": "main",
    "path": "/user",
    "value": {"name": "Alice", "age": 30}
  }}
  ```

  ## Examples

      iex> A2UI.DataPatch.from_v0_9_update(nil, %{"name" => "Alice"})
      {:replace_root, %{"name" => "Alice"}}

      iex> A2UI.DataPatch.from_v0_9_update("/user", %{"name" => "Alice"})
      {:set_at, "/user", %{"name" => "Alice"}}

      iex> A2UI.DataPatch.from_v0_9_update("/user/name", "Alice")
      {:set_at, "/user/name", "Alice"}
  """
  @spec from_v0_9_update(String.t() | nil, json_value()) :: patch()
  def from_v0_9_update(path, value) do
    pointer = normalize_pointer(path)

    case pointer do
      p when p in ["", "/"] ->
        if is_map(value) do
          {:replace_root, value}
        else
          # v0.9 allows any JSON value at root, but our internal model expects a map
          # Wrap non-map values (this is an edge case)
          {:replace_root, %{"_root" => value}}
        end

      _ ->
        {:set_at, pointer, value}
    end
  end

  # ============================================
  # Private: v0.8 Decoding
  # ============================================

  defp decode_v0_8_contents(contents) when is_list(contents) do
    Enum.reduce(contents, %{}, fn entry, acc ->
      case decode_v0_8_entry(entry) do
        {:ok, {key, value}} -> Map.put(acc, key, value)
        {:error, _reason} -> acc
      end
    end)
  end

  # Strict v0.8 decoding per server_to_client.json:
  # - Exactly one of valueString/valueNumber/valueBoolean/valueMap
  # - valueMap entries do NOT support nested valueMap (built via path updates)
  defp decode_v0_8_entry(%{"key" => key} = entry) when is_binary(key) do
    value_keys =
      ["valueString", "valueNumber", "valueBoolean", "valueMap"]
      |> Enum.filter(&Map.has_key?(entry, &1))

    case value_keys do
      ["valueString"] ->
        decode_typed_value(entry, "valueString", key, &is_binary/1)

      ["valueNumber"] ->
        decode_typed_value(entry, "valueNumber", key, &is_number/1)

      ["valueBoolean"] ->
        decode_typed_value(entry, "valueBoolean", key, &is_boolean/1)

      ["valueMap"] ->
        {:ok, {key, decode_v0_8_value_map(entry["valueMap"])}}

      [] ->
        {:error, {:missing_value, key}}

      _ ->
        {:error, {:multiple_values, key}}
    end
  end

  defp decode_v0_8_entry(_), do: {:error, :invalid_entry}

  defp decode_typed_value(entry, type_key, key, validator) do
    value = entry[type_key]

    if validator.(value) do
      {:ok, {key, value}}
    else
      {:error, {:invalid_value, key}}
    end
  end

  # v0.8 valueMap entries only support scalar typed values (no nested valueMap)
  defp decode_v0_8_value_map(entries) when is_list(entries) do
    Enum.reduce(entries, %{}, fn entry, acc ->
      case decode_v0_8_value_map_entry(entry) do
        {:ok, {key, value}} -> Map.put(acc, key, value)
        {:error, _reason} -> acc
      end
    end)
  end

  defp decode_v0_8_value_map(_), do: %{}

  defp decode_v0_8_value_map_entry(%{"key" => key} = entry) when is_binary(key) do
    value_keys =
      ["valueString", "valueNumber", "valueBoolean"]
      |> Enum.filter(&Map.has_key?(entry, &1))

    case value_keys do
      ["valueString"] ->
        decode_typed_value(entry, "valueString", key, &is_binary/1)

      ["valueNumber"] ->
        decode_typed_value(entry, "valueNumber", key, &is_number/1)

      ["valueBoolean"] ->
        decode_typed_value(entry, "valueBoolean", key, &is_boolean/1)

      [] ->
        {:error, {:missing_value, key}}

      _ ->
        {:error, {:multiple_values, key}}
    end
  end

  defp decode_v0_8_value_map_entry(_), do: {:error, :invalid_entry}

  # ============================================
  # Private: Utilities
  # ============================================

  defp normalize_pointer(nil), do: ""
  defp normalize_pointer(""), do: ""
  defp normalize_pointer("/"), do: "/"
  defp normalize_pointer("/" <> _ = path), do: path
  defp normalize_pointer(path), do: "/" <> path
end
