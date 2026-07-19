defmodule A2UI.Messages.DeleteSurface do
  @moduledoc """
  deleteSurface - removes a surface (idempotent)
  """

  defstruct [:surface_id, :protocol_version]

  @type t :: %__MODULE__{surface_id: String.t(), protocol_version: A2UI.Protocol.version() | nil}

  @doc """
  Parse v0.8/v0.9 deleteSurface message format.

  ## Example

      iex> A2UI.Messages.DeleteSurface.from_map(%{"surfaceId" => "main"})
      %A2UI.Messages.DeleteSurface{surface_id: "main"}
  """
  @spec from_map(map()) :: t()
  def from_map(%{"surfaceId" => sid}, version \\ :v0_8) do
    %__MODULE__{surface_id: sid, protocol_version: version}
  end
end
