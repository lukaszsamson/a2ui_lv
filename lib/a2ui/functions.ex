defmodule A2UI.Functions do
  @moduledoc """
  Standard catalog function implementations for A2UI v0.9.

  These functions are used for:
  - Validation in Checkable components (required, regex, length, numeric, email)
  - String interpolation (string_format with `${expression}` syntax)

  ## Validation Functions

  All validation functions return a boolean:
  - `required/1` - checks value is not null/undefined/empty
  - `regex/2` - checks value matches a regex pattern
  - `length/2` - checks string length constraints (min/max)
  - `numeric/2` - checks numeric range constraints (min/max)
  - `email/1` - checks valid email format

  ## String Interpolation

  The `string_format/3` function performs interpolation of `${expression}` patterns:
  - `${/path}` - absolute JSON Pointer path
  - `${path}` - relative JSON Pointer path (scoped)
  - `${functionName(args)}` - function call (see supported functions below)
  - `\\${` - escaped literal `${`

  ### Supported Function Calls in Interpolation

  - `${now()}` - current ISO 8601 timestamp
  - `${required(value)}` - returns boolean
  - `${email(value)}` - returns boolean
  - `${regex(value, pattern)}` - returns boolean
  - `${length(value, min?, max?)}` - returns boolean
  - `${numeric(value, min?, max?)}` - returns boolean
  - `${string_format(template)}` - nested interpolation

  Unknown functions return `nil` (interpolated as empty string).

  ## Usage

      iex> A2UI.Functions.required("hello")
      true

      iex> A2UI.Functions.email("test@example.com")
      true

      iex> A2UI.Functions.string_format("Hello, ${/name}!", %{"name" => "Alice"}, nil)
      "Hello, Alice!"

      # Function calls in interpolation
      iex> result = A2UI.Functions.string_format("Time: ${now()}", %{}, nil)
      iex> String.starts_with?(result, "Time: 20")
      true
  """

  alias A2UI.Binding

  # ============================================
  # Unified Function Dispatch
  # ============================================

  @doc """
  Executes a standard catalog function call.

  Returns `nil` for unknown functions.
  """
  @spec call(String.t(), map() | list(), map(), String.t() | nil, keyword()) :: term()
  def call(name, args, data_model, scope_path, opts \\ []) when is_binary(name) do
    case name do
      "required" ->
        required(arg_from(args, "value", 0))

      "email" ->
        email(arg_from(args, "value", 0))

      "regex" ->
        regex(arg_from(args, "value", 0), arg_from(args, "pattern", 1))

      "length" ->
        {value, opts} = min_max_args(args)
        length(value, opts)

      "numeric" ->
        {value, opts} = min_max_args(args)
        numeric(value, opts)

      "string_format" ->
        template = arg_from(args, "value", 0) || arg_from(args, "template", 1)
        version = Keyword.get(opts, :version, :v0_8)
        string_format(template, data_model, scope_path, version: version)

      "now" ->
        DateTime.utc_now() |> DateTime.to_iso8601()

      _name ->
        nil
    end
  end

  # ============================================
  # Validation Functions
  # ============================================

  @doc """
  Checks that the value is not null, undefined, or empty.

  Returns `true` if the value is present and non-empty.

  ## Examples

      iex> A2UI.Functions.required("hello")
      true

      iex> A2UI.Functions.required("")
      false

      iex> A2UI.Functions.required(nil)
      false

      iex> A2UI.Functions.required([])
      false

      iex> A2UI.Functions.required(0)
      true
  """
  @spec required(term()) :: boolean()
  def required(nil), do: false
  def required(""), do: false
  def required([]), do: false
  def required(%{} = map) when map_size(map) == 0, do: false
  # For checkboxes: false means unchecked, which fails required
  def required(false), do: false
  def required(_), do: true

  @doc """
  Checks that the value matches a regular expression pattern.

  Returns `true` if the value matches the pattern.

  ## Examples

      iex> A2UI.Functions.regex("hello123", "^[a-z]+\\\\d+$")
      true

      iex> A2UI.Functions.regex("hello", "^\\\\d+$")
      false

      iex> A2UI.Functions.regex(nil, ".*")
      false
  """
  @spec regex(term(), String.t()) :: boolean()
  def regex(nil, _pattern), do: false

  def regex(value, pattern) when is_binary(value) and is_binary(pattern) do
    case Regex.compile(pattern) do
      {:ok, regex} -> Regex.match?(regex, value)
      {:error, _} -> false
    end
  end

  def regex(value, pattern) when is_binary(pattern) do
    regex(to_string(value), pattern)
  end

  def regex(_, _), do: false

  @doc """
  Checks string length constraints.

  Returns `true` if the string length is within the specified bounds.
  At least one of `min` or `max` should be provided in opts.

  ## Options

  - `:min` - minimum allowed length (inclusive)
  - `:max` - maximum allowed length (inclusive)

  ## Examples

      iex> A2UI.Functions.length("hello", min: 3)
      true

      iex> A2UI.Functions.length("hi", min: 3)
      false

      iex> A2UI.Functions.length("hello", max: 10)
      true

      iex> A2UI.Functions.length("hello world", max: 5)
      false

      iex> A2UI.Functions.length("hello", min: 3, max: 10)
      true
  """
  @spec length(term(), keyword()) :: boolean()
  def length(nil, _opts), do: false

  def length(value, opts) when is_binary(value) do
    len = String.length(value)
    min = Keyword.get(opts, :min)
    max = Keyword.get(opts, :max)

    min_ok = is_nil(min) or len >= min
    max_ok = is_nil(max) or len <= max

    min_ok and max_ok
  end

  def length(value, opts) when is_list(value) do
    len = Kernel.length(value)
    min = Keyword.get(opts, :min)
    max = Keyword.get(opts, :max)

    min_ok = is_nil(min) or len >= min
    max_ok = is_nil(max) or len <= max

    min_ok and max_ok
  end

  def length(_, _), do: false

  @doc """
  Checks numeric range constraints.

  Returns `true` if the number is within the specified bounds.
  At least one of `min` or `max` should be provided in opts.

  ## Options

  - `:min` - minimum allowed value (inclusive)
  - `:max` - maximum allowed value (inclusive)

  ## Examples

      iex> A2UI.Functions.numeric(5, min: 0)
      true

      iex> A2UI.Functions.numeric(-1, min: 0)
      false

      iex> A2UI.Functions.numeric(5, max: 10)
      true

      iex> A2UI.Functions.numeric(15, max: 10)
      false

      iex> A2UI.Functions.numeric(5, min: 0, max: 10)
      true
  """
  @spec numeric(term(), keyword()) :: boolean()
  def numeric(nil, _opts), do: false

  def numeric(value, opts) when is_number(value) do
    min = Keyword.get(opts, :min)
    max = Keyword.get(opts, :max)

    min_ok = is_nil(min) or value >= min
    max_ok = is_nil(max) or value <= max

    min_ok and max_ok
  end

  def numeric(value, opts) when is_binary(value) do
    case parse_number(value) do
      {:ok, num} -> numeric(num, opts)
      :error -> false
    end
  end

  def numeric(_, _), do: false

  @doc """
  Checks that the value is a valid email address.

  Uses a simple but practical regex that covers most valid email formats.

  ## Examples

      iex> A2UI.Functions.email("test@example.com")
      true

      iex> A2UI.Functions.email("user.name+tag@domain.co.uk")
      true

      iex> A2UI.Functions.email("invalid")
      false

      iex> A2UI.Functions.email("@nodomain.com")
      false

      iex> A2UI.Functions.email(nil)
      false
  """
  @spec email(term()) :: boolean()
  def email(nil), do: false

  def email(value) when is_binary(value) do
    # Simple but practical email regex
    # Covers: local-part@domain with common characters
    email_regex =
      ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/

    Regex.match?(email_regex, value)
  end

  def email(_), do: false

  # ============================================
  # String Interpolation
  # ============================================

  @doc """
  Performs string interpolation with `${expression}` syntax.

  Supported expression types:
  - JSON Pointer paths: `${/absolute/path}` or `${relative/path}`
  - Function calls: `${functionName(arg1, arg2)}`
  - Escaped literals: `\\${` produces literal `${`

  ## Parameters

  - `template` - the string template with `${...}` expressions
  - `data_model` - the data model map for path resolution
  - `scope_path` - optional scope path for relative path resolution

  ## Options

  - `:version` - protocol version (`:v0_8` or `:v0_9`) for path scoping rules

  ## Examples

      iex> A2UI.Functions.string_format("Hello, ${/name}!", %{"name" => "Alice"}, nil)
      "Hello, Alice!"

      iex> A2UI.Functions.string_format("Value: ${value}", %{"items" => [%{"value" => 42}]}, "/items/0")
      "Value: 42"

      iex> A2UI.Functions.string_format("Escaped: \\\\${not_interpolated}", %{}, nil)
      "Escaped: ${not_interpolated}"
  """
  @spec string_format(String.t(), map(), String.t() | nil, keyword()) :: String.t()
  def string_format(template, data_model, scope_path, opts \\ [])

  def string_format(nil, _data_model, _scope_path, _opts), do: ""
  def string_format("", _data_model, _scope_path, _opts), do: ""

  def string_format(template, data_model, scope_path, opts) when is_binary(template) do
    version = Keyword.get(opts, :version, :v0_8)

    template
    |> interpolate_expressions(data_model, scope_path, version)
  end

  # ============================================
  # Private Helpers
  # ============================================

  defp parse_number(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, ""} ->
        {:ok, int}

      _ ->
        case Float.parse(str) do
          {float, ""} -> {:ok, float}
          _ -> :error
        end
    end
  end

  # Interpolation implementation
  # Handles: ${expr}, \${ (escaped)
  defp interpolate_expressions(template, data_model, scope_path, version) do
    # Process the template character by character to handle escapes and nesting
    {result, _} = interpolate_scan(template, data_model, scope_path, version, [])
    IO.iodata_to_binary(result)
  end

  defp interpolate_scan("", _data, _scope, _version, acc) do
    {Enum.reverse(acc), ""}
  end

  # Escaped ${ - output literal ${
  defp interpolate_scan("\\${" <> rest, data, scope, version, acc) do
    interpolate_scan(rest, data, scope, version, ["${" | acc])
  end

  # Start of expression
  defp interpolate_scan("${" <> rest, data, scope, version, acc) do
    case extract_expression(rest, 0, []) do
      {:ok, expr, remaining} ->
        resolved = resolve_expression(expr, data, scope, version)
        interpolate_scan(remaining, data, scope, version, [to_string_value(resolved) | acc])

      :error ->
        # Malformed expression, output as literal
        interpolate_scan(rest, data, scope, version, ["${" | acc])
    end
  end

  # Regular character
  defp interpolate_scan(<<char::utf8, rest::binary>>, data, scope, version, acc) do
    interpolate_scan(rest, data, scope, version, [<<char::utf8>> | acc])
  end

  # Extract expression content, handling nested ${...} and quoted strings
  # State includes: depth (nesting level), quote_char (nil or ?' or ?")
  defp extract_expression(str, depth, acc) do
    extract_expression(str, depth, acc, nil)
  end

  # Closing brace at depth 0 (not in quotes) - expression complete
  defp extract_expression("}" <> rest, 0, acc, nil) do
    {:ok, IO.iodata_to_binary(Enum.reverse(acc)), rest}
  end

  # Closing brace at depth > 0 (not in quotes) - decrease depth
  defp extract_expression("}" <> rest, depth, acc, nil) when depth > 0 do
    extract_expression(rest, depth - 1, ["}" | acc], nil)
  end

  # Nested ${ (not in quotes) - increase depth
  defp extract_expression("${" <> rest, depth, acc, nil) do
    extract_expression(rest, depth + 1, ["${" | acc], nil)
  end

  # Start of single-quoted string (not already in quotes)
  defp extract_expression("'" <> rest, depth, acc, nil) do
    extract_expression(rest, depth, ["'" | acc], ?')
  end

  # Start of double-quoted string (not already in quotes)
  defp extract_expression("\"" <> rest, depth, acc, nil) do
    extract_expression(rest, depth, ["\"" | acc], ?")
  end

  # Escaped single quote inside single-quoted string
  defp extract_expression("\\'" <> rest, depth, acc, ?') do
    extract_expression(rest, depth, ["\\'" | acc], ?')
  end

  # Escaped double quote inside double-quoted string
  defp extract_expression("\\\"" <> rest, depth, acc, ?") do
    extract_expression(rest, depth, ["\\\"" | acc], ?")
  end

  # End of single-quoted string
  defp extract_expression("'" <> rest, depth, acc, ?') do
    extract_expression(rest, depth, ["'" | acc], nil)
  end

  # End of double-quoted string
  defp extract_expression("\"" <> rest, depth, acc, ?") do
    extract_expression(rest, depth, ["\"" | acc], nil)
  end

  # Any character inside quoted string - consume without special handling
  defp extract_expression(<<char::utf8, rest::binary>>, depth, acc, quote_char)
       when not is_nil(quote_char) do
    extract_expression(rest, depth, [<<char::utf8>> | acc], quote_char)
  end

  # Any other character outside quotes
  defp extract_expression(<<char::utf8, rest::binary>>, depth, acc, nil) do
    extract_expression(rest, depth, [<<char::utf8>> | acc], nil)
  end

  # Empty string - unclosed expression
  defp extract_expression("", _depth, _acc, _quote_char) do
    :error
  end

  # Resolve an expression: path or function call
  defp resolve_expression(expr, data, scope, version) do
    expr = String.trim(expr)

    cond do
      # Function call: name(args)
      String.contains?(expr, "(") and String.ends_with?(expr, ")") ->
        resolve_function_call(expr, data, scope, version)

      # Path reference
      true ->
        Binding.resolve_path(expr, data, scope, version: version)
    end
  end

  # Parse and execute a function call
  defp resolve_function_call(expr, data, scope, version) do
    case parse_function_call(expr) do
      {:ok, func_name, args} ->
        resolved_args = Enum.map(args, &resolve_arg(&1, data, scope, version))
        call(func_name, resolved_args, data, scope, version: version)

      :error ->
        nil
    end
  end

  # Parse function call: "name(arg1, arg2)" -> {:ok, "name", ["arg1", "arg2"]}
  defp parse_function_call(expr) do
    case Regex.run(~r/^([a-zA-Z_][a-zA-Z0-9_]*)\((.*)\)$/s, expr) do
      [_, name, args_str] ->
        args = parse_arguments(args_str)
        {:ok, name, args}

      _ ->
        :error
    end
  end

  # Parse comma-separated arguments, handling nested parens and quotes
  defp parse_arguments(""), do: []

  defp parse_arguments(str) do
    str
    |> String.trim()
    |> split_arguments([], [], 0, nil)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_arguments("", current, args, _paren_depth, _quote_char) do
    Enum.reverse([IO.iodata_to_binary(Enum.reverse(current)) | args])
  end

  # Handle quoted strings
  defp split_arguments(<<"'", rest::binary>>, current, args, depth, nil) do
    split_arguments(rest, ["'" | current], args, depth, ?')
  end

  defp split_arguments(<<"\"", rest::binary>>, current, args, depth, nil) do
    split_arguments(rest, ["\"" | current], args, depth, ?")
  end

  defp split_arguments(<<"'", rest::binary>>, current, args, depth, ?') do
    split_arguments(rest, ["'" | current], args, depth, nil)
  end

  defp split_arguments(<<"\"", rest::binary>>, current, args, depth, ?") do
    split_arguments(rest, ["\"" | current], args, depth, nil)
  end

  # Handle escaped quotes inside strings
  defp split_arguments(<<"\\'", rest::binary>>, current, args, depth, quote_char) do
    split_arguments(rest, ["\\'" | current], args, depth, quote_char)
  end

  defp split_arguments(<<"\\\"", rest::binary>>, current, args, depth, quote_char) do
    split_arguments(rest, ["\\\"" | current], args, depth, quote_char)
  end

  # Inside quoted string - consume everything
  defp split_arguments(<<char::utf8, rest::binary>>, current, args, depth, quote_char)
       when not is_nil(quote_char) do
    split_arguments(rest, [<<char::utf8>> | current], args, depth, quote_char)
  end

  # Handle parentheses for nested function calls
  defp split_arguments(<<"(", rest::binary>>, current, args, depth, nil) do
    split_arguments(rest, ["(" | current], args, depth + 1, nil)
  end

  defp split_arguments(<<")", rest::binary>>, current, args, depth, nil) when depth > 0 do
    split_arguments(rest, [")" | current], args, depth - 1, nil)
  end

  # Comma at top level splits arguments
  defp split_arguments(<<",", rest::binary>>, current, args, 0, nil) do
    arg = IO.iodata_to_binary(Enum.reverse(current))
    split_arguments(rest, [], [arg | args], 0, nil)
  end

  # Regular character
  defp split_arguments(<<char::utf8, rest::binary>>, current, args, depth, quote_char) do
    split_arguments(rest, [<<char::utf8>> | current], args, depth, quote_char)
  end

  # Resolve a function argument (can be literal, path, or nested expression)
  defp resolve_arg(arg, data, scope, version) do
    arg = String.trim(arg)

    cond do
      # Nested expression ${...}
      String.starts_with?(arg, "${") and String.ends_with?(arg, "}") ->
        inner = String.slice(arg, 2..-2//1)
        resolve_expression(inner, data, scope, version)

      # Quoted string literal
      (String.starts_with?(arg, "'") and String.ends_with?(arg, "'")) or
          (String.starts_with?(arg, "\"") and String.ends_with?(arg, "\"")) ->
        String.slice(arg, 1..-2//1)

      # Boolean literals
      arg == "true" ->
        true

      arg == "false" ->
        false

      # Null literal
      arg == "null" ->
        nil

      # Number literal
      true ->
        case parse_number(arg) do
          {:ok, num} -> num
          # Return as-is (possibly a bare path reference)
          :error -> arg
        end
    end
  end

  defp arg_from(args, key, _index) when is_map(args), do: Map.get(args, key)
  defp arg_from(args, _key, index) when is_list(args), do: Enum.at(args, index)
  defp arg_from(_args, _key, _index), do: nil

  defp min_max_args(args) when is_map(args) do
    value = Map.get(args, "value")
    opts = min_max_opts(Map.get(args, "min"), Map.get(args, "max"))
    {value, opts}
  end

  defp min_max_args(args) when is_list(args) do
    value = Enum.at(args, 0)

    opts =
      case args do
        [_value, min, max] -> min_max_opts(min, max)
        [_value, constraint] when is_number(constraint) -> min_max_opts(constraint, nil)
        [_value] -> []
        _ -> []
      end

    {value, opts}
  end

  defp min_max_args(_args), do: {nil, []}

  defp min_max_opts(nil, nil), do: []
  defp min_max_opts(min, nil), do: [{:min, min}]
  defp min_max_opts(nil, max), do: [{:max, max}]
  defp min_max_opts(min, max), do: [{:min, min}, {:max, max}]

  # Convert value to string for interpolation output
  defp to_string_value(nil), do: ""
  defp to_string_value(true), do: "true"
  defp to_string_value(false), do: "false"
  defp to_string_value(value) when is_binary(value), do: value
  defp to_string_value(value) when is_integer(value), do: Integer.to_string(value)
  defp to_string_value(value) when is_float(value), do: Float.to_string(value)
  defp to_string_value(value) when is_list(value), do: Jason.encode!(value)
  defp to_string_value(value) when is_map(value), do: Jason.encode!(value)
  defp to_string_value(value), do: inspect(value)
end
