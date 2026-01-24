defmodule A2UI.Catalog.Resolver do
  @moduledoc """
  Resolves and validates catalog IDs for A2UI surfaces.

  Per the A2UI v0.8 protocol, catalog negotiation works as follows:

  1. Client advertises `supportedCatalogIds` in capabilities
  2. Server sends `beginRendering.catalogId` (optional in v0.8)
  3. Client validates the catalog is supported before rendering

  ## Current Implementation (Standard Catalog Only)

  This implementation only supports the standard catalog for the given version:
  - If `catalogId` is nil, defaults to standard catalog in v0.8
  - If `catalogId` is a known standard catalog alias for the version, resolves to standard catalog
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
  alias A2UI.Protocol

  @type version :: Protocol.version()
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
    {:ok, Protocol.standard_catalog_id(:v0_8)}
  end

  # v0.9: catalogId is required
  def resolve(nil, _capabilities, :v0_9) do
    {:error, :missing_catalog_id}
  end

  # Check if it's a standard catalog alias
  def resolve(catalog_id, capabilities, version) when is_binary(catalog_id) do
    cond do
      Protocol.standard_catalog_id?(version, catalog_id) ->
        if ClientCapabilities.supports_catalog?(capabilities, catalog_id) do
          {:ok, Protocol.standard_catalog_id(version)}
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

  Includes the problematic catalog ID and list of supported catalogs for the version.
  """
  @spec error_details(String.t() | nil, error_reason(), version()) :: map()
  def error_details(catalog_id, reason, version) do
    %{
      "catalogId" => catalog_id,
      "reason" => to_string(reason),
      "supportedCatalogIds" => Protocol.standard_catalog_ids(version)
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
