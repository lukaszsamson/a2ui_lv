defmodule A2UI.ClientCapabilities do
  @moduledoc """
  Client capabilities for A2UI catalog negotiation.

  Per v0.8 specification (section 2.1 "Catalog Negotiation"), clients advertise
  their capabilities via A2A metadata in every message sent to the server:

  - `supportedCatalogIds` - List of catalog URIs the client can render
  - `inlineCatalogs` - Array of inline catalog definition documents (if server accepts)

  This struct is used during session initialization and can be included
  in A2A metadata for catalog negotiation with servers.

  ## Inline Catalogs Format

  Per the spec, `inlineCatalogs` is an **array** of catalog definition documents,
  where each document has:

  - `catalogId` (string, required) - Unique identifier for this catalog
  - `components` (object, required) - Component definitions
  - `styles` (object, optional) - Style definitions

  ## Example

      capabilities = A2UI.ClientCapabilities.new(
        supported_catalog_ids: [
          A2UI.V0_8.standard_catalog_id(),
          "https://example.com/custom-catalog.json"
        ],
        inline_catalogs: [
          %{
            "catalogId" => "https://my-company.com/inline/custom-widgets",
            "components" => %{
              "CustomWidget" => %{
                "type" => "object",
                "properties" => %{"color" => %{"type" => "string"}}
              }
            },
            "styles" => %{}
          }
        ]
      )

      session = A2UI.Session.new(client_capabilities: capabilities)
  """

  @type catalog_definition :: %{
          required(String.t()) => String.t() | map()
        }

  @type t :: %__MODULE__{
          supported_catalog_ids: [String.t()],
          inline_catalogs: [catalog_definition()]
        }

  defstruct supported_catalog_ids: [],
            inline_catalogs: []

  @doc """
  Creates a new ClientCapabilities struct.

  ## Options

  - `:supported_catalog_ids` - List of catalog URIs this client supports
  - `:inline_catalogs` - List of inline catalog definition documents

  If no `supported_catalog_ids` are provided, defaults to the standard v0.8 catalog.

  ## Inline Catalog Format

  Each inline catalog must be a map with at least:
  - `"catalogId"` - Unique identifier string
  - `"components"` - Component definitions map
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    supported = opts[:supported_catalog_ids] || [A2UI.V0_8.standard_catalog_id()]
    inline = opts[:inline_catalogs] || []

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

  Returns true if the catalog ID is in `supported_catalog_ids` or
  matches the `catalogId` of any inline catalog.
  """
  @spec supports_catalog?(t(), String.t()) :: boolean()
  def supports_catalog?(capabilities, catalog_id) do
    catalog_id in capabilities.supported_catalog_ids or
      Enum.any?(capabilities.inline_catalogs, fn catalog ->
        catalog["catalogId"] == catalog_id
      end)
  end

  @doc """
  Looks up an inline catalog by its ID.

  Returns `{:ok, catalog}` if found, or `:error` if not found.
  """
  @spec get_inline_catalog(t(), String.t()) :: {:ok, catalog_definition()} | :error
  def get_inline_catalog(capabilities, catalog_id) do
    case Enum.find(capabilities.inline_catalogs, fn c -> c["catalogId"] == catalog_id end) do
      nil -> :error
      catalog -> {:ok, catalog}
    end
  end

  @doc """
  Converts capabilities to A2A metadata format.

  Returns a map suitable for inclusion in A2A message metadata under
  the `a2uiClientCapabilities` key.

  Per the v0.8 spec, the format is:
  - `supportedCatalogIds` - Array of catalog ID strings
  - `inlineCatalogs` - Array of catalog definition documents (only if non-empty)
  """
  @spec to_a2a_metadata(t()) :: map()
  def to_a2a_metadata(capabilities) do
    metadata = %{"supportedCatalogIds" => capabilities.supported_catalog_ids}

    if length(capabilities.inline_catalogs) > 0 do
      Map.put(metadata, "inlineCatalogs", capabilities.inline_catalogs)
    else
      metadata
    end
  end
end
