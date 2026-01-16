defmodule A2UI.V0_9.Adapter do
  @moduledoc """
  v0.9 protocol entrypoints.

  Provides v0.9-specific parsing and catalog ID management.
  v0.9 messages are parsed into the same internal message structs as v0.8,
  enabling the rest of the renderer to remain version-agnostic.

  ## Key Differences from v0.8

  - `createSurface` replaces `beginRendering` (no explicit `root` field)
  - `updateComponents` replaces `surfaceUpdate`
  - `updateDataModel` replaces `dataModelUpdate` (native JSON instead of adjacency-list)
  - Component format uses `"component": "Text"` discriminator instead of wrapper objects
  - Path scoping: absolute paths `/foo` stay absolute in templates (v0.8 scopes them)

  ## A2A Extension

  For A2A transport, use extension URI: `https://a2ui.org/a2a-extension/a2ui/v0.9`
  See `A2UI.A2A.Protocol.extension_uri(:v0_9)`.
  """

  alias A2UI.Parser
  alias A2UI.Parser.V0_9, as: ParserV09

  @type message :: Parser.message()

  # v0.9 standard catalog ID
  @standard_catalog_id "https://a2ui.dev/specification/v0_9/standard_catalog.json"

  @doc """
  Returns the standard catalog ID for v0.9.
  """
  @spec standard_catalog_id() :: String.t()
  def standard_catalog_id, do: @standard_catalog_id

  @doc """
  Returns all known standard catalog ID aliases for v0.9.
  """
  @spec standard_catalog_ids() :: [String.t()]
  def standard_catalog_ids, do: [@standard_catalog_id]

  @doc """
  Checks if a catalog ID is a known v0.9 standard catalog alias.
  """
  @spec standard_catalog_id?(String.t()) :: boolean()
  def standard_catalog_id?(catalog_id), do: catalog_id == @standard_catalog_id

  @doc """
  Returns the A2A extension URI for v0.9.

  Delegates to `A2UI.A2A.Protocol.extension_uri(:v0_9)`.
  """
  @spec extension_uri() :: String.t()
  def extension_uri, do: A2UI.A2A.Protocol.extension_uri(:v0_9)

  @doc """
  Parses a JSONL line as v0.9 format.

  For auto-detecting format, use `A2UI.Parser.parse_line/1` instead.
  """
  @spec parse_line(String.t()) :: message()
  def parse_line(jsonl_line) do
    case Jason.decode(jsonl_line) do
      {:ok, decoded} ->
        try do
          ParserV09.parse_map(decoded)
        rescue
          exception ->
            {:error, {:parse_exception, exception}}
        end

      {:error, reason} ->
        {:error, {:json_decode, reason}}
    end
  end

  @doc """
  Parses a decoded JSON map as v0.9 format.
  """
  @spec parse_map(map()) :: message()
  def parse_map(decoded), do: ParserV09.parse_map(decoded)

  @doc """
  Legacy compatibility function.
  Deprecated: Use `parse_line/1` instead.
  """
  @deprecated "Use parse_line/1 instead"
  @spec translate_line(String.t()) :: {:ok, term()} | {:error, term()}
  def translate_line(jsonl_line) do
    case parse_line(jsonl_line) do
      {:error, _} = error -> error
      result -> {:ok, result}
    end
  end
end
