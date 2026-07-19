defmodule A2UI.Messages.SurfaceUpdate do
  @moduledoc """
  surfaceUpdate (v0.8) / updateComponents (v0.9)

  Adds or updates components within a surface using adjacency list structure.
  Per Message Types Reference: "sending duplicate IDs updates existing components"
  """

  defstruct [:surface_id, :components, :protocol_version]

  @type t :: %__MODULE__{
          surface_id: String.t(),
          components: [A2UI.Component.t()],
          protocol_version: A2UI.Protocol.version() | nil
        }

  @doc """
  Parse v0.8 surfaceUpdate message format.

  ## Example

      iex> data = %{"surfaceId" => "main", "components" => [
      ...>   %{"id" => "root", "component" => %{"Text" => %{"text" => %{"literalString" => "Hello"}}}}
      ...> ]}
      iex> A2UI.Messages.SurfaceUpdate.from_map(data)
      %A2UI.Messages.SurfaceUpdate{surface_id: "main", components: [%A2UI.Component{...}]}
  """
  @spec from_map(map()) :: t()
  def from_map(%{"surfaceId" => sid, "components" => comps}) do
    %__MODULE__{
      surface_id: sid,
      components: Enum.map(comps, &A2UI.Component.from_map/1),
      protocol_version: :v0_8
    }
  end

  @doc """
  Parse v0.9 updateComponents message format.
  """
  @spec from_map_v09(map()) :: t()
  def from_map_v09(%{"surfaceId" => sid, "components" => comps}, version \\ :v0_9) do
    %__MODULE__{
      surface_id: sid,
      components: Enum.map(comps, &A2UI.Component.from_map_v09/1),
      protocol_version: version
    }
  end
end
