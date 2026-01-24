defmodule A2UI.JSON do
  @moduledoc """
  JSON decoding helpers for A2UI protocol parsing.
  """

  @spec decode_line(String.t()) :: {:ok, map()} | {:error, {:json_decode, term()}}
  def decode_line(json_line) when is_binary(json_line) do
    case Jason.decode(json_line) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:error, {:json_decode, reason}}
    end
  end
end
