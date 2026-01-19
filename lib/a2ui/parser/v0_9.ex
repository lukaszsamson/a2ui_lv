defmodule A2UI.Parser.V0_9 do
  @moduledoc """
  v0.9 wire format parser.

  Handles the v0.9 message envelope structure:
  - `{"createSurface": {...}}` - Surface creation (replaces `beginRendering`)
  - `{"updateComponents": {...}}` - Component updates (replaces `surfaceUpdate`)
  - `{"updateDataModel": {...}}` - Data model changes (native JSON, replaces `dataModelUpdate`)
  - `{"deleteSurface": {...}}` - Surface deletion (same as v0.8)

  ## Wire Format Characteristics

  - Single-key envelope pattern (one top-level key per message)
  - Native JSON values in data model (no typed `valueString`/`valueNumber` wrappers)
  - Component discriminator field: `"component": "Text"` instead of wrapper objects
  - No explicit `root` field - one component must have id "root"
  """

  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}

  @type message ::
          {:surface_update, SurfaceUpdate.t()}
          | {:data_model_update, DataModelUpdate.t()}
          | {:begin_rendering, BeginRendering.t()}
          | {:delete_surface, DeleteSurface.t()}
          | {:error, term()}

  @doc """
  Parses a decoded JSON map as a v0.9 message.

  Returns a tagged tuple with the parsed message struct.
  Uses the same internal message types as v0.8 for compatibility.

  ## Examples

      iex> A2UI.Parser.V0_9.parse_map(%{"createSurface" => %{"surfaceId" => "main", "catalogId" => "test"}})
      {:begin_rendering, %A2UI.Messages.BeginRendering{surface_id: "main", root_id: "root", catalog_id: "test"}}

      iex> A2UI.Parser.V0_9.parse_map(%{"updateComponents" => %{"surfaceId" => "main", "components" => []}})
      {:surface_update, %A2UI.Messages.SurfaceUpdate{surface_id: "main", components: []}}

      iex> A2UI.Parser.V0_9.parse_map(%{"unknown" => %{}})
      {:error, :unknown_message_type}
  """
  @spec parse_map(map()) :: message()
  def parse_map(%{"createSurface" => data}),
    do: {:begin_rendering, BeginRendering.from_map_v09(data)}

  def parse_map(%{"updateComponents" => data}),
    do: {:surface_update, SurfaceUpdate.from_map_v09(data)}

  def parse_map(%{"updateDataModel" => data}) do
    msg = DataModelUpdate.from_map(data)
    {:data_model_update, %{msg | protocol_version: :v0_9}}
  end

  def parse_map(%{"deleteSurface" => data}),
    do: {:delete_surface, DeleteSurface.from_map(data)}

  def parse_map(_),
    do: {:error, :unknown_message_type}

  @doc """
  Checks if a decoded JSON map looks like a v0.9 message.

  Returns `true` if the map has any v0.9-specific envelope keys.
  """
  @spec v0_9_message?(map()) :: boolean()
  def v0_9_message?(decoded) when is_map(decoded) do
    v0_9_keys = ["createSurface", "updateComponents", "updateDataModel", "deleteSurface"]
    Enum.any?(v0_9_keys, &Map.has_key?(decoded, &1))
  end

  def v0_9_message?(_), do: false
end
