defmodule A2UI.Messages.BeginRendering do
  @moduledoc """
  beginRendering (v0.8) / createSurface (v0.9)

  Signals client to render the surface.
  Per Data Flow Concepts: "Prevents flash of incomplete content"

  v0.9 note: "There must be exactly one component with ID 'root'"
  rather than explicit root specification.

  ## Protocol Version

  The `protocol_version` field tracks which wire format this message was parsed from.
  This is important for downstream processing:
  - Catalog resolution: v0.8 allows nil catalogId, v0.9 requires it
  - Template binding: v0.8 scopes `/path` in templates, v0.9 treats `/path` as absolute
  """

  @type protocol_version :: :v0_8 | :v0_9

  defstruct [:surface_id, :root_id, :catalog_id, :styles, :broadcast_data_model?, :protocol_version]

  @type t :: %__MODULE__{
          surface_id: String.t(),
          root_id: String.t(),
          catalog_id: String.t() | nil,
          styles: map() | nil,
          broadcast_data_model?: boolean(),
          protocol_version: protocol_version()
        }

  @doc """
  Parse v0.8 beginRendering message format.

  ## Example

      iex> data = %{"surfaceId" => "main", "root" => "root"}
      iex> A2UI.Messages.BeginRendering.from_map(data)
      %A2UI.Messages.BeginRendering{surface_id: "main", root_id: "root", catalog_id: nil, styles: nil, broadcast_data_model?: false, protocol_version: :v0_8}
  """
  @spec from_map(map()) :: t()
  def from_map(%{"surfaceId" => sid, "root" => root} = data) do
    %__MODULE__{
      surface_id: sid,
      root_id: root,
      catalog_id: Map.get(data, "catalogId"),
      styles: Map.get(data, "styles"),
      broadcast_data_model?: false,
      protocol_version: :v0_8
    }
  end

  @doc """
  Parse v0.9 createSurface message format.

  In v0.9, there is no explicit `root` field. Instead, one component must have id "root".
  We default root_id to "root" per spec requirement.

  ## Example

      iex> data = %{"surfaceId" => "main", "catalogId" => "test.catalog"}
      iex> A2UI.Messages.BeginRendering.from_map_v09(data)
      %A2UI.Messages.BeginRendering{surface_id: "main", root_id: "root", catalog_id: "test.catalog", broadcast_data_model?: false, protocol_version: :v0_9}
  """
  @spec from_map_v09(map()) :: t()
  def from_map_v09(%{"surfaceId" => sid} = data) do
    %__MODULE__{
      surface_id: sid,
      # v0.9 requires a component with id "root" - no explicit root field
      root_id: "root",
      catalog_id: Map.get(data, "catalogId"),
      styles: nil,
      broadcast_data_model?: Map.get(data, "broadcastDataModel", false),
      protocol_version: :v0_9
    }
  end
end
