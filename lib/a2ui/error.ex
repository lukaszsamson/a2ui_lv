defmodule A2UI.Error do
  @moduledoc """
  Constructs A2UI client→server error messages per v0.8 spec.

  From `client_to_server.json`:
  - Error content is flexible (`additionalProperties: true`)
  - No mandatory fields required
  - Must be sent for: binding failures, unknown components, render errors

  This module provides a consistent internal structure while remaining
  spec-compliant.
  """

  @type error_type ::
          :parse_error
          | :validation_error
          | :binding_error
          | :render_error
          | :unknown_component

  @doc """
  Builds an A2UI error message.

  ## Options

  - `:surface_id` - Surface where error occurred
  - `:component_id` - Component that caused the error
  - `:details` - Additional context map

  ## Examples

      iex> A2UI.Error.build(:parse_error, "JSON decode failed")
      %{"error" => %{"type" => "parse_error", "message" => "JSON decode failed", "timestamp" => "..."}}

      iex> A2UI.Error.build(:unknown_component, "Unknown type: Foo", surface_id: "main")
      %{"error" => %{"type" => "unknown_component", "message" => "Unknown type: Foo", "surfaceId" => "main", "timestamp" => "..."}}
  """
  @spec build(error_type(), String.t(), keyword()) :: map()
  def build(type, message, opts \\ []) do
    %{
      "error" =>
        %{
          "type" => to_string(type),
          "message" => message,
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
        |> maybe_put("surfaceId", opts[:surface_id])
        |> maybe_put("componentId", opts[:component_id])
        |> maybe_put("details", opts[:details])
    }
  end

  @doc """
  Builds a parse error for JSON decode failures.
  """
  @spec parse_error(String.t(), term()) :: map()
  def parse_error(message, reason \\ nil) do
    opts =
      if reason do
        [details: %{"reason" => format_reason(reason)}]
      else
        []
      end

    build(:parse_error, message, opts)
  end

  @doc """
  Builds a validation error.
  """
  @spec validation_error(String.t(), String.t() | nil, map() | nil) :: map()
  def validation_error(message, surface_id \\ nil, details \\ nil) do
    opts =
      []
      |> maybe_add(:surface_id, surface_id)
      |> maybe_add(:details, details)

    build(:validation_error, message, opts)
  end

  @doc """
  Builds an unknown component error.
  """
  @spec unknown_component(list(String.t()), String.t() | nil) :: map()
  def unknown_component(types, surface_id \\ nil) when is_list(types) do
    message = "Unknown component types: #{Enum.join(types, ", ")}"

    opts =
      [details: %{"types" => types}]
      |> maybe_add(:surface_id, surface_id)

    build(:unknown_component, message, opts)
  end

  # Private helpers

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end
