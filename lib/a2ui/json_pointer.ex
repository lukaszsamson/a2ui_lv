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
  @spec upsert(term(), String.t() | nil, term()) :: term()
  def upsert(root, pointer, value) do
    segments = decode_pointer(pointer)
    do_upsert(if(is_nil(root), do: default_root(), else: root), segments, value)
  end

  @doc "Validates an A2UI absolute or relative JSON Pointer without resolving it."
  @spec validate(term(), keyword()) :: :ok | {:error, String.t()}
  def validate(pointer, opts \\ [])

  def validate(pointer, opts) when is_binary(pointer) do
    absolute? = Keyword.get(opts, :absolute, false)

    cond do
      absolute? and pointer not in [""] and not String.starts_with?(pointer, "/") ->
        {:error, "must be an absolute JSON Pointer starting with /"}

      invalid_escape?(pointer) ->
        {:error, "contains an invalid JSON Pointer escape; only ~0 and ~1 are valid"}

      true ->
        :ok
    end
  end

  def validate(nil, opts) do
    if Keyword.get(opts, :absolute, false), do: :ok, else: {:error, "must be a string"}
  end

  def validate(_pointer, _opts), do: {:error, "must be a string"}

  @doc "Validates array-index segments against the containers currently present at a path."
  @spec validate_indices(term(), String.t() | nil) :: :ok | {:error, String.t()}
  def validate_indices(root, pointer) when is_binary(pointer) or is_nil(pointer) do
    segments = decode_pointer(pointer)
    do_validate_indices(root, segments)
  end

  @doc """
  Deletes a value at a JSON Pointer path.

  ## Examples

      iex> A2UI.JsonPointer.delete(%{"user" => %{"name" => "Alice", "age" => 30}}, "/user/name")
      %{"user" => %{"age" => 30}}

      iex> A2UI.JsonPointer.delete(%{"items" => ["a", "b", "c"]}, "/items/1")
      %{"items" => ["a", nil, "c"]}
  """
  @spec delete(term(), String.t() | nil) :: term()
  def delete(root, pointer) do
    segments = decode_pointer(pointer)
    do_delete(if(is_nil(root), do: default_root(), else: root), segments)
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

  defp invalid_escape?(pointer) do
    String.match?(pointer, ~r/~(?:[^01]|$)/)
  end

  defp numeric_index(seg) do
    case Integer.parse(seg) do
      {i, ""} when i >= 0 -> {:ok, i}
      _ -> :error
    end
  end

  defp canonical_array_index?("0"), do: true

  defp canonical_array_index?(<<first, rest::binary>>) when first in ?1..?9,
    do: String.match?(rest, ~r/^\d*$/)

  defp canonical_array_index?(_), do: false

  defp do_validate_indices(_current, []), do: :ok

  defp do_validate_indices(current, [segment | rest]) when is_list(current) do
    if canonical_array_index?(segment) do
      index = String.to_integer(segment)
      do_validate_indices(Enum.at(current, index), rest)
    else
      {:error, "#{inspect(segment)} is not a valid array index"}
    end
  end

  defp do_validate_indices(current, [segment | rest]) when is_map(current) do
    do_validate_indices(Map.get(current, segment), rest)
  end

  defp do_validate_indices(nil, [segment | rest]) do
    case Integer.parse(segment) do
      {_index, ""} ->
        if canonical_array_index?(segment),
          do: do_validate_indices(nil, rest),
          else: {:error, "#{inspect(segment)} is not a canonical array index"}

      _ ->
        do_validate_indices(nil, rest)
    end
  end

  defp do_validate_indices(_scalar, _rest), do: :ok

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

  # Replace a scalar with the container required by the pointer.
  defp do_upsert(_current, segments, value) do
    do_upsert(new_container_for_next(segments), segments, value)
  end

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
      {:ok, idx} when idx < length(current) -> List.replace_at(current, idx, nil)
      {:ok, _idx} -> current
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
