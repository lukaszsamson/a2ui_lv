defmodule A2UI.Transport.HTTP.SSEServer do
  @moduledoc """
  Server-side SSE (Server-Sent Events) producer for HTTP transport.

  This Plug handles SSE streaming for A2UI sessions. It subscribes to PubSub
  messages for a session and streams them to the client as SSE events.

  ## Usage

  This plug is typically used via `A2UI.Transport.HTTP.Plug`, but can be
  used directly:

      # In a router
      get "/stream" do
        A2UI.Transport.HTTP.SSEServer.call(conn, pubsub: MyApp.PubSub)
      end

  ## Query Parameters

  - `session_id` - Required. The session ID to subscribe to.

  ## SSE Format

  Messages are sent in standard SSE format:

      data: {"surfaceUpdate":{...}}

      data: {"beginRendering":{...}}

  The connection remains open until:
  - The client disconnects
  - `{:a2ui_stream_done, _}` is received
  - `{:a2ui_stream_error, _}` is received
  """

  @behaviour Plug

  import Plug.Conn
  require Logger

  alias A2UI.SSE.Event
  alias A2UI.SSE.Protocol

  @default_topic_prefix "a2ui:session:"

  @impl true
  def init(opts) do
    %{
      pubsub: Keyword.fetch!(opts, :pubsub),
      topic_prefix: Keyword.get(opts, :topic_prefix, @default_topic_prefix),
      registry: Keyword.get(opts, :registry)
    }
  end

  @impl true
  def call(conn, opts) do
    session_id = conn.query_params["session_id"]

    cond do
      is_nil(session_id) or session_id == "" ->
        conn
        |> send_resp(400, "Missing session_id parameter")
        |> halt()

      opts.registry && not session_exists?(opts.registry, session_id) ->
        conn
        |> send_resp(404, "Session not found")
        |> halt()

      true ->
        stream_sse(conn, opts, session_id)
    end
  end

  # ============================================
  # SSE Streaming
  # ============================================

  defp stream_sse(conn, opts, session_id) do
    topic = opts.topic_prefix <> session_id

    # Subscribe to PubSub
    :ok = Phoenix.PubSub.subscribe(opts.pubsub, topic)
    Logger.debug("SSE client subscribed to #{topic}")

    # Set SSE headers and start chunked response
    conn =
      conn
      |> put_sse_headers()
      |> send_chunked(200)

    # Start streaming loop
    stream_loop(conn, topic)
  end

  defp put_sse_headers(conn) do
    Protocol.response_headers(disable_buffering: true)
    |> Enum.reduce(conn, fn {key, value}, conn ->
      put_resp_header(conn, key, value)
    end)
  end

  defp stream_loop(conn, topic) do
    receive do
      {:a2ui, json_line} ->
        case send_sse_event(conn, json_line) do
          {:ok, conn} ->
            stream_loop(conn, topic)

          {:error, _reason} ->
            Logger.debug("SSE client disconnected from #{topic}")
            conn
        end

      {:a2ui_stream_done, meta} ->
        # Per A2UI spec: SSE data: must contain ONLY valid A2UI envelopes.
        # Signal completion by closing the connection, NOT by sending JSON.
        # Optionally send an SSE comment (ignored by A2UI parser) for debugging.
        Logger.debug("SSE stream completed for #{topic}: #{inspect(meta)}")
        _ = send_sse_comment(conn, "stream-done")
        conn

      {:a2ui_stream_error, reason} ->
        # Per A2UI spec: SSE data: must contain ONLY valid A2UI envelopes.
        # Signal errors by closing the connection, NOT by sending JSON.
        # Optionally send an SSE comment (ignored by A2UI parser) for debugging.
        Logger.error("SSE stream error for #{topic}: #{inspect(reason)}")
        _ = send_sse_comment(conn, "stream-error: #{inspect(reason)}")
        conn
    after
      # Heartbeat to detect disconnected clients
      30_000 ->
        case send_sse_comment(conn, "heartbeat") do
          {:ok, conn} ->
            stream_loop(conn, topic)

          {:error, _reason} ->
            Logger.debug("SSE client disconnected (heartbeat failed) from #{topic}")
            conn
        end
    end
  end

  defp send_sse_event(conn, data) do
    sse_data = Event.format(data)
    chunk(conn, sse_data)
  end

  defp send_sse_comment(conn, comment) do
    chunk(conn, ": #{comment}\n\n")
  end

  # ============================================
  # Private Helpers
  # ============================================

  defp session_exists?(registry, session_id) do
    A2UI.Transport.HTTP.Registry.session_exists?(registry, session_id)
  end
end
