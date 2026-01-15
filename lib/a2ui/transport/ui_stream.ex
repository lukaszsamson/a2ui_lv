defmodule A2UI.Transport.UIStream do
  @moduledoc """
  Behaviour for server→client UI message stream delivery.

  Per the A2UI v0.8 protocol, the renderer consumes a one-way JSONL stream
  containing `surfaceUpdate`, `dataModelUpdate`, `beginRendering`, and
  `deleteSurface` messages. This behaviour abstracts the transport layer
  (SSE, WebSocket, etc.) from the renderer.

  ## Delivery Format

  Implementations must send messages to the consumer process in this format:

  - `{:a2ui, json_line}` - A single JSONL message line
  - `{:a2ui_stream_error, reason}` - Stream error occurred
  - `{:a2ui_stream_done, meta}` - Stream completed (optional metadata)

  ## Example Implementation

      defmodule MyApp.SSETransport do
        @behaviour A2UI.Transport.UIStream

        use GenServer

        @impl true
        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts)
        end

        @impl true
        def open(pid, surface_id, consumer, opts) do
          GenServer.call(pid, {:open, surface_id, consumer, opts})
        end

        @impl true
        def close(pid, surface_id) do
          GenServer.call(pid, {:close, surface_id})
        end

        # GenServer callbacks...
      end

  ## Usage with A2UI.Session

  The consumer process (typically a LiveView or GenServer) receives messages
  and applies them to the session:

      def handle_info({:a2ui, json_line}, state) do
        case A2UI.Session.apply_json_line(state.session, json_line) do
          {:ok, updated_session} ->
            {:noreply, %{state | session: updated_session}}
          {:error, error} ->
            # Handle error...
        end
      end

      def handle_info({:a2ui_stream_error, reason}, state) do
        Logger.error("Stream error: \#{inspect(reason)}")
        {:noreply, state}
      end

      def handle_info({:a2ui_stream_done, _meta}, state) do
        {:noreply, state}
      end
  """

  @typedoc """
  Options passed to transport operations.

  Common options include:
  - `:timeout` - Operation timeout in milliseconds
  - `:headers` - HTTP headers for SSE/REST transports
  - `:url` - Endpoint URL for HTTP-based transports
  """
  @type opts :: keyword()

  @typedoc """
  Metadata returned when a stream completes.

  May include information like:
  - `:bytes_received` - Total bytes received
  - `:messages_count` - Number of messages delivered
  - `:duration_ms` - Stream duration in milliseconds
  """
  @type stream_meta :: map()

  @doc """
  Starts the transport process.

  Returns `{:ok, pid}` on success or `{:error, reason}` on failure.

  ## Options

  Implementation-specific options. Common options include:
  - `:name` - Process name for registration
  - `:url` - Base URL for HTTP-based transports
  """
  @callback start_link(opts()) :: GenServer.on_start()

  @doc """
  Opens a stream for a specific surface to a consumer process.

  The transport will begin delivering `{:a2ui, json_line}` messages to
  the consumer process. Multiple surfaces can be streamed concurrently.

  ## Parameters

  - `pid` - The transport process
  - `surface_id` - Identifier for the surface being streamed
  - `consumer` - PID of the process to receive messages
  - `opts` - Transport-specific options

  ## Returns

  - `:ok` - Stream opened successfully
  - `{:error, reason}` - Failed to open stream
  """
  @callback open(pid :: pid(), surface_id :: String.t(), consumer :: pid(), opts()) ::
              :ok | {:error, term()}

  @doc """
  Closes an active stream for a surface.

  The consumer may receive a final `{:a2ui_stream_done, meta}` message
  after this call.

  ## Parameters

  - `pid` - The transport process
  - `surface_id` - Identifier for the surface stream to close

  ## Returns

  - `:ok` - Always succeeds (idempotent)
  """
  @callback close(pid :: pid(), surface_id :: String.t()) :: :ok

  @doc """
  Optional callback to check if the transport is connected/healthy.

  Implementations that don't support health checks can omit this callback.
  """
  @callback connected?(pid :: pid()) :: boolean()

  @optional_callbacks [connected?: 1]
end
