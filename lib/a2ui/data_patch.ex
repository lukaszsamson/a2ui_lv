defmodule A2UI.DataPatch do
  @moduledoc """
  Internal abstraction for data model updates.

  This module provides a version-agnostic representation of data model changes,
  allowing the renderer to work with a single internal format.

  ## Patch Operations

  - `{:replace_root, value}` - Replace the entire data model
  - `{:set_at, pointer, value}` - Set/replace any JSON value at a path
  - `{:delete_at, pointer}` - Delete value at a path

  ## Examples

      # Create patch from wire format
      patch = DataPatch.from_update("/user", %{"name" => "Alice"})
      #=> {:set_at, "/user", %{"name" => "Alice"}}

      # Apply patch to data model
      new_data = DataPatch.apply_patch(%{}, patch)
  """

  alias A2UI.JsonPointer

  @type json_value :: String.t() | number() | boolean() | map() | list() | nil
  @type pointer :: String.t()

  @type patch ::
          {:replace_root, json_value()}
          | {:set_at, pointer(), json_value()}
          | {:delete_at, pointer()}

  # ============================================
  # Patch Application
  # ============================================

  @doc """
  Applies a patch operation to a data model.

  ## Patch Types

  - `{:replace_root, value}` - Replaces the entire data model with `value`
  - `{:set_at, pointer, value}` - Sets/replaces `value` at the JSON Pointer path
  - `{:delete_at, pointer}` - Deletes the value at the JSON Pointer path

  ## Examples

      iex> A2UI.DataPatch.apply_patch(%{}, {:replace_root, %{"name" => "Alice"}})
      %{"name" => "Alice"}

      iex> A2UI.DataPatch.apply_patch(%{"user" => %{"age" => 30}}, {:set_at, "/user/name", "Alice"})
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
    JsonPointer.upsert(data_model, pointer, value)
  end

  def apply_patch(data_model, {:delete_at, pointer}) do
    JsonPointer.delete(data_model, pointer)
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
  # Wire Format Decoder
  # ============================================

  @doc """
  Creates a patch from updateDataModel wire format.

  ## Parameters

  - `path` - The path from the wire message (can be `nil` or a pointer)
  - `value` - The native JSON value (or `:delete` sentinel for delete operations)

  ## Examples

      iex> A2UI.DataPatch.from_update(nil, %{"name" => "Alice"})
      {:replace_root, %{"name" => "Alice"}}

      iex> A2UI.DataPatch.from_update("/user", %{"name" => "Alice"})
      {:set_at, "/user", %{"name" => "Alice"}}

      iex> A2UI.DataPatch.from_update("/user/name", "Alice")
      {:set_at, "/user/name", "Alice"}

      iex> A2UI.DataPatch.from_update("/user/temp", :delete)
      {:delete_at, "/user/temp"}
  """
  @spec from_update(String.t() | nil, json_value() | :delete) :: patch()
  def from_update(path, :delete) do
    pointer = normalize_pointer(path)

    case pointer do
      p when p in ["", "/"] ->
        # Delete at root means clear everything
        {:replace_root, %{}}

      _ ->
        {:delete_at, pointer}
    end
  end

  def from_update(path, value) do
    pointer = normalize_pointer(path)

    case pointer do
      p when p in ["", "/"] ->
        if is_map(value) do
          {:replace_root, value}
        else
          # Allow any JSON value at root, but our internal model expects a map
          # Wrap non-map values (this is an edge case)
          {:replace_root, %{"_root" => value}}
        end

      _ ->
        {:set_at, pointer, value}
    end
  end

  # ============================================
  # Private: Utilities
  # ============================================

  defp normalize_pointer(nil), do: ""
  defp normalize_pointer(""), do: ""
  defp normalize_pointer("/"), do: "/"
  defp normalize_pointer("/" <> _ = path), do: path
  defp normalize_pointer(path), do: "/" <> path
end
