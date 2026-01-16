defmodule A2UI.SSE.Event do
  @moduledoc """
  SSE (Server-Sent Events) event parsing for A2UI transport.

  This module parses the SSE wire format into A2UI-compatible structures.
  Each SSE event contains a single A2UI envelope in its `data:` field.

  ## SSE Wire Format

  SSE events are text-based with the following structure:

      id: event-123
      retry: 2000
      data: {"surfaceUpdate":{"surfaceId":"main","components":[...]}}

  - `data:` - Required. Contains the A2UI envelope as JSON.
  - `id:` - Optional. Event ID for reconnection.
  - `retry:` - Optional. Suggested reconnect delay in milliseconds.
  - Events are separated by blank lines.

  ## Multi-line Data

  SSE allows multi-line data by using multiple `data:` lines:

      data: {"surfaceUpdate":
      data:   {"surfaceId":"main","components":[]}}

  These are concatenated with newlines before parsing.

  ## Usage

      # Parse a complete SSE event
      event_text = "id: 1\\ndata: {\\"beginRendering\\":{\\"surfaceId\\":\\"main\\",\\"root\\":\\"root\\"}}\\n\\n"
      {:ok, event} = A2UI.SSE.Event.parse(event_text)
      event.data  # => "{\\"beginRendering\\":...}"
      event.id    # => "1"

      # Parse streaming data (returns events + remaining buffer)
      {events, buffer} = A2UI.SSE.Event.parse_stream(buffer <> new_chunk)
  """

  defstruct [:data, :id, :retry, :event_type]

  @typedoc """
  Parsed SSE event.

  - `:data` - The `data:` field content (concatenated if multi-line)
  - `:id` - Optional event ID from `id:` field
  - `:retry` - Optional retry interval in ms from `retry:` field
  - `:event_type` - Optional event type from `event:` field (rarely used in A2UI)
  """
  @type t :: %__MODULE__{
          data: String.t() | nil,
          id: String.t() | nil,
          retry: pos_integer() | nil,
          event_type: String.t() | nil
        }

  @doc """
  Parses a single SSE event text block.

  The input should be a complete event (fields followed by blank line).
  Use `parse_stream/1` for partial/streaming data.

  ## Parameters

  - `event_text` - Complete SSE event text

  ## Returns

  - `{:ok, event}` - Successfully parsed event
  - `{:error, :empty_event}` - No data in the event
  - `{:error, :incomplete}` - Event text is incomplete

  ## Examples

      iex> A2UI.SSE.Event.parse("data: {\\"test\\":1}\\n\\n")
      {:ok, %A2UI.SSE.Event{data: "{\\"test\\":1}", id: nil, retry: nil}}

      iex> A2UI.SSE.Event.parse("id: 42\\nretry: 3000\\ndata: {}\\n\\n")
      {:ok, %A2UI.SSE.Event{data: "{}", id: "42", retry: 3000}}

      iex> A2UI.SSE.Event.parse("")
      {:error, :empty_event}
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, atom()}
  def parse(event_text) when is_binary(event_text) do
    lines =
      event_text
      |> String.split("\n")
      |> Enum.reject(&(&1 == ""))

    if Enum.empty?(lines) do
      {:error, :empty_event}
    else
      event = parse_lines(lines, %__MODULE__{})

      if event.data do
        {:ok, event}
      else
        {:error, :empty_event}
      end
    end
  end

  @doc """
  Parses streaming SSE data, returning complete events and remaining buffer.

  SSE events are separated by double newlines (`\\n\\n`). This function
  parses all complete events from the input and returns any incomplete
  data as a buffer for the next chunk.

  ## Parameters

  - `data` - Chunk of SSE data (may be partial)

  ## Returns

  `{events, remaining_buffer}` where:
  - `events` - List of parsed `%A2UI.SSE.Event{}` structs
  - `remaining_buffer` - Incomplete event data to prepend to next chunk

  ## Example

      # Simulating chunked data
      chunk1 = "id: 1\\ndata: {\\"a\\":1}\\n\\nid: 2\\nda"
      {events1, buffer} = A2UI.SSE.Event.parse_stream(chunk1)
      # events1 = [%Event{data: "{\\"a\\":1}", id: "1"}]
      # buffer = "id: 2\\nda"

      chunk2 = "ta: {\\"b\\":2}\\n\\n"
      {events2, buffer} = A2UI.SSE.Event.parse_stream(buffer <> chunk2)
      # events2 = [%Event{data: "{\\"b\\":2}", id: "2"}]
      # buffer = ""
  """
  @spec parse_stream(String.t()) :: {[t()], String.t()}
  def parse_stream(data) when is_binary(data) do
    # Split on double newlines (event boundaries)
    # Handle both \n\n and \r\n\r\n
    parts = String.split(data, ~r/\r?\n\r?\n/)

    case parts do
      # Only one part means no complete events yet
      [incomplete] ->
        {[], incomplete}

      # Last part is potentially incomplete
      parts ->
        {complete, [maybe_incomplete]} = Enum.split(parts, -1)

        events =
          complete
          |> Enum.map(&parse/1)
          |> Enum.filter(&match?({:ok, _}, &1))
          |> Enum.map(fn {:ok, event} -> event end)

        {events, maybe_incomplete}
    end
  end

  @doc """
  Extracts the A2UI JSON payload from a parsed event.

  This is a convenience function that returns just the data field,
  ready for `A2UI.Session.apply_json_line/2`.

  ## Parameters

  - `event` - Parsed SSE event

  ## Returns

  - `{:ok, json_line}` - The JSON string from the data field
  - `{:error, :no_data}` - Event has no data field

  ## Example

      {:ok, event} = A2UI.SSE.Event.parse("data: {\\"test\\":1}\\n\\n")
      {:ok, json_line} = A2UI.SSE.Event.extract_payload(event)
      {:ok, session} = A2UI.Session.apply_json_line(session, json_line)
  """
  @spec extract_payload(t()) :: {:ok, String.t()} | {:error, :no_data}
  def extract_payload(%__MODULE__{data: nil}), do: {:error, :no_data}
  def extract_payload(%__MODULE__{data: data}), do: {:ok, data}

  @doc """
  Formats an A2UI envelope as an SSE event for sending.

  This is useful for server-side SSE producers.

  ## Parameters

  - `envelope` - A2UI envelope (map) or JSON string
  - `opts` - Options:
    - `:id` - Event ID
    - `:retry` - Retry interval in ms

  ## Returns

  SSE-formatted event string ready for streaming.

  ## Example

      iex> envelope = %{"beginRendering" => %{"surfaceId" => "main", "root" => "root"}}
      iex> A2UI.SSE.Event.format(envelope)
      "data: {\\"beginRendering\\":{\\"root\\":\\"root\\",\\"surfaceId\\":\\"main\\"}}\\n\\n"

      iex> A2UI.SSE.Event.format(envelope, id: "42", retry: 5000)
      "id: 42\\nretry: 5000\\ndata: {\\"beginRendering\\":{\\"root\\":\\"root\\",\\"surfaceId\\":\\"main\\"}}\\n\\n"
  """
  @spec format(map() | String.t(), keyword()) :: String.t()
  def format(envelope, opts \\ [])

  def format(envelope, opts) when is_map(envelope) do
    format(Jason.encode!(envelope), opts)
  end

  def format(json, opts) when is_binary(json) do
    parts = []

    parts =
      case Keyword.get(opts, :id) do
        nil -> parts
        id -> parts ++ ["id: #{id}"]
      end

    parts =
      case Keyword.get(opts, :retry) do
        nil -> parts
        retry -> parts ++ ["retry: #{retry}"]
      end

    # Handle multi-line JSON by splitting into multiple data: lines
    data_lines =
      json
      |> String.split("\n")
      |> Enum.map(&"data: #{&1}")

    parts = parts ++ data_lines

    Enum.join(parts, "\n") <> "\n\n"
  end

  # ============================================
  # Private Helpers
  # ============================================

  defp parse_lines([], event), do: event

  defp parse_lines([line | rest], event) do
    event = parse_line(line, event)
    parse_lines(rest, event)
  end

  defp parse_line("data:" <> value, event) do
    value = String.trim_leading(value, " ")

    data =
      case event.data do
        nil -> value
        existing -> existing <> "\n" <> value
      end

    %{event | data: data}
  end

  defp parse_line("id:" <> value, event) do
    %{event | id: String.trim(value)}
  end

  defp parse_line("retry:" <> value, event) do
    case Integer.parse(String.trim(value)) do
      {retry, ""} -> %{event | retry: retry}
      _ -> event
    end
  end

  defp parse_line("event:" <> value, event) do
    %{event | event_type: String.trim(value)}
  end

  # Ignore comments and unknown fields
  defp parse_line(":" <> _comment, event), do: event
  defp parse_line(_unknown, event), do: event
end
