defmodule A2UI.JsonPointer do
  @moduledoc """
  Version-aware JSON Pointer (RFC 6901) operations for A2UI data models.

  This module provides upsert and delete operations that correctly handle
  the differences between v0.8 and v0.9 data model semantics:

  - **v0.8**: Collections are map-shaped (the wire format uses `valueMap`, not arrays).
    Missing containers are always created as maps.
  - **v0.9**: Native JSON with real arrays. Missing containers are created as lists
    when the next segment is numeric, otherwise as maps.

  ## Container Creation Rules

  When a path segment doesn't exist and we need to create a container:

  - If the current container is a map, the segment is used as a string key
  - If the current container is a list, numeric segments are used as indices
  - When creating a new container:
    - v0.9: Create a list if the next segment is numeric, otherwise a map
    - v0.8: Always create a map (matches the wire format)

  ## Examples

      # v0.8: creates map-based collection
      iex> A2UI.JsonPointer.upsert(%{}, "/items/0/name", "Widget", version: :v0_8)
      %{"items" => %{"0" => %{"name" => "Widget"}}}

      # v0.9: creates array-based collection
      iex> A2UI.JsonPointer.upsert(%{}, "/items/0/name", "Widget", version: :v0_9)
      %{"items" => [%{"name" => "Widget"}]}

      # Existing containers are preserved
      iex> A2UI.JsonPointer.upsert(%{"items" => [%{"name" => "Old"}]}, "/items/0/name", "New", version: :v0_9)
      %{"items" => [%{"name" => "New"}]}
  """

  @type version :: :v0_8 | :v0_9

  @doc """
  Upserts a value at a JSON Pointer path with version-aware container creation.

  ## Options

  - `:version` - Protocol version (`:v0_8` or `:v0_9`). Defaults to `:v0_9`.

  ## Examples

      iex> A2UI.JsonPointer.upsert(%{}, "/user/name", "Alice")
      %{"user" => %{"name" => "Alice"}}

      iex> A2UI.JsonPointer.upsert(%{}, "/items/0", "first", version: :v0_9)
      %{"items" => ["first"]}

      iex> A2UI.JsonPointer.upsert(%{}, "/items/0", "first", version: :v0_8)
      %{"items" => %{"0" => "first"}}
  """
  @spec upsert(map() | list() | nil, String.t() | nil, term(), keyword()) :: map() | list()
  def upsert(root, pointer, value, opts \\ []) do
    version = Keyword.get(opts, :version, :v0_9)
    segments = decode_pointer(pointer)

    do_upsert(root || default_root(), segments, value, version)
  end

  @doc """
  Deletes a value at a JSON Pointer path.

  ## Options

  - `:version` - Protocol version (`:v0_8` or `:v0_9`). Defaults to `:v0_9`.

  ## Examples

      iex> A2UI.JsonPointer.delete(%{"user" => %{"name" => "Alice", "age" => 30}}, "/user/name")
      %{"user" => %{"age" => 30}}

      iex> A2UI.JsonPointer.delete(%{"items" => ["a", "b", "c"]}, "/items/1", version: :v0_9)
      %{"items" => ["a", "c"]}
  """
  @spec delete(map() | list() | nil, String.t() | nil, keyword()) :: map() | list()
  def delete(root, pointer, opts \\ []) do
    version = Keyword.get(opts, :version, :v0_9)
    segments = decode_pointer(pointer)

    do_delete(root || default_root(), segments, version)
  end

  # ============================================
  # Pointer Decoding
  # ============================================

  defp default_root, do: %{}

  defp decode_pointer(nil), do: []
  defp decode_pointer(""), do: []
  defp decode_pointer("/"), do: []

  defp decode_pointer("/" <> rest) do
    rest
    |> String.split("/")
    |> Enum.map(&unescape/1)
  end

  # RFC 6901 unescaping: ~1 → /, ~0 → ~
  defp unescape(seg) do
    seg
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
  end

  defp numeric_index(seg) do
    case Integer.parse(seg) do
      {i, ""} when i >= 0 -> {:ok, i}
      _ -> :error
    end
  end

  # ============================================
  # UPSERT Implementation
  # ============================================

  # Base case: empty path means replace the value
  defp do_upsert(_current, [], value, _version), do: value

  # Map container - single segment (leaf)
  defp do_upsert(current, [seg], value, _version) when is_map(current) do
    Map.put(current, seg, value)
  end

  # Map container - multiple segments (recurse)
  defp do_upsert(current, [seg | rest], value, version) when is_map(current) do
    existing = Map.get(current, seg)

    child =
      case existing do
        %{} -> existing
        list when is_list(list) -> list
        _ -> new_container_for_next(rest, version)
      end

    Map.put(current, seg, do_upsert(child, rest, value, version))
  end

  # List container - single segment (leaf)
  defp do_upsert(current, [seg], value, _version) when is_list(current) do
    case numeric_index(seg) do
      {:ok, idx} -> list_put(current, idx, value)
      :error -> current
    end
  end

  # List container - multiple segments (recurse)
  defp do_upsert(current, [seg | rest], value, version) when is_list(current) do
    case numeric_index(seg) do
      {:ok, idx} ->
        existing = Enum.at(current, idx)

        child =
          case existing do
            %{} -> existing
            list when is_list(list) -> list
            _ -> new_container_for_next(rest, version)
          end

        list_put(current, idx, do_upsert(child, rest, value, version))

      :error ->
        current
    end
  end

  # Non-container (scalar) - can't traverse further
  defp do_upsert(current, _segments, _value, _version), do: current

  # Determine what container to create based on next segment and version
  defp new_container_for_next([], _version), do: %{}

  defp new_container_for_next([next | _], :v0_9) do
    case numeric_index(next) do
      {:ok, _} -> []
      :error -> %{}
    end
  end

  # v0.8: Always create maps (matches valueMap-based wire format)
  defp new_container_for_next(_rest, :v0_8), do: %{}

  # Put value at index in list, extending with nils if needed
  defp list_put(list, idx, value) do
    len = length(list)

    cond do
      idx < len ->
        List.replace_at(list, idx, value)

      true ->
        padding = List.duplicate(nil, idx - len)
        list ++ padding ++ [value]
    end
  end

  # ============================================
  # DELETE Implementation
  # ============================================

  # Delete at root means clear everything
  defp do_delete(_current, [], _version), do: %{}

  # Map container - single segment (leaf)
  defp do_delete(current, [seg], _version) when is_map(current) do
    Map.delete(current, seg)
  end

  # Map container - multiple segments (recurse)
  defp do_delete(current, [seg | rest], version) when is_map(current) do
    case Map.fetch(current, seg) do
      {:ok, child} ->
        Map.put(current, seg, do_delete(child, rest, version))

      :error ->
        current
    end
  end

  # List container - single segment (leaf)
  defp do_delete(current, [seg], _version) when is_list(current) do
    case numeric_index(seg) do
      {:ok, idx} -> List.delete_at(current, idx)
      :error -> current
    end
  end

  # List container - multiple segments (recurse)
  defp do_delete(current, [seg | rest], version) when is_list(current) do
    case numeric_index(seg) do
      {:ok, idx} ->
        case Enum.at(current, idx) do
          nil -> current
          child -> List.replace_at(current, idx, do_delete(child, rest, version))
        end

      :error ->
        current
    end
  end

  # Non-container - can't traverse further
  defp do_delete(current, _segments, _version), do: current
end
