defmodule A2UI.Messages.DataModelUpdate do
  @moduledoc """
  dataModelUpdate (v0.8) / updateDataModel (v0.9)

  Updates application state via path-based entries.
  Per Data Binding Concepts: "Components automatically update when bound data changes"

  ## Wire Format Differences

  - v0.8: `%{"dataModelUpdate" => %{"surfaceId" => ..., "path" => optional, "contents" => [...]}}`
    - Uses adjacency-list `contents` with typed values (`valueString`, etc.)
  - v0.9: `%{"updateDataModel" => %{"surfaceId" => ..., "path" => optional, "value" => any}}`
    - Uses native JSON `value`

  ## Internal Representation

  This struct uses a discriminated union via the `format` field:
  - `:v0_8` - `contents` field contains adjacency-list data
  - `:v0_9` - `value` field contains native JSON data
  """

  defstruct [:surface_id, :path, :contents, :value, format: :v0_8]

  @type t :: %__MODULE__{
          surface_id: String.t(),
          path: String.t() | nil,
          contents: list() | nil,
          value: term(),
          format: :v0_8 | :v0_9
        }

  @doc """
  Parse v0.8 dataModelUpdate message format.

  Contents is an array of key-value entries with typed values:
  - `%{"key" => "name", "valueString" => "Alice"}`
  - `%{"key" => "count", "valueNumber" => 42}`
  - `%{"key" => "active", "valueBoolean" => true}`
  - `%{"key" => "nested", "valueMap" => [...]}`

  Note: v0.8 server-to-client schema does **not** include `valueArray`.
  """
  @spec from_map(map()) :: t()
  def from_map(%{"surfaceId" => sid} = data) do
    %__MODULE__{
      surface_id: sid,
      path: Map.get(data, "path"),
      contents: Map.get(data, "contents", []),
      value: nil,
      format: :v0_8
    }
  end

  @doc """
  Parse v0.9 updateDataModel message format.

  v0.9 uses native JSON values instead of typed adjacency-list format.
  If `value` is omitted, the key at `path` should be removed (delete semantics).

  ## Examples

      iex> A2UI.Messages.DataModelUpdate.from_map_v09(%{"surfaceId" => "main", "path" => "/user/name", "value" => "Alice"})
      %A2UI.Messages.DataModelUpdate{surface_id: "main", path: "/user/name", value: "Alice", format: :v0_9}

      iex> A2UI.Messages.DataModelUpdate.from_map_v09(%{"surfaceId" => "main", "value" => %{"name" => "Alice"}})
      %A2UI.Messages.DataModelUpdate{surface_id: "main", path: nil, value: %{"name" => "Alice"}, format: :v0_9}
  """
  @spec from_map_v09(map()) :: t()
  def from_map_v09(%{"surfaceId" => sid} = data) do
    # v0.9 treats missing "value" as delete operation (we use :delete sentinel)
    value =
      if Map.has_key?(data, "value") do
        Map.get(data, "value")
      else
        :delete
      end

    %__MODULE__{
      surface_id: sid,
      path: Map.get(data, "path"),
      contents: nil,
      value: value,
      format: :v0_9
    }
  end
end
