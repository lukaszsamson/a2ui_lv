defmodule A2UI.V0_8 do
  @moduledoc """
  v0.8 protocol entrypoints.

  Provides v0.8-specific parsing and catalog ID management.

  ## Standard Catalog ID Aliases

  The v0.8 specification uses different catalog IDs in different sources:
  - `server_to_client.json`: `a2ui.org:standard_catalog_0_8_0`
  - `a2ui_protocol.md`: GitHub URL

  This module normalizes these by treating all known v0.8 aliases as equivalent.
  Use `standard_catalog_ids/0` to get all known aliases.
  """

  alias A2UI.Parser
  alias A2UI.Parser.V0_8, as: ParserV08

  @type message :: Parser.message()

  # Canonical ID (GitHub URL from protocol spec)
  @standard_catalog_id "https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json"

  # All known v0.8 standard catalog ID aliases
  @standard_catalog_ids [
    # From a2ui_protocol.md (canonical)
    "https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json",
    # From server_to_client.json schema
    "a2ui.org:standard_catalog_0_8_0"
  ]

  # TODO: v0.9 uses a different catalog ID format:
  # "https://a2ui.dev/specification/v0_9/standard_catalog.json"
  # When v0.9 support is added, create A2UI.V0_9.standard_catalog_ids/0

  @doc """
  Returns the canonical standard catalog ID for v0.8.

  This is the default catalog used when `beginRendering.catalogId` is not specified.
  """
  @spec standard_catalog_id() :: String.t()
  def standard_catalog_id, do: @standard_catalog_id

  @doc """
  Returns all known standard catalog ID aliases for v0.8.

  The v0.8 specification uses different IDs in different sources. This function
  returns all known aliases that should be treated as equivalent to the standard
  catalog.

  ## Known Aliases

  - `"https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json"` - from protocol spec
  - `"a2ui.org:standard_catalog_0_8_0"` - from server_to_client.json schema
  """
  @spec standard_catalog_ids() :: [String.t()]
  def standard_catalog_ids, do: @standard_catalog_ids

  @doc """
  Checks if a catalog ID is a known v0.8 standard catalog alias.
  """
  @spec standard_catalog_id?(String.t()) :: boolean()
  def standard_catalog_id?(catalog_id), do: catalog_id in @standard_catalog_ids

  @doc """
  Returns the A2A extension URI for v0.8.

  Delegates to `A2UI.A2A.Protocol.extension_uri(:v0_8)`.
  """
  @spec extension_uri() :: String.t()
  def extension_uri, do: A2UI.A2A.Protocol.extension_uri(:v0_8)

  @doc """
  Parses a JSONL line as v0.8 format.

  For auto-detecting format, use `A2UI.Parser.parse_line/1` instead.
  """
  @spec parse_line(String.t()) :: message()
  def parse_line(jsonl_line) do
    case Jason.decode(jsonl_line) do
      {:ok, decoded} ->
        try do
          ParserV08.parse_map(decoded)
        rescue
          exception ->
            {:error, {:parse_exception, exception}}
        end

      {:error, reason} ->
        {:error, {:json_decode, reason}}
    end
  end

  @doc """
  Parses a decoded JSON map as v0.8 format.
  """
  @spec parse_map(map()) :: message()
  def parse_map(decoded), do: ParserV08.parse_map(decoded)
end
