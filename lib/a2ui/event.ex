defmodule A2UI.Event do
  @moduledoc """
  Version-aware client→server event envelope builders.

  Per the A2UI protocol:
  - v0.8: Uses `userAction` envelope key
  - v0.9: Uses `action` envelope key (same internal structure)

  Both versions use `error` for error envelopes, but v0.9 introduces
  structured error codes like `VALIDATION_FAILED` with a `path` field.

  ## Usage

      # Build an action event (version-aware)
      event = A2UI.Event.build_action(:v0_9,
        name: "submit",
        surface_id: "main",
        component_id: "btn1",
        context: %{"formData" => %{}}
      )
      #=> %{"action" => %{...}}

      # Build a v0.8 userAction
      event = A2UI.Event.build_action(:v0_8, ...)
      #=> %{"userAction" => %{...}}

      # Build a VALIDATION_FAILED error (v0.9)
      error = A2UI.Event.validation_failed("main", "/email", "Invalid email format")
      #=> %{"error" => %{"code" => "VALIDATION_FAILED", ...}}
  """

  @type protocol_version :: A2UI.Protocol.version()

  # ============================================
  # Action Events
  # ============================================

  @doc """
  Builds an action event envelope with version-aware key.

  In v0.8, the envelope uses `userAction`. In v0.9, it uses `action`.
  The internal structure is identical.

  ## Options

  - `:name` - Action name (required)
  - `:surface_id` - Surface ID (required)
  - `:component_id` - Source component ID (required)
  - `:context` - Resolved context map (default: `%{}`)
  - `:timestamp` - ISO 8601 timestamp (default: current UTC time)

  ## Examples

      iex> A2UI.Event.build_action(:v0_9, name: "click", surface_id: "main", component_id: "btn1")
      %{"action" => %{"name" => "click", "surfaceId" => "main", ...}}

      iex> A2UI.Event.build_action(:v0_8, name: "click", surface_id: "main", component_id: "btn1")
      %{"userAction" => %{"name" => "click", "surfaceId" => "main", ...}}
  """
  @spec build_action(protocol_version(), keyword()) :: map()
  def build_action(version, opts) do
    name = Keyword.fetch!(opts, :name)
    surface_id = Keyword.fetch!(opts, :surface_id)
    component_id = Keyword.fetch!(opts, :component_id)
    context = Keyword.get(opts, :context, %{})
    timestamp = Keyword.get(opts, :timestamp, DateTime.utc_now() |> DateTime.to_iso8601())

    payload = %{
      "name" => name,
      "surfaceId" => surface_id,
      "sourceComponentId" => component_id,
      "timestamp" => timestamp,
      "context" => context
    }

    envelope_key = action_envelope_key(version)
    %{envelope_key => payload}
  end

  @doc """
  Returns the envelope key for action events based on protocol version.

  - v0.8: `"userAction"`
  - v0.9: `"action"`
  """
  @spec action_envelope_key(protocol_version()) :: String.t()
  def action_envelope_key(version), do: A2UI.Protocol.client_action_envelope_key(version)

  # ============================================
  # Error Events (v0.9)
  # ============================================

  @doc """
  Builds a VALIDATION_FAILED error envelope (v0.9 format).

  Per v0.9 `client_to_server.json`, validation errors have:
  - `code`: `"VALIDATION_FAILED"` (constant)
  - `surfaceId`: The surface where validation failed
  - `path`: JSON Pointer to the field that failed (e.g., `/email`)
  - `message`: Human-readable error description

  ## Examples

      iex> A2UI.Event.validation_failed("main", "/email", "Invalid email format")
      %{"error" => %{
        "code" => "VALIDATION_FAILED",
        "surfaceId" => "main",
        "path" => "/email",
        "message" => "Invalid email format"
      }}
  """
  @spec validation_failed(String.t(), String.t(), String.t()) :: map()
  def validation_failed(surface_id, path, message) do
    %{
      "error" => %{
        "code" => "VALIDATION_FAILED",
        "surfaceId" => surface_id,
        "path" => path,
        "message" => message
      }
    }
  end

  @doc """
  Builds a generic error envelope (v0.9 format).

  Per v0.9 `client_to_server.json`, generic errors have:
  - `code`: Any string except `"VALIDATION_FAILED"`
  - `surfaceId`: The surface where the error occurred
  - `message`: Human-readable error description
  - Additional properties allowed

  ## Options

  - `:details` - Additional details map to merge into the error

  ## Examples

      iex> A2UI.Event.generic_error("RENDER_ERROR", "main", "Failed to render component")
      %{"error" => %{"code" => "RENDER_ERROR", "surfaceId" => "main", "message" => "..."}}

      iex> A2UI.Event.generic_error("PARSE_ERROR", "main", "Invalid JSON", details: %{"line" => 5})
      %{"error" => %{"code" => "PARSE_ERROR", ..., "line" => 5}}
  """
  @spec generic_error(String.t(), String.t(), String.t(), keyword()) :: map()
  def generic_error(code, surface_id, message, opts \\ []) do
    base = %{
      "code" => code,
      "surfaceId" => surface_id,
      "message" => message
    }

    error =
      case Keyword.get(opts, :details) do
        nil -> base
        details when is_map(details) -> Map.merge(base, details)
        _ -> base
      end

    %{"error" => error}
  end

  # ============================================
  # Version Detection
  # ============================================

  @doc """
  Detects the protocol version from an incoming client→server event envelope.

  - Returns `:v0_9` if the envelope has an `"action"` key
  - Returns `:v0_8` if the envelope has a `"userAction"` key
  - Returns `:unknown` for `"error"` (errors are version-agnostic at envelope level)
  - Returns `:unknown` for unrecognized envelopes
  """
  @spec detect_version(map()) :: protocol_version() | :unknown
  def detect_version(decoded), do: A2UI.Protocol.detect_client_version(decoded)

  @doc """
  Returns the envelope type for a client→server event.

  Works with both v0.8 and v0.9 envelope formats.
  """
  @spec envelope_type(map()) :: :action | :error | :unknown
  def envelope_type(%{"action" => _}), do: :action
  def envelope_type(%{"userAction" => _}), do: :action
  def envelope_type(%{"error" => _}), do: :error
  def envelope_type(_), do: :unknown
end
