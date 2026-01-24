defmodule A2UI.Parser do
  @moduledoc """
  Parses A2UI JSONL messages with automatic version detection.

  Per the Renderer Development Guide, implements:
  - JSONL Stream Parser: Process streaming responses line-by-line
  - Message Dispatcher: Route to appropriate handlers

  ## Version Detection

  This parser automatically detects v0.8 vs v0.9 wire format based on envelope keys:

  - v0.8: `surfaceUpdate`, `dataModelUpdate`, `beginRendering`, `deleteSurface`
  - v0.9: `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`

  Both versions produce the same internal message types for downstream compatibility.

  ## Version-Specific Parsers

  For explicit version handling, use:
  - `A2UI.Parser.V0_8.parse_map/1` - v0.8 wire format only
  - `A2UI.Parser.V0_9.parse_map/1` - v0.9 wire format only
  """

  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}
  alias A2UI.Parser.{V0_8, V0_9}
  alias A2UI.JSON
  alias A2UI.Protocol

  @type message ::
          {:surface_update, SurfaceUpdate.t()}
          | {:data_model_update, DataModelUpdate.t()}
          | {:begin_rendering, BeginRendering.t()}
          | {:delete_surface, DeleteSurface.t()}
          | {:error, term()}

  @doc """
  Parses a single JSONL line into a typed message.

  Automatically detects v0.8 vs v0.9 wire format based on envelope keys.

  ## Examples

      # v0.8 format
      iex> A2UI.Parser.parse_line(~s({"surfaceUpdate":{"surfaceId":"main","components":[]}}))
      {:surface_update, %A2UI.Messages.SurfaceUpdate{surface_id: "main", components: []}}

      # v0.9 format
      iex> A2UI.Parser.parse_line(~s({"updateComponents":{"surfaceId":"main","components":[]}}))
      {:surface_update, %A2UI.Messages.SurfaceUpdate{surface_id: "main", components: []}}

      iex> A2UI.Parser.parse_line("not json")
      {:error, {:json_decode, %Jason.DecodeError{...}}}
  """
  @spec parse_line(String.t()) :: message()
  def parse_line(json_line) do
    case JSON.decode_line(json_line) do
      {:ok, decoded} ->
        try do
          dispatch_message(decoded)
        rescue
          exception ->
            {:error, {:parse_exception, exception}}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Parses a decoded JSON map with automatic version detection.

  ## Examples

      iex> A2UI.Parser.parse_map(%{"surfaceUpdate" => %{"surfaceId" => "main", "components" => []}})
      {:surface_update, %A2UI.Messages.SurfaceUpdate{...}}

      iex> A2UI.Parser.parse_map(%{"updateComponents" => %{"surfaceId" => "main", "components" => []}})
      {:surface_update, %A2UI.Messages.SurfaceUpdate{...}}
  """
  @spec parse_map(map()) :: message()
  def parse_map(decoded) when is_map(decoded), do: dispatch_message(decoded)

  @doc """
  Detects the protocol version of a decoded message.

  Returns `:v0_8`, `:v0_9`, or `:unknown`.
  """
  @spec detect_version(map()) :: :v0_8 | :v0_9 | :unknown
  def detect_version(decoded), do: Protocol.detect_server_version(decoded)

  # Version-detecting dispatch
  defp dispatch_message(decoded) do
    case Protocol.detect_server_version(decoded) do
      :v0_8 -> V0_8.parse_map(decoded)
      :v0_9 -> V0_9.parse_map(decoded)
      :unknown -> {:error, :unknown_message_type}
    end
  end
end
