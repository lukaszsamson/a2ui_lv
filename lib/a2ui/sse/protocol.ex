defmodule A2UI.SSE.Protocol do
  @moduledoc """
  SSE (Server-Sent Events) protocol constants for A2UI transport.

  This module provides constants and helpers for SSE-based UI stream
  transport as defined in `TRANSPORT_SSE.md`.

  ## Wire Format

  SSE responses must include:
  - `Content-Type: text/event-stream`
  - `Cache-Control: no-cache`
  - `Connection: keep-alive`

  Each SSE event contains a single A2UI envelope as JSON in the `data:` field:

      data: {"surfaceUpdate":{"surfaceId":"main","components":[...]}}

      data: {"beginRendering":{"surfaceId":"main","root":"root"}}

  ## Usage

      # Build SSE response headers
      headers = A2UI.SSE.Protocol.response_headers()

      # Check content type
      if A2UI.SSE.Protocol.event_stream?(content_type) do
        # Parse as SSE
      end

  ## Version Compatibility

  SSE transport is version-agnostic - the same wire format is used for
  both v0.8 and v0.9 A2UI messages. The JSON payload determines the version.
  """

  # ============================================
  # Content Types
  # ============================================

  @content_type "text/event-stream"

  @doc """
  Returns the SSE content type.

  ## Example

      iex> A2UI.SSE.Protocol.content_type()
      "text/event-stream"
  """
  @spec content_type() :: String.t()
  def content_type, do: @content_type

  @doc """
  Checks if a content type header indicates SSE.

  Handles common variations like charset suffixes.

  ## Examples

      iex> A2UI.SSE.Protocol.event_stream?("text/event-stream")
      true

      iex> A2UI.SSE.Protocol.event_stream?("text/event-stream; charset=utf-8")
      true

      iex> A2UI.SSE.Protocol.event_stream?("application/json")
      false
  """
  @spec event_stream?(String.t() | nil) :: boolean()
  def event_stream?(nil), do: false

  def event_stream?(content_type) when is_binary(content_type) do
    content_type
    |> String.downcase()
    |> String.starts_with?(@content_type)
  end

  # ============================================
  # HTTP Headers
  # ============================================

  @doc """
  Returns the required HTTP response headers for SSE.

  These headers ensure proper SSE behavior:
  - `content-type: text/event-stream` - Required for SSE
  - `cache-control: no-cache` - Disable caching
  - `connection: keep-alive` - Maintain persistent connection

  ## Options

  - `:disable_buffering` - If true, include `x-accel-buffering: no` for nginx

  ## Example

      iex> A2UI.SSE.Protocol.response_headers()
      [
        {"content-type", "text/event-stream"},
        {"cache-control", "no-cache"},
        {"connection", "keep-alive"}
      ]

      iex> A2UI.SSE.Protocol.response_headers(disable_buffering: true)
      [
        {"content-type", "text/event-stream"},
        {"cache-control", "no-cache"},
        {"connection", "keep-alive"},
        {"x-accel-buffering", "no"}
      ]
  """
  @spec response_headers(keyword()) :: [{String.t(), String.t()}]
  def response_headers(opts \\ []) do
    base = [
      {"content-type", @content_type},
      {"cache-control", "no-cache"},
      {"connection", "keep-alive"}
    ]

    if Keyword.get(opts, :disable_buffering, false) do
      base ++ [{"x-accel-buffering", "no"}]
    else
      base
    end
  end

  @doc """
  Returns required request headers for SSE client connections.

  ## Example

      iex> A2UI.SSE.Protocol.request_headers()
      [{"accept", "text/event-stream"}]
  """
  @spec request_headers() :: [{String.t(), String.t()}]
  def request_headers do
    [{"accept", @content_type}]
  end

  @doc """
  Builds request headers with Last-Event-ID for reconnection.

  Per SSE spec, the `Last-Event-ID` header is sent on reconnect
  to allow the server to resume from a known position.

  ## Parameters

  - `last_event_id` - The ID of the last received event, or nil

  ## Example

      iex> A2UI.SSE.Protocol.request_headers_with_resume("42")
      [{"accept", "text/event-stream"}, {"last-event-id", "42"}]

      iex> A2UI.SSE.Protocol.request_headers_with_resume(nil)
      [{"accept", "text/event-stream"}]
  """
  @spec request_headers_with_resume(String.t() | nil) :: [{String.t(), String.t()}]
  def request_headers_with_resume(nil), do: request_headers()

  def request_headers_with_resume(last_event_id) when is_binary(last_event_id) do
    request_headers() ++ [{"last-event-id", last_event_id}]
  end

  # ============================================
  # Default Values
  # ============================================

  @default_retry_ms 2000

  @doc """
  Returns the default retry interval in milliseconds.

  Per TRANSPORT_SSE.md, the default retry is 2000ms.

  ## Example

      iex> A2UI.SSE.Protocol.default_retry_ms()
      2000
  """
  @spec default_retry_ms() :: pos_integer()
  def default_retry_ms, do: @default_retry_ms
end
