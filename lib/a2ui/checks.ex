defmodule A2UI.Checks do
  @moduledoc """
  Evaluates v0.9 validation checks (CheckRule and LogicExpression).

  Used for:
  - Input component validation: Show error messages when checks fail
  - Button state: Disable buttons when any check fails

  ## CheckRule Structure

  Each check rule is a LogicExpression with a required `message` field:

      %{
        "call" => "required",
        "args" => %{"value" => %{"path" => "/email"}},
        "message" => "Email is required"
      }

  ## LogicExpression Types

  - `%{"call" => name, "args" => ...}` - Function call
  - `%{"and" => [...]}` - All conditions must be true
  - `%{"or" => [...]}` - At least one must be true
  - `%{"not" => expr}` - Negation
  - `%{"true" => true}` - Literal true
  - `%{"false" => false}` - Literal false

  ## Usage

      # Evaluate a list of checks, get failing messages
      messages = A2UI.Checks.evaluate_checks(checks, data_model, scope_path, opts)
      #=> ["Email is required", "Must be valid email"]

      # Check if all checks pass (for button enabled state)
      all_pass? = A2UI.Checks.all_pass?(checks, data_model, scope_path, opts)
      #=> false
  """

  alias A2UI.{DynamicValue, Functions}

  @type check_rule :: map()
  @type logic_expression :: map()
  @type data_model :: map()
  @type scope_path :: String.t() | nil

  # ============================================
  # Public API
  # ============================================

  @doc """
  Evaluates a list of check rules and returns the messages of failing checks.

  Returns an empty list if all checks pass, otherwise returns a list of
  error messages from failed checks.

  ## Options

  - `:version` - Protocol version (`:v0_8` or `:v0_9`) for path scoping rules

  ## Examples

      iex> checks = [
      ...>   %{"call" => "required", "args" => %{"value" => %{"path" => "/email"}}, "message" => "Email required"},
      ...>   %{"call" => "email", "args" => %{"value" => %{"path" => "/email"}}, "message" => "Invalid email"}
      ...> ]
      iex> A2UI.Checks.evaluate_checks(checks, %{"email" => ""}, nil)
      ["Email required", "Invalid email"]

      iex> A2UI.Checks.evaluate_checks(checks, %{"email" => "test@example.com"}, nil)
      []
  """
  @spec evaluate_checks(list(check_rule()), data_model(), scope_path(), keyword()) :: [String.t()]
  def evaluate_checks(nil, _data_model, _scope_path, _opts), do: []
  def evaluate_checks([], _data_model, _scope_path, _opts), do: []

  def evaluate_checks(checks, data_model, scope_path, opts \\ []) when is_list(checks) do
    checks
    |> Enum.filter(fn check ->
      # A check fails if its expression evaluates to false
      not evaluate_expression(check, data_model, scope_path, opts)
    end)
    |> Enum.map(fn check ->
      check["message"] || "Validation failed"
    end)
  end

  @doc """
  Returns true if all checks pass, false otherwise.

  This is a convenience function for button enabled state.

  ## Examples

      iex> checks = [%{"call" => "required", "args" => %{"value" => "hello"}, "message" => "Required"}]
      iex> A2UI.Checks.all_pass?(checks, %{}, nil)
      true

      iex> checks = [%{"call" => "required", "args" => %{"value" => ""}, "message" => "Required"}]
      iex> A2UI.Checks.all_pass?(checks, %{}, nil)
      false
  """
  @spec all_pass?(list(check_rule()) | nil, data_model(), scope_path(), keyword()) :: boolean()
  def all_pass?(nil, _data_model, _scope_path, _opts), do: true
  def all_pass?([], _data_model, _scope_path, _opts), do: true

  def all_pass?(checks, data_model, scope_path, opts \\ []) when is_list(checks) do
    Enum.all?(checks, fn check ->
      evaluate_expression(check, data_model, scope_path, opts)
    end)
  end

  # ============================================
  # Expression Evaluation
  # ============================================

  @doc """
  Evaluates a LogicExpression to a boolean.

  ## Expression Types

  - `%{"and" => [...]}` - All sub-expressions must be true
  - `%{"or" => [...]}` - At least one sub-expression must be true
  - `%{"not" => expr}` - Negation of the sub-expression
  - `%{"call" => name, "args" => ...}` - Function call
  - `%{"true" => true}` - Literal true
  - `%{"false" => false}` - Literal false
  """
  @spec evaluate_expression(logic_expression(), data_model(), scope_path(), keyword()) :: boolean()

  # Literal true
  def evaluate_expression(%{"true" => true}, _data, _scope, _opts), do: true

  # Literal false
  def evaluate_expression(%{"false" => false}, _data, _scope, _opts), do: false

  # AND: all must be true
  def evaluate_expression(%{"and" => exprs}, data, scope, opts) when is_list(exprs) do
    Enum.all?(exprs, &evaluate_expression(&1, data, scope, opts))
  end

  # OR: at least one must be true
  def evaluate_expression(%{"or" => exprs}, data, scope, opts) when is_list(exprs) do
    Enum.any?(exprs, &evaluate_expression(&1, data, scope, opts))
  end

  # NOT: negate the expression
  def evaluate_expression(%{"not" => expr}, data, scope, opts) when is_map(expr) do
    not evaluate_expression(expr, data, scope, opts)
  end

  # Function call
  def evaluate_expression(%{"call" => func_name} = expr, data, scope, opts) when is_binary(func_name) do
    args = expr["args"] || %{}
    resolved_args = resolve_function_args(args, data, scope, opts)
    execute_check_function(func_name, resolved_args)
  end

  # Unknown expression - treat as true (fail-safe)
  def evaluate_expression(_expr, _data, _scope, _opts), do: true

  # ============================================
  # Function Execution
  # ============================================

  # Resolve function arguments from the args map using DynamicValue evaluator
  # This supports nested FunctionCalls in args
  defp resolve_function_args(args, data, scope, opts) when is_map(args) do
    Map.new(args, fn {key, value} ->
      {key, DynamicValue.evaluate(value, data, scope, opts)}
    end)
  end

  # Execute a standard catalog check function
  defp execute_check_function("required", args) do
    Functions.required(args["value"])
  end

  defp execute_check_function("email", args) do
    Functions.email(args["value"])
  end

  defp execute_check_function("regex", args) do
    Functions.regex(args["value"], args["pattern"])
  end

  defp execute_check_function("length", args) do
    opts = build_min_max_opts(args)
    Functions.length(args["value"], opts)
  end

  defp execute_check_function("numeric", args) do
    opts = build_min_max_opts(args)
    Functions.numeric(args["value"], opts)
  end

  # Unknown function - treat as passing (fail-safe)
  defp execute_check_function(_func_name, _args), do: true

  # Build keyword list with min/max from args
  defp build_min_max_opts(args) do
    opts = []
    opts = if args["min"], do: [{:min, args["min"]} | opts], else: opts
    opts = if args["max"], do: [{:max, args["max"]} | opts], else: opts
    opts
  end
end
