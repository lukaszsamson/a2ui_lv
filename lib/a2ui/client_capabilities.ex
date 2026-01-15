defmodule A2UI.ClientCapabilities do
  @moduledoc """
  Client capabilities for A2UI catalog negotiation.

  Per v0.8 specification, clients can advertise their capabilities via A2A metadata:
  - `supportedCatalogIds` - List of catalog URIs the client can render
  - `inlineCatalogs` - Map of inline catalog definitions (if server accepts)

  This struct is used during session initialization and can be included
  in A2A metadata for catalog negotiation with servers.

  ## Example

      capabilities = A2UI.ClientCapabilities.new(
        supported_catalog_ids: [
          A2UI.V0_8.standard_catalog_id(),
          "https://example.com/custom-catalog.json"
        ]
      )

      session = A2UI.Session.new(client_capabilities: capabilities)
  """

  @type t :: %__MODULE__{
          supported_catalog_ids: [String.t()],
          inline_catalogs: %{String.t() => map()}
        }

  defstruct supported_catalog_ids: [],
            inline_catalogs: %{}

  @doc """
  Creates a new ClientCapabilities struct.

  ## Options

  - `:supported_catalog_ids` - List of catalog URIs this client supports
  - `:inline_catalogs` - Map of catalog_id => catalog_definition for inline catalogs

  If no `supported_catalog_ids` are provided, defaults to the standard v0.8 catalog.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    supported = opts[:supported_catalog_ids] || [A2UI.V0_8.standard_catalog_id()]
    inline = opts[:inline_catalogs] || %{}

    %__MODULE__{
      supported_catalog_ids: supported,
      inline_catalogs: inline
    }
  end

  @doc """
  Returns the default client capabilities with only the standard catalog.
  """
  @spec default() :: t()
  def default do
    new()
  end

  @doc """
  Checks if a catalog ID is supported by these capabilities.
  """
  @spec supports_catalog?(t(), String.t()) :: boolean()
  def supports_catalog?(capabilities, catalog_id) do
    catalog_id in capabilities.supported_catalog_ids or
      Map.has_key?(capabilities.inline_catalogs, catalog_id)
  end

  @doc """
  Converts capabilities to A2A metadata format.

  Returns a map suitable for inclusion in A2A message metadata under
  the `a2uiClientCapabilities` key.
  """
  @spec to_a2a_metadata(t()) :: map()
  def to_a2a_metadata(capabilities) do
    metadata = %{"supportedCatalogIds" => capabilities.supported_catalog_ids}

    if map_size(capabilities.inline_catalogs) > 0 do
      Map.put(metadata, "inlineCatalogs", capabilities.inline_catalogs)
    else
      metadata
    end
  end
end
