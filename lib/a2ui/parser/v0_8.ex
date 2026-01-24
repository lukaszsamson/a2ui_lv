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

  ## Internal Representation

  This parser adapts v0.8 wire format to v0.9-native internal representation at parse time.
  All downstream code works with v0.9 structures exclusively.
  """

  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}
  alias A2UI.Protocol
  alias A2UI.V0_8.Adapter

  @type message ::
          {:surface_update, SurfaceUpdate.t()}
          | {:data_model_update, DataModelUpdate.t()}
          | {:begin_rendering, BeginRendering.t()}
          | {:delete_surface, DeleteSurface.t()}
          | {:error, term()}

  @doc """
  Parses a decoded JSON map as a v0.8 message.

  Returns a tagged tuple with the parsed message struct.
  Adapts v0.8 wire format to v0.9-native internal representation.

  ## Examples

      iex> A2UI.Parser.V0_8.parse_map(%{"surfaceUpdate" => %{"surfaceId" => "main", "components" => []}})
      {:surface_update, %A2UI.Messages.SurfaceUpdate{surface_id: "main", components: []}}

      iex> A2UI.Parser.V0_8.parse_map(%{"unknown" => %{}})
      {:error, :unknown_message_type}
  """
  @spec parse_map(map()) :: message()
  def parse_map(%{"surfaceUpdate" => data}) do
    # Adapt v0.8 format to v0.9, then parse as v0.9
    adapted = Adapter.adapt_surface_update(data)
    {:surface_update, SurfaceUpdate.from_map_v09(adapted)}
  end

  def parse_map(%{"dataModelUpdate" => data}) do
    # Adapt v0.8 format to v0.9, then parse
    adapted = Adapter.adapt_data_model_update(data)
    msg = DataModelUpdate.from_map(adapted)
    {:data_model_update, %{msg | protocol_version: :v0_8}}
  end

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
    Protocol.server_message?(:v0_8, decoded)
  end

  def v0_8_message?(_), do: false
end
