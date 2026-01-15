defmodule A2UI.Transport.Events do
  @moduledoc """
  Behaviour for client→server event envelope delivery.

  Per the A2UI v0.8 protocol (section 5), clients send single-event envelopes
  where the payload has exactly one top-level key: `userAction` or `error`.
  This behaviour abstracts the transport layer from the event sending logic.

  ## Event Envelope Format

  Per `client_to_server.json`, event envelopes must have exactly one of:

  ### userAction

      %{
        "userAction" => %{
          "name" => "submit_form",
          "surfaceId" => "main",
          "sourceComponentId" => "submit_btn",
          "timestamp" => "2024-01-15T10:30:00Z",
          "context" => %{"formData" => %{...}}
        }
      }

  ### error

      %{
        "error" => %{
          "type" => "validation_error",
          "message" => "Invalid component configuration",
          "surfaceId" => "main",
          "timestamp" => "2024-01-15T10:30:00Z",
          "details" => %{...}
        }
      }

  ## Example Implementation

      defmodule MyApp.RESTEventTransport do
        @behaviour A2UI.Transport.Events

        use GenServer

        @impl true
        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts)
        end

        @impl true
        def send_event(pid, event_envelope, opts) do
          GenServer.call(pid, {:send_event, event_envelope, opts})
        end

        # GenServer callbacks that POST to REST endpoint...
      end

  ## Transport Wrapping

  Implementations are free to wrap the event envelope as needed:

  - **A2A**: Wrap in an A2A message with `metadata.a2uiClientCapabilities`
  - **REST**: POST raw `event_envelope` to an endpoint
  - **WebSocket**: Send `event_envelope` as a JSON frame

  ## Usage

      # Send a userAction event
      event = %{
        "userAction" => %{
          "name" => "increment",
          "surfaceId" => "counter",
          "sourceComponentId" => "inc_btn",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "context" => %{}
        }
      }

      :ok = MyApp.RESTEventTransport.send_event(transport_pid, event, [])

      # Send an error event
      error = A2UI.Error.validation_error("Invalid input", "form-surface")
      :ok = MyApp.RESTEventTransport.send_event(transport_pid, error, [])
  """

  @typedoc """
  Options passed to transport operations.

  Common options include:
  - `:timeout` - Operation timeout in milliseconds
  - `:headers` - HTTP headers for REST transports
  - `:async` - If true, don't wait for acknowledgment
  """
  @type opts :: keyword()

  @typedoc """
  Event envelope containing either a userAction or error.

  Must have exactly one top-level key: `"userAction"` or `"error"`.
  """
  @type event_envelope :: %{String.t() => map()}

  @doc """
  Sends an event envelope to the server.

  The envelope must contain exactly one top-level key: `"userAction"` or `"error"`.

  ## Parameters

  - `pid` - The transport process
  - `event_envelope` - The event to send
  - `opts` - Transport-specific options

  ## Returns

  - `:ok` - Event sent successfully
  - `{:error, reason}` - Failed to send event

  ## Options

  - `:timeout` - Maximum time to wait for acknowledgment (default: 5000ms)
  - `:async` - If true, return immediately without waiting (default: false)
  """
  @callback send_event(pid :: pid(), event_envelope(), opts()) :: :ok | {:error, term()}

  # Helper functions for working with event envelopes

  @doc """
  Validates that an event envelope has the correct structure.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.

  ## Examples

      iex> A2UI.Transport.Events.validate_envelope(%{"userAction" => %{"name" => "test"}})
      :ok

      iex> A2UI.Transport.Events.validate_envelope(%{"error" => %{"type" => "parse_error"}})
      :ok

      iex> A2UI.Transport.Events.validate_envelope(%{"invalid" => %{}})
      {:error, :invalid_envelope_type}

      iex> A2UI.Transport.Events.validate_envelope(%{"userAction" => %{}, "error" => %{}})
      {:error, :multiple_envelope_keys}
  """
  @spec validate_envelope(event_envelope()) :: :ok | {:error, atom()}
  def validate_envelope(envelope) when is_map(envelope) do
    keys = Map.keys(envelope)

    cond do
      length(keys) != 1 ->
        {:error, :multiple_envelope_keys}

      "userAction" in keys ->
        :ok

      "error" in keys ->
        :ok

      true ->
        {:error, :invalid_envelope_type}
    end
  end

  def validate_envelope(_), do: {:error, :not_a_map}

  @doc """
  Returns the type of event in the envelope.

  ## Examples

      iex> A2UI.Transport.Events.envelope_type(%{"userAction" => %{}})
      :user_action

      iex> A2UI.Transport.Events.envelope_type(%{"error" => %{}})
      :error

      iex> A2UI.Transport.Events.envelope_type(%{"invalid" => %{}})
      :unknown
  """
  @spec envelope_type(event_envelope()) :: :user_action | :error | :unknown
  def envelope_type(%{"userAction" => _}), do: :user_action
  def envelope_type(%{"error" => _}), do: :error
  def envelope_type(_), do: :unknown
end
