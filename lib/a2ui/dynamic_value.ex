defmodule A2UI.DynamicValue do
  @moduledoc """
  Evaluates v0.9 DynamicValue expressions.

  Per `common_types.json`, a DynamicValue can be:
  - A literal value (string, number, boolean, array)
  - A path binding (`%{"path" => "/some/path"}`)
  - A FunctionCall (`%{"call" => "funcName", "args" => %{...}, "returnType" => "string"}`)

  This module provides a unified evaluator that handles all three cases,
  including recursive evaluation of FunctionCall arguments.

  ## FunctionCall Structure

      %{
        "call" => "string_format",
        "args" => %{
          "value" => "Hello ${/name}"
        },
        "returnType" => "string"
      }

  ## Supported Functions

  Standard catalog functions:
  - `required(value)` - checks value is not null/undefined/empty
  - `regex(value, pattern)` - checks value matches regex pattern
  - `length(value, min?, max?)` - checks string/array length
  - `numeric(value, min?, max?)` - checks numeric range
  - `email(value)` - checks valid email format
  - `string_format(value)` - string interpolation

  Built-in functions:
  - `now()` - returns current ISO 8601 timestamp

  ## Usage

      # Evaluate a literal
      DynamicValue.evaluate("hello", data_model, scope_path, opts)
      #=> "hello"

      # Evaluate a path binding
      DynamicValue.evaluate(%{"path" => "/name"}, %{"name" => "Alice"}, nil, [])
      #=> "Alice"

      # Evaluate a FunctionCall
      DynamicValue.evaluate(
        %{"call" => "string_format", "args" => %{"value" => "Hi ${/name}"}, "returnType" => "string"},
        %{"name" => "Bob"},
        nil,
        []
      )
      #=> "Hi Bob"
  """

  alias A2UI.{Binding, Functions}

  @type dynamic_value :: term()
  @type data_model :: map()
  @type scope_path :: String.t() | nil

  @doc """
  Evaluates a DynamicValue to its resolved value.

  Handles:
  - Literal values (string, number, boolean, nil, list)
  - Path bindings (`%{"path" => "..."}``)
  - FunctionCalls (`%{"call" => "...", "args" => %{...}}`)
  - v0.8 literal wrappers (`%{"literalString" => "..."}`, etc.)

  ## Options

  - `:version` - Protocol version (`:v0_8` or `:v0_9`) for path scoping rules

  ## Examples

      iex> A2UI.DynamicValue.evaluate("hello", %{}, nil, [])
      "hello"

      iex> A2UI.DynamicValue.evaluate(%{"path" => "/name"}, %{"name" => "Alice"}, nil, [])
      "Alice"

      iex> A2UI.DynamicValue.evaluate(
      ...>   %{"call" => "required", "args" => %{"value" => "test"}, "returnType" => "boolean"},
      ...>   %{},
      ...>   nil,
      ...>   []
      ...> )
      true
  """
  @spec evaluate(dynamic_value(), data_model(), scope_path(), keyword()) :: term()

  # FunctionCall - detect before other map handlers
  def evaluate(%{"call" => func_name} = value, data_model, scope_path, opts)
      when is_binary(func_name) do
    args = value["args"] || %{}
    # Recursively evaluate args as DynamicValues
    resolved_args = resolve_args(args, data_model, scope_path, opts)
    execute_function(func_name, resolved_args, data_model, scope_path, opts)
  end

  # Path binding with optional literal fallback
  def evaluate(%{"path" => path} = bound, data_model, scope_path, opts) when is_binary(path) do
    version = Keyword.get(opts, :version, :v0_8)

    case Binding.resolve_path(path, data_model, scope_path, version: version) do
      nil -> get_literal_fallback(bound)
      value -> value
    end
  end

  # v0.8 literal wrappers
  def evaluate(%{"literalString" => value}, _data, _scope, _opts), do: value
  def evaluate(%{"literalNumber" => value}, _data, _scope, _opts), do: value
  def evaluate(%{"literalBoolean" => value}, _data, _scope, _opts), do: value
  def evaluate(%{"literalArray" => value}, _data, _scope, _opts), do: value

  # Native literals (v0.9 simplified format)
  def evaluate(value, _data, _scope, _opts) when is_binary(value), do: value
  def evaluate(value, _data, _scope, _opts) when is_number(value), do: value
  def evaluate(value, _data, _scope, _opts) when is_boolean(value), do: value
  def evaluate(nil, _data, _scope, _opts), do: nil
  def evaluate(value, _data, _scope, _opts) when is_list(value), do: value

  # Map without path or call - could be nested structure, return as-is
  # This should be after FunctionCall and path binding checks
  def evaluate(%{} = value, _data, _scope, _opts), do: value

  @doc """
  Checks if a value is a FunctionCall dynamic value.

  ## Examples

      iex> A2UI.DynamicValue.function_call?(%{"call" => "now"})
      true

      iex> A2UI.DynamicValue.function_call?(%{"path" => "/name"})
      false

      iex> A2UI.DynamicValue.function_call?("literal")
      false
  """
  @spec function_call?(term()) :: boolean()
  def function_call?(%{"call" => _}), do: true
  def function_call?(_), do: false

  # ============================================
  # Private Helpers
  # ============================================

  # Recursively resolve function arguments
  defp resolve_args(args, data_model, scope_path, opts) when is_map(args) do
    Map.new(args, fn {key, value} ->
      {key, evaluate(value, data_model, scope_path, opts)}
    end)
  end

  # Get literal fallback from v0.8 format bound value
  defp get_literal_fallback(%{"literalString" => v}), do: v
  defp get_literal_fallback(%{"literalNumber" => v}), do: v
  defp get_literal_fallback(%{"literalBoolean" => v}), do: v
  defp get_literal_fallback(%{"literalArray" => v}), do: v
  defp get_literal_fallback(_), do: nil

  # ============================================
  # Function Execution
  # ============================================

  # Built-in: now() - returns current ISO 8601 timestamp
  defp execute_function("now", _args, _data, _scope, _opts) do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  # Standard catalog: required(value)
  defp execute_function("required", args, _data, _scope, _opts) do
    Functions.required(args["value"])
  end

  # Standard catalog: email(value)
  defp execute_function("email", args, _data, _scope, _opts) do
    Functions.email(args["value"])
  end

  # Standard catalog: regex(value, pattern)
  defp execute_function("regex", args, _data, _scope, _opts) do
    Functions.regex(args["value"], args["pattern"])
  end

  # Standard catalog: length(value, min?, max?)
  defp execute_function("length", args, _data, _scope, _opts) do
    opts = build_min_max_opts(args)
    Functions.length(args["value"], opts)
  end

  # Standard catalog: numeric(value, min?, max?)
  defp execute_function("numeric", args, _data, _scope, _opts) do
    opts = build_min_max_opts(args)
    Functions.numeric(args["value"], opts)
  end

  # Standard catalog: string_format(value)
  # Per v0.9 spec, the parameter is "value" (accepts "template" as legacy fallback)
  defp execute_function("string_format", args, data, scope, opts) do
    # v0.9 spec uses "value", keep "template" as fallback for backward compatibility
    template = args["value"] || args["template"]
    version = Keyword.get(opts, :version, :v0_8)
    Functions.string_format(template, data, scope, version: version)
  end

  # Unknown function - return nil (safe default)
  defp execute_function(_func_name, _args, _data, _scope, _opts) do
    nil
  end

  # Build keyword list with min/max from args
  defp build_min_max_opts(args) do
    opts = []
    opts = if args["min"], do: [{:min, args["min"]} | opts], else: opts
    opts = if args["max"], do: [{:max, args["max"]} | opts], else: opts
    opts
  end
end
