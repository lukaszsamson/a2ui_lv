defmodule A2UI.BoundValue do
  @moduledoc """
  Helpers for v0.8 BoundValue literal extraction.
  """

  @literal_keys ~w(literalString literalNumber literalBoolean literalArray)

  @spec literal_keys() :: [String.t()]
  def literal_keys, do: @literal_keys

  @spec extract_literal(map()) :: {:ok, term()} | :error
  def extract_literal(%{} = term) do
    cond do
      Map.has_key?(term, "literalString") -> {:ok, term["literalString"]}
      Map.has_key?(term, "literalNumber") -> {:ok, term["literalNumber"]}
      Map.has_key?(term, "literalBoolean") -> {:ok, term["literalBoolean"]}
      Map.has_key?(term, "literalArray") -> {:ok, term["literalArray"]}
      true -> :error
    end
  end

  def extract_literal(_), do: :error
end
