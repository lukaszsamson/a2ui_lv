defmodule A2UI.Transport.HTTP.SSEClient do
  @moduledoc """
  HTTP+SSE client for receiving A2UI messages.

  Implements `A2UI.Transport.UIStream` behavior using HTTP Server-Sent Events.
  Uses the `req` library for HTTP streaming.

  ## Requirements

  This module requires the `req` library. Add to your `mix.exs`:

      {:req, "~> 0.5"}

  ## Usage

      # Start the client
      {:ok, client} = A2UI.Transport.HTTP.SSEClient.start_link(
        base_url: "http://localhost:4000/a2ui",
        session_id: "abc123"
      )

      # Open a stream to receive messages
      :ok = A2UI.Transport.HTTP.SSEClient.open(client, "main", self(), [])

      # Consumer receives messages:
      # {:a2ui, json_line}
      # {:a2ui_stream_done, meta}
      # {:a2ui_stream_error, reason}

      # Close the stream
      :ok = A2UI.Transport.HTTP.SSEClient.close(client, "main")

  ## Options

  - `:base_url` - Required. Base URL of the HTTP transport endpoint
  - `:session_id` - Required. Session ID to subscribe to
  - `:req_options` - Additional options for Req (timeouts, headers, etc.)
  """

  @behaviour A2UI.Transport.UIStream

  use GenServer
  require Logger

  alias A2UI.SSE.Event
  alias A2UI.SSE.StreamState

  defstruct [
    :base_url,
    :session_id,
    :req_options,
    :stream_task,
    :stream_state,
    consumers: %{},
    connected: false
  ]

  # Check if Req is available at compile time
  @req_available Code.ensure_loaded?(Req)

  # ============================================
  # Client API
  # ============================================

  @doc """
  Starts the SSE client.

  ## Options

  - `:base_url` - Required. Base URL of the HTTP transport
  - `:session_id` - Required. Session ID to subscribe to
  - `:req_options` - Additional Req options (default: [])
  - `:name` - Process name
  """
  @impl A2UI.Transport.UIStream
  if @req_available do
    def start_link(opts) do
      name = Keyword.get(opts, :name)
      gen_opts = if name, do: [name: name], else: []
      GenServer.start_link(__MODULE__, opts, gen_opts)
    end
  else
    def start_link(_opts) do
      A2UI.Transport.HTTP.missing_dependency_error()
    end
  end

  @doc """
  Opens an SSE stream for a surface to a consumer process.

  The consumer will receive `{:a2ui, json_line}` messages.
  """
  @impl A2UI.Transport.UIStream
  def open(pid, surface_id, consumer, opts \\ []) do
    GenServer.call(pid, {:open, surface_id, consumer, opts})
  end

  @doc """
  Closes a stream for a surface.
  """
  @impl A2UI.Transport.UIStream
  def close(pid, surface_id) do
    GenServer.call(pid, {:close, surface_id})
  end

  @doc """
  Checks if the client is connected.
  """
  @impl A2UI.Transport.UIStream
  def connected?(pid) do
    GenServer.call(pid, :connected?)
  end

  # ============================================
  # GenServer Callbacks
  # ============================================

  if @req_available do
    @impl true
    def init(opts) do
      base_url = Keyword.fetch!(opts, :base_url)
      session_id = Keyword.fetch!(opts, :session_id)
      req_options = Keyword.get(opts, :req_options, [])

      state = %__MODULE__{
        base_url: base_url,
        session_id: session_id,
        req_options: req_options,
        stream_state: StreamState.new(session_id: session_id)
      }

      {:ok, state}
    end

    @impl true
    def handle_call({:open, surface_id, consumer, _opts}, _from, state) do
      # Monitor the consumer
      Process.monitor(consumer)

      # Add consumer to map
      consumers = Map.put(state.consumers, surface_id, consumer)
      state = %{state | consumers: consumers}

      # Start streaming if not already
      state = maybe_start_stream(state)

      {:reply, :ok, state}
    end

    def handle_call({:close, surface_id}, _from, state) do
      case Map.get(state.consumers, surface_id) do
        nil ->
          {:reply, :ok, state}

        consumer ->
          send(consumer, {:a2ui_stream_done, %{}})
          consumers = Map.delete(state.consumers, surface_id)
          state = %{state | consumers: consumers}

          # Stop stream if no more consumers
          state = maybe_stop_stream(state)

          {:reply, :ok, state}
      end
    end

    def handle_call(:connected?, _from, state) do
      {:reply, state.connected, state}
    end

    @impl true
    def handle_info({:sse_chunk, chunk}, state) do
      {events, stream_state} = StreamState.process_chunk(state.stream_state, chunk)
      state = %{state | stream_state: stream_state}

      # Dispatch events to all consumers
      for event <- events do
        case Event.extract_payload(event) do
          {:ok, json_line} ->
            dispatch_to_consumers(state.consumers, {:a2ui, json_line})

          {:error, _} ->
            :skip
        end
      end

      {:noreply, state}
    end

    def handle_info({:sse_connected}, state) do
      Logger.debug("SSE client connected to #{state.base_url}")
      stream_state = StreamState.mark_connected(state.stream_state)
      {:noreply, %{state | connected: true, stream_state: stream_state}}
    end

    def handle_info({:sse_error, reason}, state) do
      Logger.error("SSE client error: #{inspect(reason)}")
      dispatch_to_consumers(state.consumers, {:a2ui_stream_error, reason})

      stream_state = StreamState.mark_disconnected(state.stream_state)
      state = %{state | connected: false, stream_state: stream_state, stream_task: nil}

      # Schedule reconnect
      retry_delay = StreamState.retry_delay(stream_state)
      Process.send_after(self(), :reconnect, retry_delay)

      {:noreply, state}
    end

    def handle_info({:sse_done}, state) do
      Logger.debug("SSE client stream completed")
      meta = StreamState.completion_meta(state.stream_state)
      dispatch_to_consumers(state.consumers, {:a2ui_stream_done, meta})

      stream_state = StreamState.mark_disconnected(state.stream_state)
      {:noreply, %{state | connected: false, stream_state: stream_state, stream_task: nil}}
    end

    def handle_info(:reconnect, state) do
      if map_size(state.consumers) > 0 do
        {:noreply, maybe_start_stream(state)}
      else
        {:noreply, state}
      end
    end

    def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
      # Remove any consumers that died
      consumers =
        state.consumers
        |> Enum.reject(fn {_surface_id, consumer} -> consumer == pid end)
        |> Map.new()

      state = %{state | consumers: consumers}
      state = maybe_stop_stream(state)

      {:noreply, state}
    end

    def handle_info({ref, _result}, state) when is_reference(ref) do
      # Task completed - ignore
      {:noreply, state}
    end

    @impl true
    def terminate(_reason, state) do
      if state.stream_task do
        Task.shutdown(state.stream_task, :brutal_kill)
      end

      :ok
    end

    # ============================================
    # Private Functions
    # ============================================

    defp maybe_start_stream(%{stream_task: nil, consumers: consumers} = state)
         when map_size(consumers) > 0 do
      parent = self()
      url = build_stream_url(state)
      headers = StreamState.reconnect_headers(state.stream_state)

      task =
        Task.async(fn ->
          stream_sse(parent, url, headers, state.req_options)
        end)

      %{state | stream_task: task}
    end

    defp maybe_start_stream(state), do: state

    defp maybe_stop_stream(%{stream_task: task, consumers: consumers} = state)
         when map_size(consumers) == 0 and not is_nil(task) do
      Task.shutdown(task, :brutal_kill)
      %{state | stream_task: nil, connected: false}
    end

    defp maybe_stop_stream(state), do: state

    defp build_stream_url(state) do
      uri =
        state.base_url
        |> URI.parse()
        |> Map.update!(:path, fn
          nil -> "/stream"
          path -> String.trim_trailing(path, "/") <> "/stream"
        end)

      query = URI.encode_query(%{"session_id" => state.session_id})
      %{uri | query: query} |> URI.to_string()
    end

    defp stream_sse(parent, url, headers, req_options) do
      send(parent, {:sse_connected})

      req_opts =
        Keyword.merge(
          [
            headers: headers,
            into: fn {:data, chunk}, acc ->
              send(parent, {:sse_chunk, chunk})
              {:cont, acc}
            end,
            receive_timeout: :infinity
          ],
          req_options
        )

      case Req.get(url, req_opts) do
        {:ok, %Req.Response{status: 200}} ->
          send(parent, {:sse_done})

        {:ok, %Req.Response{status: status, body: body}} ->
          send(parent, {:sse_error, {:http_error, status, body}})

        {:error, reason} ->
          send(parent, {:sse_error, reason})
      end
    end

    defp dispatch_to_consumers(consumers, message) do
      for {_surface_id, consumer} <- consumers do
        send(consumer, message)
      end
    end
  else
    @impl true
    def init(_opts) do
      {:stop, {:missing_dependency, :req}}
    end
  end
end
