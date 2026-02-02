defmodule A2UI.Transport.A2A.AgentCard do
  @moduledoc """
  A2A Agent Card parsing and validation.

  Per the A2A specification, agents publish their capabilities at
  `/.well-known/agent.json`. This module parses that response and
  checks for A2UI extension support.

  ## Agent Card Structure

  A minimal agent card for A2UI support:

      {
        "name": "My A2UI Agent",
        "url": "http://localhost:3002",
        "capabilities": {
          "extensions": [{
            "uri": "https://a2ui.org/a2a-extension/a2ui/v0.8",
            "params": {
              "supportedCatalogIds": ["https://a2ui.org/standard-catalog/v0.8/main.json"],
              "acceptsInlineCatalogs": false
            }
          }]
        }
      }

  ## Usage

      # Parse an agent card response
      {:ok, card} = A2UI.Transport.A2A.AgentCard.parse(json_response)

      # Check A2UI support
      if A2UI.Transport.A2A.AgentCard.supports_a2ui?(card) do
        # Agent supports A2UI v0.8
      end

      # Check if agent accepts inline catalogs
      A2UI.Transport.A2A.AgentCard.accepts_inline_catalogs?(card)
  """

  alias A2UI.A2A.Protocol

  @type t :: %__MODULE__{
          name: String.t(),
          url: String.t(),
          description: String.t() | nil,
          extensions: [extension()],
          capabilities: map(),
          raw: map()
        }

  @type extension :: %{
          uri: String.t(),
          params: map()
        }

  defstruct [
    :name,
    :url,
    :description,
    extensions: [],
    capabilities: %{},
    raw: %{}
  ]

  @doc """
  Converts an a2a_ex AgentCard struct to an A2UI AgentCard.

  This adapter allows using the a2a_ex library for agent card discovery
  while maintaining the A2UI-specific AgentCard structure.

  ## Examples

      iex> a2a_card = %A2A.Types.AgentCard{name: "Test", url: "http://localhost:3002"}
      iex> card = A2UI.Transport.A2A.AgentCard.from_a2a_ex(a2a_card)
      iex> card.name
      "Test"
  """
  @spec from_a2a_ex(A2A.Types.AgentCard.t()) :: t()
  def from_a2a_ex(%A2A.Types.AgentCard{} = a2a_card) do
    extensions = extract_extensions_from_capabilities(a2a_card.capabilities)

    %__MODULE__{
      name: a2a_card.name,
      url: a2a_card.url,
      description: a2a_card.description,
      extensions: extensions,
      capabilities: capabilities_to_map(a2a_card.capabilities),
      raw: A2A.Types.AgentCard.to_map(a2a_card)
    }
  end

  @doc """
  Parses an agent card JSON response into an AgentCard struct.

  ## Examples

      iex> json = %{
      ...>   "name" => "Test Agent",
      ...>   "url" => "http://localhost:3002",
      ...>   "capabilities" => %{"extensions" => []}
      ...> }
      iex> {:ok, card} = A2UI.Transport.A2A.AgentCard.parse(json)
      iex> card.name
      "Test Agent"
  """
  @spec parse(map() | String.t()) :: {:ok, t()} | {:error, atom()}
  def parse(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, map} -> parse(map)
      {:error, _} -> {:error, :invalid_json}
    end
  end

  def parse(%{"name" => name, "url" => url} = json) when is_binary(name) and is_binary(url) do
    capabilities = json["capabilities"] || %{}
    extensions = parse_extensions(capabilities["extensions"] || [])

    card = %__MODULE__{
      name: name,
      url: url,
      description: json["description"],
      extensions: extensions,
      capabilities: capabilities,
      raw: json
    }

    {:ok, card}
  end

  def parse(%{} = json) do
    # Try with atom keys
    cond do
      Map.has_key?(json, :name) and Map.has_key?(json, :url) ->
        parse(%{
          "name" => json[:name],
          "url" => json[:url],
          "description" => json[:description],
          "capabilities" => json[:capabilities]
        })

      true ->
        {:error, :missing_required_fields}
    end
  end

  def parse(_), do: {:error, :invalid_format}

  @doc """
  Checks if the agent card indicates A2UI support.

  ## Parameters

  - `card` - The parsed agent card
  - `version` - The A2UI version to check for (default: `:v0_8`)

  ## Examples

      iex> card = %A2UI.Transport.A2A.AgentCard{extensions: [%{uri: "https://a2ui.org/a2a-extension/a2ui/v0.8", params: %{}}]}
      iex> A2UI.Transport.A2A.AgentCard.supports_a2ui?(card)
      true
  """
  @spec supports_a2ui?(t(), atom()) :: boolean()
  def supports_a2ui?(%__MODULE__{extensions: extensions}, version \\ :v0_8) do
    target_uri = Protocol.extension_uri(version)

    Enum.any?(extensions, fn
      %{uri: uri} -> uri == target_uri
      _ -> false
    end)
  end

  @doc """
  Gets the A2UI extension configuration from the agent card.

  Returns the extension params if found, or `nil` if not.

  ## Examples

      iex> card = %A2UI.Transport.A2A.AgentCard{extensions: [%{uri: "https://a2ui.org/a2a-extension/a2ui/v0.8", params: %{"acceptsInlineCatalogs" => true}}]}
      iex> ext = A2UI.Transport.A2A.AgentCard.get_a2ui_extension(card)
      iex> ext.params["acceptsInlineCatalogs"]
      true
  """
  @spec get_a2ui_extension(t(), atom()) :: extension() | nil
  def get_a2ui_extension(%__MODULE__{extensions: extensions}, version \\ :v0_8) do
    target_uri = Protocol.extension_uri(version)

    Enum.find(extensions, fn
      %{uri: uri} -> uri == target_uri
      _ -> false
    end)
  end

  @doc """
  Checks if the agent accepts inline catalog definitions.

  Per the A2UI spec, this is indicated by the `acceptsInlineCatalogs` param
  in the A2UI extension configuration.

  ## Examples

      iex> card = %A2UI.Transport.A2A.AgentCard{extensions: [%{uri: "https://a2ui.org/a2a-extension/a2ui/v0.8", params: %{"acceptsInlineCatalogs" => true}}]}
      iex> A2UI.Transport.A2A.AgentCard.accepts_inline_catalogs?(card)
      true
  """
  @spec accepts_inline_catalogs?(t()) :: boolean()
  def accepts_inline_catalogs?(%__MODULE__{} = card) do
    case get_a2ui_extension(card) do
      %{params: %{"acceptsInlineCatalogs" => true}} -> true
      _ -> false
    end
  end

  @doc """
  Gets the supported catalog IDs from the agent's A2UI extension.

  Returns an empty list if the extension is not found or has no catalog IDs.
  """
  @spec supported_catalog_ids(t()) :: [String.t()]
  def supported_catalog_ids(%__MODULE__{} = card) do
    case get_a2ui_extension(card) do
      %{params: %{"supportedCatalogIds" => ids}} when is_list(ids) -> ids
      _ -> []
    end
  end

  @doc """
  Gets the agent's task endpoint URL.

  This is typically `{base_url}/a2a/tasks`.
  """
  @spec tasks_url(t()) :: String.t()
  def tasks_url(%__MODULE__{url: base_url}) do
    base_url
    |> URI.parse()
    |> Map.update!(:path, fn
      nil -> "/a2a/tasks"
      path -> String.trim_trailing(path, "/") <> "/a2a/tasks"
    end)
    |> URI.to_string()
  end

  @doc """
  Gets the URL for a specific task.
  """
  @spec task_url(t(), String.t()) :: String.t()
  def task_url(%__MODULE__{} = card, task_id) do
    tasks_url(card) <> "/" <> task_id
  end

  # Private helpers

  defp parse_extensions(extensions) when is_list(extensions) do
    Enum.map(extensions, fn
      %{"uri" => uri} = ext when is_binary(uri) ->
        %{
          uri: uri,
          params: ext["params"] || %{}
        }

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_extensions(_), do: []

  # Helper functions for from_a2a_ex/1

  defp extract_extensions_from_capabilities(nil), do: []

  defp extract_extensions_from_capabilities(%A2A.Types.AgentCapabilities{extensions: nil}), do: []

  defp extract_extensions_from_capabilities(%A2A.Types.AgentCapabilities{extensions: extensions}) do
    Enum.map(extensions, fn
      %A2A.Types.AgentExtension{uri: uri, metadata: metadata} ->
        %{
          uri: uri,
          params: metadata || %{}
        }

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp capabilities_to_map(nil), do: %{}

  defp capabilities_to_map(%A2A.Types.AgentCapabilities{} = capabilities) do
    A2A.Types.AgentCapabilities.to_map(capabilities)
  end
end
