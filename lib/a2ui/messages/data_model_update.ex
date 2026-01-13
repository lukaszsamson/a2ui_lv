defmodule A2UI.Messages.DataModelUpdate do
  @moduledoc """
  dataModelUpdate (v0.8) / updateDataModel (v0.9)

  Updates application state via path-based entries.
  Per Data Binding Concepts: "Components automatically update when bound data changes"

  IMPORTANT: The v0.9 message shape is **not** compatible with v0.8:
  - v0.8: `%{"dataModelUpdate" => %{"surfaceId" => ..., "path" => optional, "contents" => [...]}}`
  - v0.9: `%{"updateDataModel" => %{"surfaceId" => ..., "actorId" => ..., "updates" => [...], "versions" => %{...}}}`

  For the PoC, we only implement v0.8 parsing/apply.
  """

  defstruct [:surface_id, :path, :contents]

  @type t :: %__MODULE__{
          surface_id: String.t(),
          path: String.t() | nil,
          contents: list()
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
      contents: Map.get(data, "contents", [])
    }
  end
end
