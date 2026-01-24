defmodule A2UI.Messages.DataModelUpdate do
  @moduledoc """
  dataModelUpdate (v0.8) / updateDataModel (v0.9)

  Updates application state via path-based entries.
  Per Data Binding Concepts: "Components automatically update when bound data changes"

  ## Wire Format

  Both v0.8 and v0.9 wire formats are adapted to the same internal representation:
  - `surface_id` - The surface to update
  - `path` - Optional JSON Pointer path (nil means root)
  - `value` - Native JSON value to set at path

  The v0.8 parser adapts its wire format (adjacency-list `contents` with typed values)
  to this v0.9-native representation at parse time.
  """

  defstruct [:surface_id, :path, :value, :protocol_version, :patches]

  @type t :: %__MODULE__{
          surface_id: String.t(),
          path: String.t() | nil,
          value: term(),
          protocol_version: :v0_8 | :v0_9 | nil,
          patches: [A2UI.DataPatch.patch()]
        }

  @doc """
  Parse updateDataModel message format.

  Uses native JSON values. If `value` is omitted, the key at `path` should be
  removed (delete semantics).

  ## Examples

      iex> A2UI.Messages.DataModelUpdate.from_map(%{"surfaceId" => "main", "path" => "/user/name", "value" => "Alice"})
      %A2UI.Messages.DataModelUpdate{surface_id: "main", path: "/user/name", value: "Alice"}

      iex> A2UI.Messages.DataModelUpdate.from_map(%{"surfaceId" => "main", "value" => %{"name" => "Alice"}})
      %A2UI.Messages.DataModelUpdate{surface_id: "main", path: nil, value: %{"name" => "Alice"}}

      iex> A2UI.Messages.DataModelUpdate.from_map(%{"surfaceId" => "main", "path" => "/temp"})
      %A2UI.Messages.DataModelUpdate{surface_id: "main", path: "/temp", value: :delete}
  """
  @spec from_map(map()) :: t()
  def from_map(%{"surfaceId" => sid} = data) do
    # Missing "value" key means delete operation (we use :delete sentinel)
    value =
      if Map.has_key?(data, "value") do
        Map.get(data, "value")
      else
        :delete
      end

    patches =
      case Map.get(data, "patches") do
        patches when is_list(patches) ->
          patches

        _ ->
          [A2UI.DataPatch.from_update(Map.get(data, "path"), value)]
      end

    %__MODULE__{
      surface_id: sid,
      path: Map.get(data, "path"),
      value: value,
      protocol_version: :v0_9,
      patches: patches
    }
  end
end
