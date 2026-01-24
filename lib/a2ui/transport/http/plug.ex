defmodule A2UI.Transport.HTTP.Plug do
  @moduledoc """
  Combined HTTP router for A2UI HTTP+SSE transport.

  This Plug provides all endpoints needed for HTTP+SSE transport:

  - `GET /stream?session_id=X` - SSE stream for receiving A2UI messages
  - `POST /events` - Send client events (actions) to the server
  - `POST /message` - Agent pushes A2UI message to a session
  - `POST /sessions` - Create a new session (optional)

  ## Usage

  Mount in your Phoenix router:

      forward "/a2ui", A2UI.Transport.HTTP.Plug,
        pubsub: MyApp.PubSub,
        registry: A2UI.Transport.HTTP.Registry

  ## Options

  - `:pubsub` - Required. The PubSub module for broadcasting
  - `:registry` - Optional. Registry process name for session management.
    If not provided, sessions won't be validated.
  - `:topic_prefix` - Topic prefix for sessions (default: "a2ui:session:")
  - `:event_handler` - Optional function to handle client events:
    `(session_id, event_envelope) -> :ok | {:error, reason}`

  ## Endpoints

  ### GET /stream

  Establishes an SSE connection for receiving A2UI messages.

  Query parameters:
  - `session_id` - Required. Session to subscribe to.

  ### POST /events

  Receives client events (actions) from the renderer.

  Request body (JSON):
  ```json
  {
    "sessionId": "abc123",
    "event": {"userAction": {"name": "submit", ...}}
  }
  ```

  ### POST /message

  Allows an agent to push an A2UI message to a session.

  Request body (JSON):
  ```json
  {
    "sessionId": "abc123",
    "message": {"surfaceUpdate": {...}}
  }
  ```

  ### POST /sessions

  Creates a new session.

  Request body (JSON, optional):
  ```json
  {"metadata": {"prompt": "user request"}}
  ```

  Response:
  ```json
  {"sessionId": "abc123"}
  ```
  """

  use Plug.Router
  require Logger

  alias A2UI.Transport.HTTP.Registry
  alias A2UI.Transport.HTTP.SSEServer

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug :match
  plug :dispatch

  # ============================================
  # Routes
  # ============================================

  get "/stream" do
    opts = conn.private[:a2ui_http_opts]

    sse_opts =
      SSEServer.init(
        pubsub: opts.pubsub,
        topic_prefix: opts.topic_prefix,
        registry: opts.registry
      )

    SSEServer.call(conn, sse_opts)
  end

  post "/events" do
    opts = conn.private[:a2ui_http_opts]

    case conn.body_params do
      %{"sessionId" => session_id, "event" => event} when is_binary(session_id) ->
        handle_event(conn, opts, session_id, event)

      _ ->
        send_json(conn, 400, %{error: "Missing sessionId or event"})
    end
  end

  post "/message" do
    opts = conn.private[:a2ui_http_opts]

    case conn.body_params do
      %{"sessionId" => session_id, "message" => message}
      when is_binary(session_id) and is_binary(message) ->
        handle_message(conn, opts, session_id, message)

      %{"sessionId" => session_id, "message" => message}
      when is_binary(session_id) and is_map(message) ->
        handle_message(conn, opts, session_id, Jason.encode!(message))

      _ ->
        send_json(conn, 400, %{error: "Missing sessionId or message"})
    end
  end

  post "/sessions" do
    opts = conn.private[:a2ui_http_opts]
    metadata = conn.body_params["metadata"] || %{}

    case opts.registry do
      nil ->
        send_json(conn, 501, %{error: "Session management not configured"})

      registry ->
        {:ok, session_id} = Registry.create_session(registry, metadata: metadata)
        send_json(conn, 201, %{sessionId: session_id})
    end
  end

  # Done marker endpoint - signals stream completion
  post "/done" do
    opts = conn.private[:a2ui_http_opts]

    case conn.body_params do
      %{"sessionId" => session_id} when is_binary(session_id) ->
        meta = conn.body_params["meta"] || %{}
        handle_done(conn, opts, session_id, meta)

      _ ->
        send_json(conn, 400, %{error: "Missing sessionId"})
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  # ============================================
  # Plug Callbacks
  # ============================================

  @default_topic_prefix "a2ui:session:"

  @impl true
  def init(opts) do
    %{
      pubsub: Keyword.fetch!(opts, :pubsub),
      registry: Keyword.get(opts, :registry),
      topic_prefix: Keyword.get(opts, :topic_prefix, @default_topic_prefix),
      event_handler: Keyword.get(opts, :event_handler)
    }
  end

  @impl true
  def call(conn, opts) do
    conn
    |> put_private(:a2ui_http_opts, opts)
    |> super(opts)
  end

  # ============================================
  # Handler Functions
  # ============================================

  defp handle_event(conn, opts, session_id, event) do
    case opts.event_handler do
      nil ->
        # No event handler configured - just acknowledge
        Logger.debug("Received event for session #{session_id}: #{inspect(event)}")
        send_json(conn, 200, %{ok: true})

      handler when is_function(handler, 2) ->
        case handler.(session_id, event) do
          :ok ->
            send_json(conn, 200, %{ok: true})

          {:error, reason} ->
            send_json(conn, 500, %{error: inspect(reason)})
        end
    end
  end

  defp handle_message(conn, opts, session_id, json_line) do
    case opts.registry do
      nil ->
        # No registry - broadcast directly to topic
        topic = opts.topic_prefix <> session_id
        Phoenix.PubSub.broadcast(opts.pubsub, topic, {:a2ui, json_line})
        send_json(conn, 200, %{ok: true})

      registry ->
        case Registry.broadcast(registry, session_id, json_line) do
          :ok ->
            send_json(conn, 200, %{ok: true})

          {:error, :not_found} ->
            send_json(conn, 404, %{error: "Session not found"})
        end
    end
  end

  defp handle_done(conn, opts, session_id, meta) do
    case opts.registry do
      nil ->
        topic = opts.topic_prefix <> session_id
        Phoenix.PubSub.broadcast(opts.pubsub, topic, {:a2ui_stream_done, meta})
        send_json(conn, 200, %{ok: true})

      registry ->
        case Registry.broadcast_done(registry, session_id, meta) do
          :ok ->
            send_json(conn, 200, %{ok: true})

          {:error, :not_found} ->
            send_json(conn, 404, %{error: "Session not found"})
        end
    end
  end

  defp send_json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end
end
