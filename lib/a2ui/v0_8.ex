defmodule A2UI.V0_8 do
  @moduledoc """
  v0.8 protocol entrypoints.

  The current PoC implementation is v0.8-native end-to-end, so this module is a
  small façade over `A2UI.Parser` to make version boundaries explicit.
  """

  alias A2UI.Parser

  @type message :: Parser.message()

  @standard_catalog_id "https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json"

  @doc """
  Returns the standard catalog ID for v0.8.

  This is the default catalog used when `beginRendering.catalogId` is not specified.
  """
  @spec standard_catalog_id() :: String.t()
  def standard_catalog_id, do: @standard_catalog_id

  @spec parse_line(String.t()) :: message()
  def parse_line(jsonl_line), do: Parser.parse_line(jsonl_line)
end
