defmodule A2UI.Messages.DeleteSurface do
  @moduledoc """
  deleteSurface - removes a surface (idempotent)
  """

  defstruct [:surface_id]

  @type t :: %__MODULE__{surface_id: String.t()}

  @doc """
  Parse v0.8/v0.9 deleteSurface message format.

  ## Example

      iex> A2UI.Messages.DeleteSurface.from_map(%{"surfaceId" => "main"})
      %A2UI.Messages.DeleteSurface{surface_id: "main"}
  """
  @spec from_map(map()) :: t()
  def from_map(%{"surfaceId" => sid}) do
    %__MODULE__{surface_id: sid}
  end
end
