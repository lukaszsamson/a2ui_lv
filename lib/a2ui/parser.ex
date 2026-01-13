defmodule A2UI.Parser do
  @moduledoc """
  Parses A2UI JSONL messages.

  Per the Renderer Development Guide, implements:
  - JSONL Stream Parser: Process streaming responses line-by-line
  - Message Dispatcher: Route to appropriate handlers
  """

  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}

  @type message ::
          {:surface_update, SurfaceUpdate.t()}
          | {:data_model_update, DataModelUpdate.t()}
          | {:begin_rendering, BeginRendering.t()}
          | {:delete_surface, DeleteSurface.t()}
          | {:error, term()}

  @doc """
  Parses a single JSONL line into a typed message.

  ## Examples

      iex> A2UI.Parser.parse_line(~s({"surfaceUpdate":{"surfaceId":"main","components":[]}}))
      {:surface_update, %A2UI.Messages.SurfaceUpdate{surface_id: "main", components: []}}

      iex> A2UI.Parser.parse_line(~s({"beginRendering":{"surfaceId":"main","root":"root"}}))
      {:begin_rendering, %A2UI.Messages.BeginRendering{surface_id: "main", root_id: "root", ...}}

      iex> A2UI.Parser.parse_line("not json")
      {:error, {:json_decode, %Jason.DecodeError{...}}}
  """
  @spec parse_line(String.t()) :: message()
  def parse_line(json_line) do
    case Jason.decode(json_line) do
      {:ok, decoded} ->
        dispatch_message(decoded)

      {:error, reason} ->
        {:error, {:json_decode, reason}}
    end
  end

  # v0.8 message dispatch
  defp dispatch_message(%{"surfaceUpdate" => data}),
    do: {:surface_update, SurfaceUpdate.from_map(data)}

  defp dispatch_message(%{"dataModelUpdate" => data}),
    do: {:data_model_update, DataModelUpdate.from_map(data)}

  defp dispatch_message(%{"beginRendering" => data}),
    do: {:begin_rendering, BeginRendering.from_map(data)}

  defp dispatch_message(%{"deleteSurface" => data}),
    do: {:delete_surface, DeleteSurface.from_map(data)}

  defp dispatch_message(_),
    do: {:error, :unknown_message_type}
end
