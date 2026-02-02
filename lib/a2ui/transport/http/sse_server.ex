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

  Messages are sent in standard SSE format with event IDs for resume support:

      id: 1
      data: {"surfaceUpdate":{...}}

      id: 2
      data: {"beginRendering":{...}}

  The `id:` field enables client reconnection using the `Last-Event-ID` header.

  ## Resume/Replay Support

  When a client reconnects with the `Last-Event-ID` header, the server will
  replay all events since that ID (if the registry is configured and the events
  are still in the session's event history buffer).

  To enable replay, configure the registry option:

      A2UI.Transport.HTTP.SSEServer.call(conn,
        pubsub: MyApp.PubSub,
        registry: A2UI.Transport.HTTP.Registry
      )

  The `retry:` hint is also sent at connection start to suggest reconnection delay.

  ## Options

  - `:pubsub` - Required. The PubSub module for message broadcast.
  - `:topic_prefix` - Topic prefix for sessions (default: "a2ui:session:")
  - `:registry` - Registry module for session/event lookup (enables replay)
  - `:retry_ms` - Suggested reconnection delay in ms (default: 3000)

  ## Connection Lifecycle

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
      registry: Keyword.get(opts, :registry),
      retry_ms: Keyword.get(opts, :retry_ms, 3000)
    }
  end

  @impl true
  def call(conn, opts) do
    session_id = conn.query_params["session_id"]

    # Extract Last-Event-ID header for resume support
    last_event_id = get_last_event_id(conn)

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
        stream_sse(conn, opts, session_id, last_event_id)
    end
  end

  defp get_last_event_id(conn) do
    case get_req_header(conn, "last-event-id") do
      [id | _] ->
        case Integer.parse(id) do
          {n, ""} when n >= 0 -> n
          _ -> nil
        end

      [] ->
        nil
    end
  end

  # ============================================
  # SSE Streaming
  # ============================================

  defp stream_sse(conn, opts, session_id, last_event_id) do
    topic = opts.topic_prefix <> session_id

    # Subscribe to PubSub first to avoid race condition
    :ok = Phoenix.PubSub.subscribe(opts.pubsub, topic)
    Logger.debug("SSE client subscribed to #{topic}")

    # Set SSE headers and start chunked response
    conn =
      conn
      |> put_sse_headers()
      |> send_chunked(200)

    # Send retry hint
    conn =
      case send_retry_hint(conn, opts.retry_ms) do
        {:ok, conn} -> conn
        {:error, _} -> conn
      end

    # Replay missed events if Last-Event-ID was provided and registry is available
    conn =
      if last_event_id && opts.registry do
        replay_events(conn, opts.registry, session_id, last_event_id)
      else
        conn
      end

    # Start streaming loop
    stream_loop(conn, topic)
  end

  defp replay_events(conn, registry, session_id, after_event_id) do
    alias A2UI.Transport.HTTP.Registry

    case Registry.get_events_since(registry, session_id, after_event_id) do
      {:ok, events} when events != [] ->
        Logger.debug(
          "Replaying #{length(events)} events for session #{session_id} (after event #{after_event_id})"
        )

        Enum.reduce(events, conn, fn {event_id, data}, acc_conn ->
          case send_sse_event(acc_conn, data, event_id) do
            {:ok, new_conn} -> new_conn
            {:error, _} -> acc_conn
          end
        end)

      {:ok, []} ->
        Logger.debug(
          "No events to replay for session #{session_id} (after event #{after_event_id})"
        )

        conn

      {:error, :not_found} ->
        Logger.warning("Session #{session_id} not found in registry during replay")
        conn
    end
  end

  defp send_retry_hint(conn, retry_ms) when is_integer(retry_ms) and retry_ms > 0 do
    chunk(conn, "retry: #{retry_ms}\n\n")
  end

  defp send_retry_hint(conn, _), do: {:ok, conn}

  defp put_sse_headers(conn) do
    Protocol.response_headers(disable_buffering: true)
    |> Enum.reduce(conn, fn {key, value}, conn ->
      put_resp_header(conn, key, value)
    end)
  end

  defp stream_loop(conn, topic) do
    receive do
      # New format with event ID (from Registry)
      {:a2ui, json_line, event_id} ->
        case send_sse_event(conn, json_line, event_id) do
          {:ok, conn} ->
            stream_loop(conn, topic)

          {:error, _reason} ->
            Logger.debug("SSE client disconnected from #{topic}")
            conn
        end

      # Legacy format without event ID (for backward compatibility)
      {:a2ui, json_line} ->
        case send_sse_event(conn, json_line, nil) do
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

  defp send_sse_event(conn, data, event_id) do
    opts = if event_id, do: [id: event_id], else: []
    sse_data = Event.format(data, opts)
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
