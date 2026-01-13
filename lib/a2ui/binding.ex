defmodule A2UI.Binding do
  @moduledoc """
  Resolves A2UI BoundValue objects against a data model.

  From Data Binding Concepts:
  - Literal values: fixed content
  - Path-bound values: reactive, update when data changes
  - Scoped paths: relative resolution in template contexts

  JSON Pointer paths per RFC 6901, with proper unescaping.
  """

  @type bound_value :: map() | String.t() | number() | boolean() | nil
  @type data_model :: map()
  @type scope_path :: String.t() | nil

  @doc """
  Resolves a BoundValue to its actual value.

  The `scope_path` parameter is the base JSON Pointer path for template contexts
  (for example: `"/products/0"`). This avoids embedding large scope objects in the DOM.
  Instead we pass a short pointer string and resolve on the server at render/event time.

  ## BoundValue Resolution Rules (from Renderer Guide)

  1. **Literal Only**: Return the literal value directly
  2. **Path Only**: Resolve path against data_model
  3. **Path + Literal**: Path with fallback to literal if path is nil

  ## Examples

      iex> A2UI.Binding.resolve(%{"literalString" => "Hello"}, %{}, nil)
      "Hello"

      iex> A2UI.Binding.resolve(%{"path" => "/user/name"}, %{"user" => %{"name" => "Alice"}}, nil)
      "Alice"

      iex> A2UI.Binding.resolve(%{"path" => "/missing", "literalString" => "default"}, %{}, nil)
      "default"
  """
  @spec resolve(bound_value(), data_model(), scope_path()) :: term()
  def resolve(bound_value, data_model, scope_path \\ nil)

  # Path with optional literal fallback - try path first, fall back to literal if path returns nil
  def resolve(%{"path" => path} = bound, data_model, scope_path) when is_binary(path) do
    case resolve_path(path, data_model, scope_path) do
      nil -> get_literal_fallback(bound)
      value -> value
    end
  end

  # Literal-only values (v0.8 format) - no path key present
  def resolve(%{"literalString" => value}, _data, _scope), do: value
  def resolve(%{"literalNumber" => value}, _data, _scope), do: value
  def resolve(%{"literalBoolean" => value}, _data, _scope), do: value
  def resolve(%{"literalArray" => value}, _data, _scope), do: value

  # v0.9 simplified format: direct values
  def resolve(value, _data, _scope) when is_binary(value), do: value
  def resolve(value, _data, _scope) when is_number(value), do: value
  def resolve(value, _data, _scope) when is_boolean(value), do: value
  def resolve(nil, _data, _scope), do: nil

  # Map without path - could be nested structure, return as-is
  def resolve(%{} = value, _data, _scope), do: value

  @doc """
  Resolves a JSON Pointer path against data model.

  Scope handling per spec:
  - v0.8: Scoped paths inside templates are written like `/name` but resolve against the item
    (we implement this by prefixing `scope_path`).
  - v0.9: Relative paths like `firstName` resolve as `{scope_path}/firstName`.

  ## Examples

      iex> A2UI.Binding.resolve_path("/user/name", %{"user" => %{"name" => "Alice"}}, nil)
      "Alice"

      iex> A2UI.Binding.resolve_path("/name", %{"items" => [%{"name" => "first"}]}, "/items/0")
      "first"
  """
  @spec resolve_path(String.t(), data_model(), scope_path()) :: term()
  def resolve_path(path, data_model, scope_path) do
    get_at_pointer(data_model, expand_path(path, scope_path))
  end

  @doc """
  Expands a potentially relative path to absolute.

  ## Examples

      iex> A2UI.Binding.expand_path("/user/name", nil)
      "/user/name"

      iex> A2UI.Binding.expand_path("/name", "/items/0")
      "/items/0/name"

      iex> A2UI.Binding.expand_path("name", "/items/0")
      "/items/0/name"
  """
  @spec expand_path(String.t() | nil, scope_path()) :: String.t()
  def expand_path(path, nil), do: normalize_pointer(path)

  def expand_path(path, scope_path) when is_binary(scope_path) do
    path = to_string(path || "")

    cond do
      path == "" ->
        scope_path

      String.starts_with?(path, "./") ->
        join_pointer(scope_path, "/" <> String.trim_leading(path, "./"))

      # v0.8 template scoping: `/name` is scoped to the template item.
      String.starts_with?(path, "/") ->
        join_pointer(scope_path, path)

      # v0.9 scoped relative segments: `firstName`
      true ->
        join_pointer(scope_path, "/" <> path)
    end
  end

  defp normalize_pointer(nil), do: ""
  defp normalize_pointer(""), do: ""
  defp normalize_pointer("/" <> _ = path), do: path
  defp normalize_pointer(path), do: "/" <> path

  defp join_pointer(scope_path, "/"), do: scope_path
  defp join_pointer(scope_path, "/" <> rest), do: scope_path <> "/" <> rest

  @doc """
  Extracts the binding path from a BoundValue (for two-way binding).

  ## Examples

      iex> A2UI.Binding.get_path(%{"path" => "/form/name"})
      "/form/name"

      iex> A2UI.Binding.get_path(%{"literalString" => "static"})
      nil
  """
  @spec get_path(bound_value()) :: String.t() | nil
  def get_path(%{"path" => path}), do: path
  def get_path(_), do: nil

  @doc """
  Get value at JSON Pointer path (RFC 6901).

  Handles:
  - `/foo/bar` - object traversal
  - `/items/0` - array indexing
  - `~0` unescaping to `~`
  - `~1` unescaping to `/`

  ## Examples

      iex> A2UI.Binding.get_at_pointer(%{"user" => %{"name" => "Alice"}}, "/user/name")
      "Alice"

      iex> A2UI.Binding.get_at_pointer(%{"items" => ["a", "b", "c"]}, "/items/1")
      "b"

      iex> A2UI.Binding.get_at_pointer(%{"a/b" => %{"c~d" => "value"}}, "/a~1b/c~0d")
      "value"
  """
  @spec get_at_pointer(data_model(), String.t()) :: term()
  def get_at_pointer(data, "/" <> path) do
    segments =
      path
      |> String.split("/", trim: true)
      |> Enum.map(&unescape_pointer_segment/1)

    traverse(data, segments)
  end

  def get_at_pointer(data, ""), do: data
  def get_at_pointer(_data, _), do: nil

  @doc """
  Set value at JSON Pointer path (for two-way binding).
  Returns updated data model.

  ## Examples

      iex> A2UI.Binding.set_at_pointer(%{"user" => %{"name" => "Alice"}}, "/user/name", "Bob")
      %{"user" => %{"name" => "Bob"}}

      iex> A2UI.Binding.set_at_pointer(%{"items" => ["a", "b"]}, "/items/1", "x")
      %{"items" => ["a", "x"]}
  """
  @spec set_at_pointer(data_model(), String.t(), term()) :: data_model()
  def set_at_pointer(data, "/" <> path, value) do
    segments =
      path
      |> String.split("/", trim: true)
      |> Enum.map(&unescape_pointer_segment/1)

    if segments == [] do
      value
    else
      put_at_path(data, segments, value)
    end
  end

  def set_at_pointer(_data, "", value), do: value
  def set_at_pointer(data, _, _value), do: data

  @doc """
  Escapes a single JSON Pointer segment (RFC 6901).

  Use this when constructing pointer strings from user/data-model keys.
  """
  @spec escape_pointer_segment(String.t()) :: String.t()
  def escape_pointer_segment(segment) when is_binary(segment) do
    segment
    |> String.replace("~", "~0")
    |> String.replace("/", "~1")
  end

  @doc """
  Appends a segment to a JSON Pointer, escaping the segment as needed.

  ## Examples

      iex> A2UI.Binding.append_pointer_segment("/products", "0")
      "/products/0"

      iex> A2UI.Binding.append_pointer_segment("", "a/b")
      "/a~1b"
  """
  @spec append_pointer_segment(String.t(), String.t()) :: String.t()
  def append_pointer_segment(pointer, segment) when is_binary(pointer) and is_binary(segment) do
    segment = escape_pointer_segment(segment)
    pointer = normalize_pointer(pointer)

    cond do
      pointer in ["", "/"] -> "/" <> segment
      true -> pointer <> "/" <> segment
    end
  end

  # RFC 6901 JSON Pointer unescaping
  # Order matters: ~1 before ~0 to avoid double-unescaping
  defp unescape_pointer_segment(segment) do
    segment
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
  end

  # Traversal implementation
  defp traverse(data, []), do: data
  defp traverse(nil, _), do: nil

  defp traverse(data, [key | rest]) when is_map(data) do
    value = Map.get(data, key)
    traverse(value, rest)
  end

  defp traverse(data, [key | rest]) when is_list(data) do
    case Integer.parse(key) do
      {index, ""} when index >= 0 -> traverse(Enum.at(data, index), rest)
      _ -> nil
    end
  end

  defp traverse(_, _), do: nil

  # Path setting implementation
  defp put_at_path(data, [key], value) do
    cond do
      is_list(data) ->
        case Integer.parse(key) do
          {index, ""} when index >= 0 -> List.replace_at(data, index, value)
          _ -> data
        end

      true ->
        Map.put(data || %{}, key, value)
    end
  end

  defp put_at_path(data, [key | rest], value) do
    cond do
      is_list(data) ->
        case Integer.parse(key) do
          {index, ""} when index >= 0 ->
            current = Enum.at(data, index) || %{}
            List.replace_at(data, index, put_at_path(current, rest, value))

          _ ->
            data
        end

      true ->
        current = Map.get(data || %{}, key, %{})
        Map.put(data || %{}, key, put_at_path(current, rest, value))
    end
  end

  defp get_literal_fallback(%{"literalString" => v}), do: v
  defp get_literal_fallback(%{"literalNumber" => v}), do: v
  defp get_literal_fallback(%{"literalBoolean" => v}), do: v
  defp get_literal_fallback(%{"literalArray" => v}), do: v
  defp get_literal_fallback(_), do: nil
end
