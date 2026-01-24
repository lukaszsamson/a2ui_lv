defmodule A2UI.Catalog.Resolver do
  @moduledoc """
  Resolves and validates catalog IDs for A2UI surfaces.

  Per the A2UI v0.8 protocol, catalog negotiation works as follows:

  1. Client advertises `supportedCatalogIds` in capabilities
  2. Server sends `beginRendering.catalogId` (optional in v0.8)
  3. Client validates the catalog is supported before rendering

  ## Current Implementation (Standard Catalog Only)

  This implementation only supports the v0.8 standard catalog:
  - If `catalogId` is nil, defaults to standard catalog
  - If `catalogId` is a known standard catalog alias, resolves to standard catalog
  - All other catalog IDs are rejected with an error

  Inline catalogs are not supported and will return an error.

  ## Version Compatibility

  The resolver accepts a protocol version (`:v0_8` or `:v0_9`) to handle
  version-specific rules:
  - v0.8: `catalogId` is optional (defaults to standard)
  - v0.9: `catalogId` is required (no default)

  ## Usage

      case A2UI.Catalog.Resolver.resolve(catalog_id, capabilities, :v0_8) do
        {:ok, resolved_id} ->
          # Use resolved_id for rendering
        {:error, reason} ->
          # Handle error (emit error event, reject surface)
      end
  """

  alias A2UI.ClientCapabilities

  @type version :: :v0_8 | :v0_9
  @type error_reason ::
          :unsupported_catalog
          | :inline_catalog_not_supported
          | :missing_catalog_id
          | :catalog_not_in_capabilities

  @doc """
  Resolves a catalog ID for a surface.

  ## Parameters

  - `catalog_id` - The catalog ID from `beginRendering.catalogId` (may be nil)
  - `capabilities` - The client's `A2UI.ClientCapabilities`
  - `version` - Protocol version (`:v0_8` or `:v0_9`)

  ## Returns

  - `{:ok, resolved_catalog_id}` - Successfully resolved catalog ID
  - `{:error, reason}` - Resolution failed

  ## Error Reasons

  - `:missing_catalog_id` - v0.9 requires catalogId but none provided
  - `:unsupported_catalog` - Catalog ID is not a known standard catalog
  - `:inline_catalog_not_supported` - Inline catalogs are not supported
  - `:catalog_not_in_capabilities` - Catalog not in client's supported list
  """
  @spec resolve(String.t() | nil, ClientCapabilities.t(), version()) ::
          {:ok, String.t()} | {:error, error_reason()}
  def resolve(catalog_id, capabilities, version \\ :v0_8)

  # v0.8: nil catalogId defaults to standard catalog
  def resolve(nil, _capabilities, :v0_8) do
    {:ok, A2UI.V0_8.standard_catalog_id()}
  end

  # v0.9: catalogId is required
  def resolve(nil, _capabilities, :v0_9) do
    {:error, :missing_catalog_id}
  end

  # Check if it's a standard catalog alias
  def resolve(catalog_id, capabilities, _version) when is_binary(catalog_id) do
    cond do
      # Check if it's a known v0.8 standard catalog alias
      A2UI.V0_8.standard_catalog_id?(catalog_id) ->
        # Verify client supports it (should always be true for standard)
        if ClientCapabilities.supports_catalog?(capabilities, catalog_id) do
          {:ok, A2UI.V0_8.standard_catalog_id()}
        else
          {:error, :catalog_not_in_capabilities}
        end

      # Check if it's the v0.9 standard catalog
      A2UI.V0_9.standard_catalog_id?(catalog_id) ->
        if ClientCapabilities.supports_catalog?(capabilities, catalog_id) do
          {:ok, A2UI.V0_9.standard_catalog_id()}
        else
          {:error, :catalog_not_in_capabilities}
        end

      # Check if it's an inline catalog (not supported)
      inline_catalog?(capabilities, catalog_id) ->
        {:error, :inline_catalog_not_supported}

      # Check if client claims to support it (but we don't)
      ClientCapabilities.supports_catalog?(capabilities, catalog_id) ->
        {:error, :unsupported_catalog}

      # Unknown catalog
      true ->
        {:error, :unsupported_catalog}
    end
  end

  @doc """
  Formats an error reason as a human-readable message.

  ## Examples

      iex> A2UI.Catalog.Resolver.format_error(:unsupported_catalog)
      "Unsupported catalog: only standard catalog is supported"

      iex> A2UI.Catalog.Resolver.format_error(:inline_catalog_not_supported)
      "Inline catalogs are not supported"
  """
  @spec format_error(error_reason()) :: String.t()
  def format_error(:missing_catalog_id) do
    "catalogId is required for v0.9 protocol"
  end

  def format_error(:unsupported_catalog) do
    "Unsupported catalog: only standard catalog is supported"
  end

  def format_error(:inline_catalog_not_supported) do
    "Inline catalogs are not supported"
  end

  def format_error(:catalog_not_in_capabilities) do
    "Catalog ID not in client's supported catalog list"
  end

  @doc """
  Returns details map for error reporting.

  Includes the problematic catalog ID and list of supported catalogs.
  """
  @spec error_details(String.t() | nil, error_reason()) :: map()
  def error_details(catalog_id, reason) do
    %{
      "catalogId" => catalog_id,
      "reason" => to_string(reason),
      "supportedCatalogIds" =>
        A2UI.V0_8.standard_catalog_ids() ++ A2UI.V0_9.standard_catalog_ids()
    }
  end

  # Private helpers

  defp inline_catalog?(capabilities, catalog_id) do
    case ClientCapabilities.get_inline_catalog(capabilities, catalog_id) do
      {:ok, _catalog} -> true
      :error -> false
    end
  end
end
