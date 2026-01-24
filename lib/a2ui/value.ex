defmodule A2UI.Value do
  @moduledoc """
  Resolves bound and dynamic values against a data model.
  """

  @type value :: term()
  @type data_model :: map()
  @type scope_path :: String.t() | nil

  alias A2UI.{Binding, BoundValue, Functions}

  @doc """
  Resolves a value to its concrete representation.

  Handles:
  - v0.8 typed literals
  - JSON pointer paths with fallback literals
  - function calls with evaluated arguments
  """
  @spec resolve(value(), data_model(), scope_path(), keyword()) :: term()
  def resolve(value, data_model, scope_path \\ nil, opts \\ [])

  def resolve(%{"call" => func_name} = value, data_model, scope_path, opts)
      when is_binary(func_name) do
    args = value["args"] || %{}
    resolved_args = resolve_args(args, data_model, scope_path, opts)
    Functions.call(func_name, resolved_args, data_model, scope_path, opts)
  end

  def resolve(%{"path" => path} = bound, data_model, scope_path, opts) when is_binary(path) do
    case Binding.resolve_path(path, data_model, scope_path, opts) do
      nil -> literal_fallback(bound)
      value -> value
    end
  end

  def resolve(value, _data, _scope, _opts) when is_binary(value), do: value
  def resolve(value, _data, _scope, _opts) when is_number(value), do: value
  def resolve(value, _data, _scope, _opts) when is_boolean(value), do: value
  def resolve(value, _data, _scope, _opts) when is_list(value), do: value
  def resolve(nil, _data, _scope, _opts), do: nil

  def resolve(%{} = value, _data, _scope, _opts) do
    case BoundValue.extract_literal(value) do
      {:ok, literal} -> literal
      :error -> value
    end
  end

  defp resolve_args(args, data_model, scope_path, opts) when is_map(args) do
    Map.new(args, fn {key, value} ->
      {key, resolve(value, data_model, scope_path, opts)}
    end)
  end

  defp literal_fallback(term) do
    case BoundValue.extract_literal(term) do
      {:ok, value} -> value
      :error -> nil
    end
  end
end
