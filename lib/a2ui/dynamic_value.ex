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

  alias A2UI.Value

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
  def evaluate(value, data_model, scope_path, opts \\ []) do
    Value.resolve(value, data_model, scope_path, opts)
  end

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
end
