defmodule A2UI.V0_8 do
  @moduledoc """
  v0.8 protocol entrypoints.

  The current PoC implementation is v0.8-native end-to-end, so this module is a
  small façade over `A2UI.Parser` to make version boundaries explicit.
  """

  alias A2UI.Parser

  @type message :: Parser.message()

  @spec parse_line(String.t()) :: message()
  def parse_line(jsonl_line), do: Parser.parse_line(jsonl_line)
end
