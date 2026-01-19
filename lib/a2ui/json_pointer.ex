defmodule A2UI.JsonPointer do
  @moduledoc """
  JSON Pointer (RFC 6901) operations for A2UI data models.

  This module provides upsert and delete operations that handle JSON Pointer paths
  with native JSON semantics (creating lists for numeric segments).

  ## Container Creation Rules

  When a path segment doesn't exist and we need to create a container:

  - If the current container is a map, the segment is used as a string key
  - If the current container is a list, numeric segments are used as indices
  - When creating a new container:
    - Create a list if the next segment is numeric, otherwise a map

  ## Examples

      # Creates array-based collection for numeric segments
      iex> A2UI.JsonPointer.upsert(%{}, "/items/0/name", "Widget")
      %{"items" => [%{"name" => "Widget"}]}

      # Existing containers are preserved
      iex> A2UI.JsonPointer.upsert(%{"items" => [%{"name" => "Old"}]}, "/items/0/name", "New")
      %{"items" => [%{"name" => "New"}]}
  """

  @doc """
  Upserts a value at a JSON Pointer path.

  Creates intermediate containers as needed (lists for numeric segments, maps otherwise).

  ## Examples

      iex> A2UI.JsonPointer.upsert(%{}, "/user/name", "Alice")
      %{"user" => %{"name" => "Alice"}}

      iex> A2UI.JsonPointer.upsert(%{}, "/items/0", "first")
      %{"items" => ["first"]}
  """
  @spec upsert(map() | list() | nil, String.t() | nil, term()) :: map() | list()
  def upsert(root, pointer, value) do
    segments = decode_pointer(pointer)
    do_upsert(root || default_root(), segments, value)
  end

  @doc """
  Deletes a value at a JSON Pointer path.

  ## Examples

      iex> A2UI.JsonPointer.delete(%{"user" => %{"name" => "Alice", "age" => 30}}, "/user/name")
      %{"user" => %{"age" => 30}}

      iex> A2UI.JsonPointer.delete(%{"items" => ["a", "b", "c"]}, "/items/1")
      %{"items" => ["a", "c"]}
  """
  @spec delete(map() | list() | nil, String.t() | nil) :: map() | list()
  def delete(root, pointer) do
    segments = decode_pointer(pointer)
    do_delete(root || default_root(), segments)
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
  defp do_upsert(_current, [], value), do: value

  # Map container - single segment (leaf)
  defp do_upsert(current, [seg], value) when is_map(current) do
    Map.put(current, seg, value)
  end

  # Map container - multiple segments (recurse)
  defp do_upsert(current, [seg | rest], value) when is_map(current) do
    existing = Map.get(current, seg)

    child =
      case existing do
        %{} -> existing
        list when is_list(list) -> list
        _ -> new_container_for_next(rest)
      end

    Map.put(current, seg, do_upsert(child, rest, value))
  end

  # List container - single segment (leaf)
  defp do_upsert(current, [seg], value) when is_list(current) do
    case numeric_index(seg) do
      {:ok, idx} -> list_put(current, idx, value)
      :error -> current
    end
  end

  # List container - multiple segments (recurse)
  defp do_upsert(current, [seg | rest], value) when is_list(current) do
    case numeric_index(seg) do
      {:ok, idx} ->
        existing = Enum.at(current, idx)

        child =
          case existing do
            %{} -> existing
            list when is_list(list) -> list
            _ -> new_container_for_next(rest)
          end

        list_put(current, idx, do_upsert(child, rest, value))

      :error ->
        current
    end
  end

  # Non-container (scalar) - can't traverse further
  defp do_upsert(current, _segments, _value), do: current

  # Determine what container to create based on next segment
  defp new_container_for_next([]), do: %{}

  defp new_container_for_next([next | _]) do
    case numeric_index(next) do
      {:ok, _} -> []
      :error -> %{}
    end
  end

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
  defp do_delete(_current, []), do: %{}

  # Map container - single segment (leaf)
  defp do_delete(current, [seg]) when is_map(current) do
    Map.delete(current, seg)
  end

  # Map container - multiple segments (recurse)
  defp do_delete(current, [seg | rest]) when is_map(current) do
    case Map.fetch(current, seg) do
      {:ok, child} ->
        Map.put(current, seg, do_delete(child, rest))

      :error ->
        current
    end
  end

  # List container - single segment (leaf)
  defp do_delete(current, [seg]) when is_list(current) do
    case numeric_index(seg) do
      {:ok, idx} -> List.delete_at(current, idx)
      :error -> current
    end
  end

  # List container - multiple segments (recurse)
  defp do_delete(current, [seg | rest]) when is_list(current) do
    case numeric_index(seg) do
      {:ok, idx} ->
        case Enum.at(current, idx) do
          nil -> current
          child -> List.replace_at(current, idx, do_delete(child, rest))
        end

      :error ->
        current
    end
  end

  # Non-container - can't traverse further
  defp do_delete(current, _segments), do: current
end
