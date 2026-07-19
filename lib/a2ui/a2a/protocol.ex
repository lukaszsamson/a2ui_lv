defmodule A2UI.A2A.Protocol do
  @moduledoc """
  A2A protocol constants and extension URIs for A2UI.

  This module defines protocol-level constants required for A2UI messages
  transported over A2A (Agent-to-Agent) protocol. These constants are used
  by A2A transport implementations to correctly package and identify A2UI messages.

  ## Extension Activation

  A2UI uses A2A extension URIs that must be activated for A2UI message exchange:

  - v0.8: `https://a2ui.org/a2a-extension/a2ui/v0.8`
  - v0.9: `https://a2ui.org/a2a-extension/a2ui/v0.9`

  Clients activate extensions via:
  - HTTP/JSON-RPC: `X-A2A-Extensions` header
  - gRPC: `X-A2A-Extensions` metadata value

  ## Message Packaging

  All A2UI messages transported over A2A are encoded as A2A `DataPart` with:
  - `data`: the raw A2UI message envelope
  - `metadata.mimeType`: `application/json+a2ui`

  See `A2UI.A2A.DataPart` for message packaging functions.
  """

  # ============================================
  # MIME Types
  # ============================================

  @legacy_mime_type "application/json+a2ui"
  @mime_type "application/a2ui+json"

  @doc """
  Returns the MIME type for A2UI messages in A2A DataParts.

  All A2UI message envelopes transported over A2A use this MIME type
  in the DataPart's `metadata.mimeType` field.
  """
  @spec mime_type() :: String.t()
  def mime_type, do: @legacy_mime_type

  @spec mime_type(A2UI.Protocol.version()) :: String.t()
  def mime_type(:v0_8), do: @legacy_mime_type
  def mime_type(version) when version in [:v0_9, :v0_9_1], do: @mime_type

  def mime_type?(mime), do: mime in [@legacy_mime_type, @mime_type]

  # ============================================
  # Extension URIs
  # ============================================

  @extension_uri_v0_8 "https://a2ui.org/a2a-extension/a2ui/v0.8"
  @extension_uri_v0_9 "https://a2ui.org/a2a-extension/a2ui/v0.9"
  @extension_uri_v0_9_1 "https://a2ui.org/a2a-extension/a2ui/v0.9.1"

  @doc """
  Returns the A2A extension URI for A2UI v0.8.

  This URI must be included in A2A extension activation (via header or metadata)
  when exchanging v0.8 A2UI messages.
  """
  @spec extension_uri(:v0_8) :: String.t()
  @spec extension_uri(:v0_9) :: String.t()
  @spec extension_uri(:v0_9_1) :: String.t()
  def extension_uri(:v0_8), do: @extension_uri_v0_8
  def extension_uri(:v0_9), do: @extension_uri_v0_9
  def extension_uri(:v0_9_1), do: @extension_uri_v0_9_1

  @doc """
  Returns the default (v0.8) A2A extension URI.
  """
  @spec extension_uri() :: String.t()
  def extension_uri, do: @extension_uri_v0_8

  @doc """
  Returns all known A2UI extension URIs.
  """
  @spec extension_uris() :: [String.t()]
  def extension_uris, do: [@extension_uri_v0_8, @extension_uri_v0_9, @extension_uri_v0_9_1]

  # ============================================
  # Metadata Keys
  # ============================================

  @client_capabilities_key "a2uiClientCapabilities"
  @client_data_model_key "a2uiClientDataModel"
  @supported_catalog_ids_key "supportedCatalogIds"
  @inline_catalogs_key "inlineCatalogs"

  @doc """
  Returns the metadata key for A2UI client capabilities.

  Client capabilities are attached to every client→server A2A message
  under `message.metadata.a2uiClientCapabilities`.
  """
  @spec client_capabilities_key() :: String.t()
  def client_capabilities_key, do: @client_capabilities_key

  def client_data_model_key, do: @client_data_model_key

  @doc """
  Returns the key for supported catalog IDs within client capabilities.
  """
  @spec supported_catalog_ids_key() :: String.t()
  def supported_catalog_ids_key, do: @supported_catalog_ids_key

  @doc """
  Returns the key for inline catalogs within client capabilities.
  """
  @spec inline_catalogs_key() :: String.t()
  def inline_catalogs_key, do: @inline_catalogs_key

  # ============================================
  # A2A Message Roles
  # ============================================

  @doc """
  Returns the A2A message role for client (user) messages.
  """
  @spec client_role() :: String.t()
  def client_role, do: "user"

  @doc """
  Returns the A2A message role for server (agent) messages.
  """
  @spec server_role() :: String.t()
  def server_role, do: "agent"
end
