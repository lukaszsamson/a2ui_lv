defmodule A2UI.Transport.A2A.Client do
  @moduledoc """
  A2A transport client for A2UI.

  Implements both `A2UI.Transport.UIStream` and `A2UI.Transport.Events` behaviors
  using the A2A protocol format. This client can communicate with any A2A-compliant
  agent that supports the A2UI extension.

  ## Requirements

  This module requires the `req` library. Add to your `mix.exs`:

      {:req, "~> 0.5"}

  ## Usage

      # Start the client
      {:ok, client} = A2UI.Transport.A2A.Client.start_link(
        base_url: "http://localhost:3002",
        capabilities: A2UI.ClientCapabilities.default()
      )

      # Fetch agent card to verify A2UI support
      {:ok, card} = A2UI.Transport.A2A.Client.fetch_agent_card(client)

      # Create a task (starts the conversation)
      initial_message = %{"content" => "Show me a hello world button"}
      {:ok, task_id} = A2UI.Transport.A2A.Client.create_task(client, initial_message, [])

      # Open a stream to receive responses
      :ok = A2UI.Transport.A2A.Client.open(client, "main", self(), task_id: task_id)

      # Consumer receives:
      # {:a2ui, json_line}
      # {:a2ui_stream_done, meta}
      # {:a2ui_stream_error, reason}

      # Send events (actions)
      event = %{"userAction" => %{"name" => "submit", "surfaceId" => "main", ...}}
      :ok = A2UI.Transport.A2A.Client.send_event(client, event, task_id: task_id)

  ## Options

  - `:base_url` - Required. Base URL of the A2A agent
  - `:capabilities` - Client capabilities (default: `A2UI.ClientCapabilities.default()`)
  - `:protocol_version` - A2UI protocol version (default: `:v0_8`)
  - `:req_options` - Additional options for Req (timeouts, headers, etc.)
  """

  @behaviour A2UI.Transport.UIStream
  @behaviour A2UI.Transport.Events

  use GenServer
  require Logger

  alias A2UI.A2A.Protocol
  alias A2UI.A2A.DataPart
  alias A2UI.ClientCapabilities
  alias A2UI.Transport.A2A.AgentCard
  alias A2UI.SSE.Event
  alias A2UI.SSE.StreamState

  defstruct [
    :base_url,
    :capabilities,
    :protocol_version,
    :req_options,
    :agent_card,
    :current_task_id,
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
  Starts the A2A client.

  ## Options

  - `:base_url` - Required. Base URL of the A2A agent
  - `:capabilities` - Client capabilities (default: `ClientCapabilities.default()`)
  - `:protocol_version` - A2UI version (default: `:v0_8`)
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
      A2UI.Transport.A2A.missing_dependency_error()
    end
  end

  @doc """
  Opens an SSE stream for a surface to a consumer process.

  The consumer will receive `{:a2ui, json_line}` messages containing
  A2UI envelopes extracted from A2A message DataParts.

  ## Options

  - `:task_id` - Required. The A2A task ID to stream from
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

  @doc """
  Sends an event envelope to the server via A2A POST.

  The envelope is wrapped in an A2A message with client capabilities.

  ## Options

  - `:task_id` - Required. The A2A task ID to send to
  - `:timeout` - Request timeout in milliseconds (default: 5000)
  - `:data_broadcast` - Data model broadcast payload
  """
  @impl A2UI.Transport.Events
  def send_event(pid, event_envelope, opts \\ []) do
    GenServer.call(pid, {:send_event, event_envelope, opts})
  end

  # A2A-specific API

  @doc """
  Fetches the agent card from `/.well-known/agent.json`.

  Returns `{:ok, agent_card}` on success.
  """
  @spec fetch_agent_card(pid()) :: {:ok, AgentCard.t()} | {:error, term()}
  def fetch_agent_card(pid) do
    GenServer.call(pid, :fetch_agent_card)
  end

  @doc """
  Creates a new A2A task with an initial message.

  The message is wrapped in A2A format with client capabilities.

  ## Parameters

  - `pid` - The client process
  - `initial_content` - The initial message content (text prompt)
  - `opts` - Options (currently unused)

  ## Returns

  `{:ok, task_id}` on success.
  """
  @spec create_task(pid(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def create_task(pid, initial_content, opts \\ []) do
    GenServer.call(pid, {:create_task, initial_content, opts})
  end

  @doc """
  Checks if the connected agent supports A2UI.
  """
  @spec supports_a2ui?(pid()) :: boolean()
  def supports_a2ui?(pid) do
    GenServer.call(pid, :supports_a2ui?)
  end

  # ============================================
  # GenServer Callbacks
  # ============================================

  if @req_available do
    @impl true
    def init(opts) do
      base_url = Keyword.fetch!(opts, :base_url)
      capabilities = Keyword.get(opts, :capabilities, ClientCapabilities.default())
      protocol_version = Keyword.get(opts, :protocol_version, :v0_8)
      req_options = Keyword.get(opts, :req_options, [])

      state = %__MODULE__{
        base_url: base_url,
        capabilities: capabilities,
        protocol_version: protocol_version,
        req_options: req_options,
        stream_state: StreamState.new(session_id: "a2a")
      }

      {:ok, state}
    end

    @impl true
    def handle_call(:fetch_agent_card, _from, state) do
      case do_fetch_agent_card(state) do
        {:ok, card} = result ->
          {:reply, result, %{state | agent_card: card}}

        error ->
          {:reply, error, state}
      end
    end

    def handle_call({:create_task, initial_content, _opts}, _from, state) do
      case do_create_task(state, initial_content) do
        {:ok, task_id} = result ->
          {:reply, result, %{state | current_task_id: task_id}}

        error ->
          {:reply, error, state}
      end
    end

    def handle_call(:supports_a2ui?, _from, state) do
      result =
        case state.agent_card do
          %AgentCard{} = card -> AgentCard.supports_a2ui?(card, state.protocol_version)
          _ -> false
        end

      {:reply, result, state}
    end

    def handle_call({:open, surface_id, consumer, opts}, _from, state) do
      task_id = opts[:task_id] || state.current_task_id

      if is_nil(task_id) do
        {:reply, {:error, :no_task_id}, state}
      else
        # Monitor the consumer
        Process.monitor(consumer)

        # Add consumer to map
        consumers = Map.put(state.consumers, surface_id, consumer)
        state = %{state | consumers: consumers, current_task_id: task_id}

        # Start streaming if not already
        state = maybe_start_stream(state, task_id)

        {:reply, :ok, state}
      end
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

    def handle_call({:send_event, event_envelope, opts}, _from, state) do
      task_id = opts[:task_id] || state.current_task_id

      if is_nil(task_id) do
        {:reply, {:error, :no_task_id}, state}
      else
        result = do_send_event(state, event_envelope, task_id, opts)
        {:reply, result, state}
      end
    end

    @impl true
    def handle_info({:sse_chunk, chunk}, state) do
      {events, stream_state} = StreamState.process_chunk(state.stream_state, chunk)
      state = %{state | stream_state: stream_state}

      # Process each SSE event
      for event <- events do
        case Event.extract_payload(event) do
          {:ok, json_line} ->
            # Try to parse as A2A message and extract DataParts
            process_a2a_message(json_line, state.consumers)

          {:error, _} ->
            :skip
        end
      end

      {:noreply, state}
    end

    def handle_info({:sse_connected}, state) do
      Logger.debug("A2A client connected to #{state.base_url}")
      stream_state = StreamState.mark_connected(state.stream_state)
      {:noreply, %{state | connected: true, stream_state: stream_state}}
    end

    def handle_info({:sse_error, reason}, state) do
      Logger.error("A2A client error: #{inspect(reason)}")
      dispatch_to_consumers(state.consumers, {:a2ui_stream_error, reason})

      stream_state = StreamState.mark_disconnected(state.stream_state)
      state = %{state | connected: false, stream_state: stream_state, stream_task: nil}

      # Schedule reconnect
      retry_delay = StreamState.retry_delay(stream_state)
      Process.send_after(self(), :reconnect, retry_delay)

      {:noreply, state}
    end

    def handle_info({:sse_done}, state) do
      Logger.debug("A2A client stream completed")
      meta = StreamState.completion_meta(state.stream_state)
      dispatch_to_consumers(state.consumers, {:a2ui_stream_done, meta})

      stream_state = StreamState.mark_disconnected(state.stream_state)
      {:noreply, %{state | connected: false, stream_state: stream_state, stream_task: nil}}
    end

    def handle_info(:reconnect, state) do
      if map_size(state.consumers) > 0 and state.current_task_id do
        {:noreply, maybe_start_stream(state, state.current_task_id)}
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

    defp do_fetch_agent_card(state) do
      url = build_agent_card_url(state)
      headers = a2a_headers(state)

      req_opts =
        Keyword.merge(
          [
            headers: headers,
            receive_timeout: 10_000
          ],
          state.req_options
        )

      case Req.get(url, req_opts) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          AgentCard.parse(body)

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error("Failed to fetch agent card: status=#{status}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          Logger.error("Failed to fetch agent card: #{inspect(reason)}")
          {:error, reason}
      end
    end

    defp do_create_task(state, initial_content) do
      url = build_tasks_url(state)
      headers = a2a_headers(state)

      # Build the initial A2A message
      # The initial message contains a text part with the prompt
      a2a_message = build_initial_task_message(state, initial_content)

      req_opts =
        Keyword.merge(
          [
            headers: headers,
            json: a2a_message,
            receive_timeout: 30_000
          ],
          state.req_options
        )

      case Req.post(url, req_opts) do
        {:ok, %Req.Response{status: status, body: body}} when status in [200, 201] ->
          # Extract task ID from response
          case extract_task_id(body) do
            {:ok, task_id} ->
              Logger.info("A2A task created: #{task_id}")
              {:ok, task_id}

            :error ->
              Logger.error("Failed to extract task ID from response")
              {:error, :missing_task_id}
          end

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error("Failed to create task: status=#{status}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          Logger.error("Failed to create task: #{inspect(reason)}")
          {:error, reason}
      end
    end

    defp do_send_event(state, event_envelope, task_id, opts) do
      # Validate the envelope
      case A2UI.Transport.Events.validate_envelope(event_envelope) do
        :ok ->
          post_event(state, event_envelope, task_id, opts)

        {:error, _} = error ->
          error
      end
    end

    defp post_event(state, event_envelope, task_id, opts) do
      url = build_task_url(state, task_id)
      headers = a2a_headers(state)
      timeout = Keyword.get(opts, :timeout, 5_000)

      # Build A2A message with capabilities
      a2a_message = DataPart.build_client_message(event_envelope, state.capabilities)

      # Add data broadcast if present
      a2a_message =
        case Keyword.get(opts, :data_broadcast) do
          nil ->
            a2a_message

          broadcast ->
            put_in(
              a2a_message,
              ["message", "metadata", "a2uiDataBroadcast"],
              broadcast
            )
        end

      req_opts =
        Keyword.merge(
          [
            headers: headers,
            json: a2a_message,
            receive_timeout: timeout
          ],
          state.req_options
        )

      case Req.post(url, req_opts) do
        {:ok, %Req.Response{status: status}} when status in 200..299 ->
          :ok

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error("A2A event POST failed: status=#{status}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          Logger.error("A2A event POST error: #{inspect(reason)}")
          {:error, reason}
      end
    end

    defp maybe_start_stream(%{stream_task: nil, consumers: consumers} = state, task_id)
         when map_size(consumers) > 0 do
      parent = self()
      url = build_task_stream_url(state, task_id)
      headers = a2a_headers(state) ++ StreamState.reconnect_headers(state.stream_state)

      task =
        Task.async(fn ->
          stream_sse(parent, url, headers, state.req_options)
        end)

      %{state | stream_task: task}
    end

    defp maybe_start_stream(state, _task_id), do: state

    defp maybe_stop_stream(%{stream_task: task, consumers: consumers} = state)
         when map_size(consumers) == 0 and not is_nil(task) do
      Task.shutdown(task, :brutal_kill)
      %{state | stream_task: nil, connected: false}
    end

    defp maybe_stop_stream(state), do: state

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

    defp process_a2a_message(json_line, consumers) do
      case Jason.decode(json_line) do
        {:ok, %{"message" => _} = a2a_msg} ->
          # Extract A2UI envelopes from DataParts
          envelopes = DataPart.extract_envelopes(a2a_msg)

          for envelope <- envelopes do
            json = Jason.encode!(envelope)
            dispatch_to_consumers(consumers, {:a2ui, json})
          end

        {:ok, envelope} when is_map(envelope) ->
          # Not wrapped in A2A message, dispatch directly
          # (for backwards compatibility or raw A2UI streams)
          dispatch_to_consumers(consumers, {:a2ui, json_line})

        {:error, _} ->
          # Not valid JSON, skip
          :ok
      end
    end

    defp dispatch_to_consumers(consumers, message) do
      for {_surface_id, consumer} <- consumers do
        send(consumer, message)
      end
    end

    defp build_agent_card_url(state) do
      uri =
        state.base_url
        |> URI.parse()
        |> Map.put(:path, "/.well-known/agent.json")

      URI.to_string(uri)
    end

    defp build_tasks_url(state) do
      case state.agent_card do
        %AgentCard{} = card ->
          AgentCard.tasks_url(card)

        _ ->
          uri =
            state.base_url
            |> URI.parse()
            |> Map.update!(:path, fn
              nil -> "/a2a/tasks"
              path -> String.trim_trailing(path, "/") <> "/a2a/tasks"
            end)

          URI.to_string(uri)
      end
    end

    defp build_task_url(state, task_id) do
      case state.agent_card do
        %AgentCard{} = card ->
          AgentCard.task_url(card, task_id)

        _ ->
          build_tasks_url(state) <> "/" <> task_id
      end
    end

    defp build_task_stream_url(state, task_id) do
      # SSE stream endpoint - just GET the task URL
      build_task_url(state, task_id)
    end

    defp a2a_headers(state) do
      extension_uri = Protocol.extension_uri(state.protocol_version)

      [
        {"x-a2a-extensions", extension_uri},
        {"accept", "application/json, text/event-stream"},
        {"content-type", "application/json"}
      ]
    end

    defp build_initial_task_message(state, content) do
      # Build a proper A2A task creation message
      # The initial message has a text part with the prompt
      %{
        "message" => %{
          "role" => Protocol.client_role(),
          "metadata" => %{
            Protocol.client_capabilities_key() =>
              ClientCapabilities.to_a2a_metadata(state.capabilities)
          },
          "parts" => [
            %{
              "text" => content
            }
          ]
        }
      }
    end

    defp extract_task_id(%{"taskId" => task_id}) when is_binary(task_id), do: {:ok, task_id}
    defp extract_task_id(%{"task_id" => task_id}) when is_binary(task_id), do: {:ok, task_id}
    defp extract_task_id(%{"id" => task_id}) when is_binary(task_id), do: {:ok, task_id}
    defp extract_task_id(_), do: :error
  else
    @impl true
    def init(_opts) do
      {:stop, {:missing_dependency, :req}}
    end
  end
end
