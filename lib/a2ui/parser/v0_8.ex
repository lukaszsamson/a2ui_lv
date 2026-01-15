defmodule A2UI.Parser.V0_8 do
  @moduledoc """
  v0.8 wire format parser.

  Handles the v0.8 message envelope structure:
  - `{"surfaceUpdate": {...}}` - Component updates
  - `{"dataModelUpdate": {...}}` - Data model changes (adjacency-list format)
  - `{"beginRendering": {...}}` - Surface ready signal
  - `{"deleteSurface": {...}}` - Surface deletion

  ## Wire Format Characteristics

  - Single-key envelope pattern (one top-level key per message)
  - Typed value encoding in data model: `valueString`, `valueNumber`, `valueBoolean`, `valueMap`
  - Component wrapper objects: `{"Text": {...}}` instead of `"component": "Text"`
  """

  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}

  @type message ::
          {:surface_update, SurfaceUpdate.t()}
          | {:data_model_update, DataModelUpdate.t()}
          | {:begin_rendering, BeginRendering.t()}
          | {:delete_surface, DeleteSurface.t()}
          | {:error, term()}

  @doc """
  Parses a decoded JSON map as a v0.8 message.

  Returns a tagged tuple with the parsed message struct.

  ## Examples

      iex> A2UI.Parser.V0_8.parse_map(%{"surfaceUpdate" => %{"surfaceId" => "main", "components" => []}})
      {:surface_update, %A2UI.Messages.SurfaceUpdate{surface_id: "main", components: []}}

      iex> A2UI.Parser.V0_8.parse_map(%{"unknown" => %{}})
      {:error, :unknown_message_type}
  """
  @spec parse_map(map()) :: message()
  def parse_map(%{"surfaceUpdate" => data}),
    do: {:surface_update, SurfaceUpdate.from_map(data)}

  def parse_map(%{"dataModelUpdate" => data}),
    do: {:data_model_update, DataModelUpdate.from_map(data)}

  def parse_map(%{"beginRendering" => data}),
    do: {:begin_rendering, BeginRendering.from_map(data)}

  def parse_map(%{"deleteSurface" => data}),
    do: {:delete_surface, DeleteSurface.from_map(data)}

  def parse_map(_),
    do: {:error, :unknown_message_type}

  @doc """
  Checks if a decoded JSON map looks like a v0.8 message.

  Returns `true` if the map has any v0.8-specific envelope keys.
  """
  @spec v0_8_message?(map()) :: boolean()
  def v0_8_message?(decoded) when is_map(decoded) do
    v0_8_keys = ["surfaceUpdate", "dataModelUpdate", "beginRendering", "deleteSurface"]
    Enum.any?(v0_8_keys, &Map.has_key?(decoded, &1))
  end

  def v0_8_message?(_), do: false
end
