defmodule A2UI.V0_9 do
  @moduledoc """
  v0.9 protocol constants.

  Provides v0.9-specific catalog ID management.

  ## Standard Catalog ID

  The v0.9 specification uses a single canonical catalog ID:
  - `"https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"`

  ## Wire Format Differences from v0.8

  v0.9 uses different envelope names:
  - `createSurface` (was `beginRendering`)
  - `updateComponents` (was `surfaceUpdate`)
  - `updateDataModel` (was `dataModelUpdate`)
  - `deleteSurface` (was `endRendering`)

  Components use flat structure:
  - `"component": "Text"` (not `"component": {"Text": {...}}`)
  - Properties are siblings of `component`, not nested inside
  - `children` is a plain array of IDs (not `{"explicitList": [...]}`)
  """

  alias A2UI.Protocol

  @doc "Parses and validates a released v0.9 JSONL message."
  def parse_line(jsonl_line) do
    with {:ok, decoded} <- A2UI.JSON.decode_line(jsonl_line),
         :ok <- A2UI.Validator.validate_server_message(decoded, :v0_9) do
      A2UI.Parser.V0_9.parse_map(Map.delete(decoded, "version"), :v0_9)
    end
  rescue
    exception -> {:error, {:parse_exception, exception}}
  end

  @doc "Parses and validates a decoded released v0.9 message."
  def parse_map(decoded) do
    with :ok <- A2UI.Validator.validate_server_message(decoded, :v0_9) do
      A2UI.Parser.V0_9.parse_map(Map.delete(decoded, "version"), :v0_9)
    end
  end

  @doc """
  Returns the canonical standard catalog ID for v0.9.

  This is the default catalog used when `createSurface.catalogId` is specified.
  Note: v0.9 requires catalogId in createSurface (unlike v0.8 where it was optional).
  """
  @spec standard_catalog_id() :: String.t()
  def standard_catalog_id, do: Protocol.standard_catalog_id(:v0_9)

  @doc """
  Returns all known standard catalog ID aliases for v0.9.

  v0.9 uses a single canonical catalog ID with no aliases.
  """
  @spec standard_catalog_ids() :: [String.t()]
  def standard_catalog_ids, do: Protocol.standard_catalog_ids(:v0_9)

  @doc """
  Checks if a catalog ID is the v0.9 standard catalog.
  """
  @spec standard_catalog_id?(String.t()) :: boolean()
  def standard_catalog_id?(catalog_id), do: Protocol.standard_catalog_id?(:v0_9, catalog_id)

  @doc """
  Returns the A2A extension URI for v0.9.

  Delegates to `A2UI.A2A.Protocol.extension_uri(:v0_9)`.
  """
  @spec extension_uri() :: String.t()
  def extension_uri, do: Protocol.extension_uri(:v0_9)
end
