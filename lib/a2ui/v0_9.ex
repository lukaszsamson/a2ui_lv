defmodule A2UI.V0_9 do
  @moduledoc """
  v0.9 protocol constants.

  Provides v0.9-specific catalog ID management.

  ## Standard Catalog ID

  The v0.9 specification uses a single canonical catalog ID:
  - `"https://a2ui.dev/specification/v0_9/standard_catalog.json"`

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

  @standard_catalog_id "https://a2ui.dev/specification/v0_9/standard_catalog.json"

  @doc """
  Returns the canonical standard catalog ID for v0.9.

  This is the default catalog used when `createSurface.catalogId` is specified.
  Note: v0.9 requires catalogId in createSurface (unlike v0.8 where it was optional).
  """
  @spec standard_catalog_id() :: String.t()
  def standard_catalog_id, do: @standard_catalog_id

  @doc """
  Returns all known standard catalog ID aliases for v0.9.

  v0.9 uses a single canonical catalog ID with no aliases.
  """
  @spec standard_catalog_ids() :: [String.t()]
  def standard_catalog_ids, do: [@standard_catalog_id]

  @doc """
  Checks if a catalog ID is the v0.9 standard catalog.
  """
  @spec standard_catalog_id?(String.t()) :: boolean()
  def standard_catalog_id?(catalog_id), do: catalog_id == @standard_catalog_id

  @doc """
  Returns the A2A extension URI for v0.9.

  Delegates to `A2UI.A2A.Protocol.extension_uri(:v0_9)`.
  """
  @spec extension_uri() :: String.t()
  def extension_uri, do: A2UI.A2A.Protocol.extension_uri(:v0_9)
end
