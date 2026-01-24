defmodule A2UI.Protocol do
  @moduledoc """
  Protocol constants and helpers for A2UI versions.

  Provides a single source of truth for envelope keys, catalog IDs, and
  version detection across v0.8 and v0.9.
  """

  @type version :: :v0_8 | :v0_9
  @type server_envelope ::
          :surface_update | :data_model_update | :begin_rendering | :delete_surface

  @standard_catalog_id_v0_8 "https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json"

  @standard_catalog_ids_v0_8 [
    @standard_catalog_id_v0_8,
    "a2ui.org:standard_catalog_0_8_0"
  ]

  @standard_catalog_id_v0_9 "https://a2ui.dev/specification/v0_9/standard_catalog.json"
  @standard_catalog_ids_v0_9 [@standard_catalog_id_v0_9]

  @server_envelopes %{
    v0_8: %{
      surface_update: "surfaceUpdate",
      data_model_update: "dataModelUpdate",
      begin_rendering: "beginRendering",
      delete_surface: "deleteSurface"
    },
    v0_9: %{
      surface_update: "updateComponents",
      data_model_update: "updateDataModel",
      begin_rendering: "createSurface",
      delete_surface: "deleteSurface"
    }
  }

  @client_action_envelopes %{
    v0_8: "userAction",
    v0_9: "action"
  }

  @doc """
  Returns the canonical standard catalog ID for a protocol version.
  """
  @spec standard_catalog_id(version()) :: String.t()
  def standard_catalog_id(:v0_8), do: @standard_catalog_id_v0_8
  def standard_catalog_id(:v0_9), do: @standard_catalog_id_v0_9

  @doc """
  Returns all known standard catalog ID aliases for a protocol version.
  """
  @spec standard_catalog_ids(version()) :: [String.t()]
  def standard_catalog_ids(:v0_8), do: @standard_catalog_ids_v0_8
  def standard_catalog_ids(:v0_9), do: @standard_catalog_ids_v0_9

  @doc """
  Returns all known standard catalog IDs across versions.
  """
  @spec standard_catalog_ids() :: [String.t()]
  def standard_catalog_ids do
    @standard_catalog_ids_v0_8 ++ @standard_catalog_ids_v0_9
  end

  @doc """
  Checks if a catalog ID is a known standard catalog alias for a version.
  """
  @spec standard_catalog_id?(version(), String.t()) :: boolean()
  def standard_catalog_id?(:v0_8, catalog_id), do: catalog_id in @standard_catalog_ids_v0_8
  def standard_catalog_id?(:v0_9, catalog_id), do: catalog_id in @standard_catalog_ids_v0_9

  @doc """
  Checks if a catalog ID is a known standard catalog alias in any version.
  """
  @spec standard_catalog_id?(String.t()) :: boolean()
  def standard_catalog_id?(catalog_id) when is_binary(catalog_id) do
    standard_catalog_id?(:v0_8, catalog_id) or standard_catalog_id?(:v0_9, catalog_id)
  end

  @doc """
  Returns the server envelope key for the given version and envelope type.
  """
  @spec server_envelope_key(version(), server_envelope()) :: String.t()
  def server_envelope_key(version, envelope) do
    @server_envelopes
    |> Map.fetch!(version)
    |> Map.fetch!(envelope)
  end

  @doc """
  Returns all server envelope keys for a protocol version.
  """
  @spec server_envelope_keys(version()) :: [String.t()]
  def server_envelope_keys(version) do
    @server_envelopes
    |> Map.fetch!(version)
    |> Map.values()
  end

  @doc """
  Checks if a decoded map looks like a server message for a version.
  """
  @spec server_message?(version(), map()) :: boolean()
  def server_message?(version, decoded) when is_map(decoded) do
    keys = server_envelope_keys(version)
    Enum.any?(keys, &Map.has_key?(decoded, &1))
  end

  def server_message?(_version, _decoded), do: false

  @doc """
  Detects the server message protocol version from decoded JSON.
  """
  @spec detect_server_version(map()) :: version() | :unknown
  def detect_server_version(decoded) when is_map(decoded) do
    cond do
      server_message?(:v0_8, decoded) -> :v0_8
      server_message?(:v0_9, decoded) -> :v0_9
      true -> :unknown
    end
  end

  def detect_server_version(_), do: :unknown

  @doc """
  Returns the envelope key for action events based on protocol version.
  """
  @spec client_action_envelope_key(version()) :: String.t()
  def client_action_envelope_key(version) do
    Map.get(@client_action_envelopes, version, "userAction")
  end

  @doc """
  Detects the client event protocol version from decoded JSON.
  """
  @spec detect_client_version(map()) :: version() | :unknown
  def detect_client_version(%{unquote(@client_action_envelopes[:v0_9]) => _}), do: :v0_9
  def detect_client_version(%{unquote(@client_action_envelopes[:v0_8]) => _}), do: :v0_8
  def detect_client_version(_), do: :unknown

  @doc """
  Returns the A2A extension URI for the protocol version.
  """
  @spec extension_uri(version()) :: String.t()
  def extension_uri(version), do: A2UI.A2A.Protocol.extension_uri(version)

  @doc """
  Returns all known A2UI extension URIs.
  """
  @spec extension_uris() :: [String.t()]
  def extension_uris, do: A2UI.A2A.Protocol.extension_uris()

  @doc """
  Detects protocol version from an A2A extension URI.
  """
  @spec version_from_extension_uri(String.t()) :: version() | :unknown
  def version_from_extension_uri(uri) when is_binary(uri) do
    cond do
      uri == extension_uri(:v0_8) -> :v0_8
      uri == extension_uri(:v0_9) -> :v0_9
      true -> :unknown
    end
  end
end
