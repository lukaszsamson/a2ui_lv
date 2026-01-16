defmodule A2UI.SSE.StreamState do
  @moduledoc """
  Tracks SSE stream state for reconnection and resumption.

  SSE supports automatic reconnection via:
  - `retry:` - Server-suggested reconnect delay
  - `Last-Event-ID` - Client header for resumption

  This module provides a state container for SSE client implementations.

  ## Usage

      # Initialize state
      state = A2UI.SSE.StreamState.new()

      # Update from parsed event
      state = A2UI.SSE.StreamState.update_from_event(state, event)

      # Get reconnect headers
      headers = A2UI.SSE.StreamState.reconnect_headers(state)

      # Get retry delay after disconnect
      delay = A2UI.SSE.StreamState.retry_delay(state)
  """

  alias A2UI.SSE.Protocol

  defstruct [
    :last_event_id,
    :retry_ms,
    :url,
    :surface_id,
    connected: false,
    buffer: "",
    messages_received: 0,
    bytes_received: 0,
    connected_at: nil,
    last_message_at: nil
  ]

  @typedoc """
  SSE stream state.

  - `:last_event_id` - Last received event ID for resumption
  - `:retry_ms` - Server-suggested retry interval
  - `:url` - Stream endpoint URL
  - `:surface_id` - A2UI surface ID this stream is for
  - `:connected` - Whether currently connected
  - `:buffer` - Partial event data awaiting completion
  - `:messages_received` - Count of complete events received
  - `:bytes_received` - Total bytes received
  - `:connected_at` - DateTime of connection
  - `:last_message_at` - DateTime of last received message
  """
  @type t :: %__MODULE__{
          last_event_id: String.t() | nil,
          retry_ms: pos_integer() | nil,
          url: String.t() | nil,
          surface_id: String.t() | nil,
          connected: boolean(),
          buffer: String.t(),
          messages_received: non_neg_integer(),
          bytes_received: non_neg_integer(),
          connected_at: DateTime.t() | nil,
          last_message_at: DateTime.t() | nil
        }

  @doc """
  Creates a new SSE stream state.

  ## Options

  - `:url` - Stream endpoint URL
  - `:surface_id` - A2UI surface ID
  - `:retry_ms` - Initial retry interval (default: 2000)

  ## Example

      iex> state = A2UI.SSE.StreamState.new(url: "http://localhost/stream", surface_id: "main")
      iex> state.url
      "http://localhost/stream"
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      url: Keyword.get(opts, :url),
      surface_id: Keyword.get(opts, :surface_id),
      retry_ms: Keyword.get(opts, :retry_ms, Protocol.default_retry_ms())
    }
  end

  @doc """
  Marks the stream as connected.

  ## Example

      iex> state = A2UI.SSE.StreamState.new() |> A2UI.SSE.StreamState.mark_connected()
      iex> state.connected
      true
  """
  @spec mark_connected(t()) :: t()
  def mark_connected(state) do
    %{state | connected: true, connected_at: DateTime.utc_now()}
  end

  @doc """
  Marks the stream as disconnected.

  Preserves `last_event_id` and `retry_ms` for reconnection.
  """
  @spec mark_disconnected(t()) :: t()
  def mark_disconnected(state) do
    %{state | connected: false, buffer: ""}
  end

  @doc """
  Updates state from a parsed SSE event.

  - Updates `last_event_id` if event has an ID
  - Updates `retry_ms` if event has a retry directive
  - Increments message counter

  ## Example

      iex> event = %A2UI.SSE.Event{id: "42", retry: 5000, data: "{}"}
      iex> state = A2UI.SSE.StreamState.new() |> A2UI.SSE.StreamState.update_from_event(event)
      iex> state.last_event_id
      "42"
      iex> state.retry_ms
      5000
  """
  @spec update_from_event(t(), A2UI.SSE.Event.t()) :: t()
  def update_from_event(state, %A2UI.SSE.Event{} = event) do
    state = %{state | messages_received: state.messages_received + 1}
    state = %{state | last_message_at: DateTime.utc_now()}

    state =
      if event.id do
        %{state | last_event_id: event.id}
      else
        state
      end

    if event.retry do
      %{state | retry_ms: event.retry}
    else
      state
    end
  end

  @doc """
  Updates the buffer with incoming chunk data.

  Returns `{events, updated_state}` where events are parsed from complete
  SSE events in the combined buffer.

  ## Example

      chunk = "data: {\\"test\\":1}\\n\\n"
      {events, state} = A2UI.SSE.StreamState.process_chunk(state, chunk)
  """
  @spec process_chunk(t(), String.t()) :: {[A2UI.SSE.Event.t()], t()}
  def process_chunk(state, chunk) when is_binary(chunk) do
    combined = state.buffer <> chunk
    {events, remaining} = A2UI.SSE.Event.parse_stream(combined)

    # Update state from each event
    state =
      Enum.reduce(events, state, fn event, acc ->
        update_from_event(acc, event)
      end)

    state = %{state | buffer: remaining}
    state = %{state | bytes_received: state.bytes_received + byte_size(chunk)}

    {events, state}
  end

  @doc """
  Returns HTTP headers for reconnection.

  Includes `Last-Event-ID` if available for resumption.

  ## Example

      iex> state = %A2UI.SSE.StreamState{last_event_id: "42"}
      iex> A2UI.SSE.StreamState.reconnect_headers(state)
      [{"accept", "text/event-stream"}, {"last-event-id", "42"}]
  """
  @spec reconnect_headers(t()) :: [{String.t(), String.t()}]
  def reconnect_headers(state) do
    Protocol.request_headers_with_resume(state.last_event_id)
  end

  @doc """
  Returns the retry delay for reconnection attempts.

  Uses server-provided retry value if available, otherwise default.

  ## Example

      iex> state = %A2UI.SSE.StreamState{retry_ms: 5000}
      iex> A2UI.SSE.StreamState.retry_delay(state)
      5000

      iex> state = %A2UI.SSE.StreamState{retry_ms: nil}
      iex> A2UI.SSE.StreamState.retry_delay(state)
      2000
  """
  @spec retry_delay(t()) :: pos_integer()
  def retry_delay(%{retry_ms: nil}), do: Protocol.default_retry_ms()
  def retry_delay(%{retry_ms: retry_ms}), do: retry_ms

  @doc """
  Returns metadata for stream completion.

  This can be used in `{:a2ui_stream_done, meta}` messages.

  ## Example

      meta = A2UI.SSE.StreamState.completion_meta(state)
      # => %{messages_received: 42, bytes_received: 1234, ...}
  """
  @spec completion_meta(t()) :: map()
  def completion_meta(state) do
    duration_ms =
      if state.connected_at do
        DateTime.diff(DateTime.utc_now(), state.connected_at, :millisecond)
      end

    %{
      messages_received: state.messages_received,
      bytes_received: state.bytes_received,
      duration_ms: duration_ms,
      last_event_id: state.last_event_id,
      surface_id: state.surface_id
    }
  end
end
