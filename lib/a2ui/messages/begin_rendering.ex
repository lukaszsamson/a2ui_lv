defmodule A2UI.Messages.BeginRendering do
  @moduledoc """
  beginRendering (v0.8) / createSurface (v0.9)

  Signals client to render the surface.
  Per Data Flow Concepts: "Prevents flash of incomplete content"

  v0.9 note: "There must be exactly one component with ID 'root'"
  rather than explicit root specification.
  """

  defstruct [:surface_id, :root_id, :catalog_id, :styles]

  @type t :: %__MODULE__{
          surface_id: String.t(),
          root_id: String.t(),
          catalog_id: String.t() | nil,
          styles: map() | nil
        }

  @doc """
  Parse v0.8 beginRendering message format.

  ## Example

      iex> data = %{"surfaceId" => "main", "root" => "root"}
      iex> A2UI.Messages.BeginRendering.from_map(data)
      %A2UI.Messages.BeginRendering{surface_id: "main", root_id: "root", catalog_id: nil, styles: nil}
  """
  @spec from_map(map()) :: t()
  def from_map(%{"surfaceId" => sid, "root" => root} = data) do
    %__MODULE__{
      surface_id: sid,
      root_id: root,
      catalog_id: Map.get(data, "catalogId"),
      styles: Map.get(data, "styles")
    }
  end
end
