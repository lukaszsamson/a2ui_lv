defmodule A2UI.Transport.A2A.Client do
  @moduledoc """
  A2A transport client for A2UI.

  Implements both `A2UI.Transport.UIStream` and `A2UI.Transport.Events` behaviors
  using the A2A protocol format. This client wraps the `a2a_ex` library to
  communicate with any A2A-compliant agent that supports the A2UI extension.

  ## Requirements

  This module requires the `req` and `a2a_ex` libraries. Add to your `mix.exs`:

      {:req, "~> 0.5"}
      {:a2a_ex, path: "../a2a_ex"}

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

  defstruct [
    :base_url,
    :capabilities,
    :protocol_version,
    :req_options,
    :agent_card,
    :a2a_agent_card,
    :current_task_id,
    :stream_task,
    :stream_cancel_fun,
    :last_event_id,
    consumers: %{},
    connected: false
  ]

  # Check if dependencies are available at compile time
  @a2a_available Code.ensure_loaded?(A2A.Client)
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
  if @a2a_available and @req_available do
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

  if @a2a_available and @req_available do
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
        req_options: req_options
      }

      {:ok, state}
    end

    @impl true
    def handle_call(:fetch_agent_card, _from, state) do
      case do_fetch_agent_card(state) do
        {:ok, a2a_card, card} ->
          {:reply, {:ok, card}, %{state | agent_card: card, a2a_agent_card: a2a_card}}

        {:error, _} = error ->
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
    def handle_info({:stream_connected}, state) do
      Logger.debug("A2A client connected to #{state.base_url}")
      {:noreply, %{state | connected: true}}
    end

    def handle_info({:stream_item, item}, state) do
      state = process_stream_item(item, state)
      {:noreply, state}
    end

    def handle_info({:stream_done}, state) do
      Logger.debug("A2A client stream completed")
      dispatch_to_consumers(state.consumers, {:a2ui_stream_done, %{}})

      {:noreply, %{state | connected: false, stream_task: nil, stream_cancel_fun: nil}}
    end

    def handle_info({:stream_error, reason}, state) do
      Logger.error("A2A client stream error: #{inspect(reason)}")
      dispatch_to_consumers(state.consumers, {:a2ui_stream_error, reason})

      state = %{state | connected: false, stream_task: nil, stream_cancel_fun: nil}

      # Schedule reconnect if we have consumers
      if map_size(state.consumers) > 0 do
        Process.send_after(self(), :reconnect, 1000)
      end

      {:noreply, state}
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
      if state.stream_cancel_fun do
        state.stream_cancel_fun.()
      end

      if state.stream_task do
        Task.shutdown(state.stream_task, :brutal_kill)
      end

      :ok
    end

    # ============================================
    # Private Functions
    # ============================================

    defp do_fetch_agent_card(state) do
      config_opts = a2a_config_opts(state)

      case A2A.Client.discover(state.base_url, config_opts) do
        {:ok, a2a_card} ->
          card = AgentCard.from_a2a_ex(a2a_card)
          {:ok, a2a_card, card}

        {:error, %A2A.Error{} = error} ->
          Logger.error("Failed to fetch agent card: #{inspect(error)}")
          {:error, error}
      end
    end

    defp do_create_task(state, initial_content) do
      message = build_a2a_message(state.capabilities, initial_content)
      config_opts = a2a_config_opts(state)

      case A2A.Client.send_message(state.base_url, [message: message], config_opts) do
        {:ok, %A2A.Types.Task{id: task_id}} when is_binary(task_id) ->
          Logger.info("A2A task created: #{task_id}")
          {:ok, task_id}

        {:ok, %A2A.Types.Message{task_id: task_id}} when is_binary(task_id) ->
          Logger.info("A2A task created: #{task_id}")
          {:ok, task_id}

        {:ok, other} ->
          Logger.error("Failed to extract task ID from response: #{inspect(other)}")
          {:error, :missing_task_id}

        {:error, %A2A.Error{} = error} ->
          Logger.error("Failed to create task: #{inspect(error)}")
          {:error, error}
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
      # Build A2A message with capabilities
      a2a_message_map = DataPart.build_client_message(event_envelope, state.capabilities)

      # Add data broadcast if present
      a2a_message_map =
        case Keyword.get(opts, :data_broadcast) do
          nil ->
            a2a_message_map

          broadcast ->
            put_in(
              a2a_message_map,
              ["message", "metadata", "a2uiDataBroadcast"],
              broadcast
            )
        end

      # Convert to A2A.Types.Message
      message = A2A.Types.Message.from_map(a2a_message_map["message"])

      config_opts =
        a2a_config_opts(state)
        |> Keyword.put(:req_options, Keyword.merge(state.req_options, receive_timeout: 5_000))

      # Send the message with task_id in metadata
      request_opts = [
        message: message,
        metadata: %{"taskId" => task_id}
      ]

      case A2A.Client.send_message(state.base_url, request_opts, config_opts) do
        {:ok, _} ->
          :ok

        {:error, %A2A.Error{} = error} ->
          Logger.error("A2A event POST failed: #{inspect(error)}")
          {:error, error}
      end
    end

    defp maybe_start_stream(%{stream_task: nil, consumers: consumers} = state, task_id)
         when map_size(consumers) > 0 do
      parent = self()
      config_opts = a2a_config_opts(state)

      # Use resubscribe if we have a last_event_id, otherwise subscribe
      stream_result =
        if state.last_event_id do
          A2A.Client.resubscribe(
            state.base_url,
            task_id,
            %{cursor: state.last_event_id},
            config_opts
          )
        else
          A2A.Client.subscribe(state.base_url, task_id, config_opts)
        end

      case stream_result do
        {:ok, stream} ->
          send(parent, {:stream_connected})

          task =
            Task.async(fn ->
              try do
                Enum.each(stream, fn item ->
                  send(parent, {:stream_item, item})
                end)

                send(parent, {:stream_done})
              rescue
                e ->
                  send(parent, {:stream_error, e})
              end
            end)

          %{
            state
            | stream_task: task,
              stream_cancel_fun: fn -> A2A.Client.Stream.cancel(stream) end
          }

        {:error, reason} ->
          Logger.error("Failed to start stream: #{inspect(reason)}")
          send(parent, {:stream_error, reason})
          state
      end
    end

    defp maybe_start_stream(state, _task_id), do: state

    defp maybe_stop_stream(%{stream_task: task, consumers: consumers} = state)
         when map_size(consumers) == 0 and not is_nil(task) do
      if state.stream_cancel_fun do
        state.stream_cancel_fun.()
      end

      Task.shutdown(task, :brutal_kill)
      %{state | stream_task: nil, stream_cancel_fun: nil, connected: false}
    end

    defp maybe_stop_stream(state), do: state

    defp process_stream_item(%A2A.Types.StreamResponse{message: msg}, state)
         when not is_nil(msg) do
      # Convert message to map and extract envelopes
      message_map = A2A.Types.Message.to_map(msg)
      envelopes = DataPart.extract_envelopes(%{"message" => message_map})

      for envelope <- envelopes do
        json = Jason.encode!(envelope)
        dispatch_to_consumers(state.consumers, {:a2ui, json})
      end

      # Update last_event_id if available
      update_last_event_id(state, msg)
    end

    defp process_stream_item(%A2A.Types.StreamResponse{status_update: update}, state)
         when not is_nil(update) do
      # Status updates may contain messages too
      if update.status && update.status.message do
        message_map = A2A.Types.Message.to_map(update.status.message)
        envelopes = DataPart.extract_envelopes(%{"message" => message_map})

        for envelope <- envelopes do
          json = Jason.encode!(envelope)
          dispatch_to_consumers(state.consumers, {:a2ui, json})
        end
      end

      state
    end

    defp process_stream_item(%A2A.Types.StreamResponse{task: task}, state)
         when not is_nil(task) do
      # Task updates - check for messages in history
      if task.history do
        for msg <- task.history do
          message_map = A2A.Types.Message.to_map(msg)
          envelopes = DataPart.extract_envelopes(%{"message" => message_map})

          for envelope <- envelopes do
            json = Jason.encode!(envelope)
            dispatch_to_consumers(state.consumers, {:a2ui, json})
          end
        end
      end

      state
    end

    defp process_stream_item(%A2A.Types.StreamError{error: error}, state) do
      Logger.warning("Stream error received: #{inspect(error)}")
      state
    end

    defp process_stream_item(_item, state), do: state

    defp update_last_event_id(state, %A2A.Types.Message{message_id: id}) when is_binary(id) do
      %{state | last_event_id: id}
    end

    defp update_last_event_id(state, _msg), do: state

    defp dispatch_to_consumers(consumers, message) do
      for {_surface_id, consumer} <- consumers do
        send(consumer, message)
      end
    end

    defp a2a_config_opts(state) do
      extension_uri = Protocol.extension_uri(state.protocol_version)

      [
        agent_card_path: "/.well-known/agent.json",
        legacy_extensions_header: true,
        extensions: [extension_uri],
        rest_base_path: "/a2a",
        subscribe_verb: :get,
        version: :v0_3,
        req_options: state.req_options
      ]
    end

    defp build_a2a_message(capabilities, content) do
      %A2A.Types.Message{
        role: :user,
        metadata: %{
          Protocol.client_capabilities_key() => ClientCapabilities.to_a2a_metadata(capabilities)
        },
        parts: [
          %A2A.Types.TextPart{
            kind: "text",
            text: content
          }
        ]
      }
    end
  else
    @impl true
    def init(_opts) do
      {:stop, {:missing_dependency, :a2a_ex}}
    end
  end
end
