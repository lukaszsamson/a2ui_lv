defmodule A2UI.Transport.Local do
  @moduledoc """
  Local (in-process) transport implementation for A2UI.

  This transport is useful for:
  - Testing without network dependencies
  - Demo applications where agent and renderer run in the same BEAM node
  - Development and debugging

  It implements both `A2UI.Transport.UIStream` and `A2UI.Transport.Events`
  behaviours, routing messages directly between processes.

  ## Usage

      # Start the local transport
      {:ok, transport} = A2UI.Transport.Local.start_link(
        event_handler: fn event -> handle_event(event) end
      )

      # Open a stream to receive UI messages
      :ok = A2UI.Transport.Local.open(transport, "main", self(), [])

      # Send UI messages (typically called by agent/generator)
      :ok = A2UI.Transport.Local.send_ui_message(transport, "main", json_line)

      # Send events back to server
      :ok = A2UI.Transport.Local.send_event(transport, user_action, [])

  ## Architecture

  The local transport maintains a registry of surface_id → consumer mappings.
  When `send_ui_message/3` is called, it looks up the consumer and delivers
  the message directly. Events are passed to the configured `event_handler`.
  """

  @behaviour A2UI.Transport.UIStream
  @behaviour A2UI.Transport.Events

  use GenServer

  defstruct streams: %{},
            event_handler: nil

  # ============================================
  # Client API
  # ============================================

  @doc """
  Starts the local transport process.

  ## Options

  - `:name` - Optional process name
  - `:event_handler` - Function to handle outgoing events: `(event_envelope) -> :ok | {:error, term()}`
  """
  @impl A2UI.Transport.UIStream
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Opens a stream for a surface to a consumer process.

  The consumer will receive `{:a2ui, json_line}` messages when
  `send_ui_message/3` is called for this surface.
  """
  @impl A2UI.Transport.UIStream
  def open(pid, surface_id, consumer, _opts \\ []) do
    GenServer.call(pid, {:open, surface_id, consumer})
  end

  @doc """
  Closes a stream for a surface.

  The consumer will receive `{:a2ui_stream_done, %{}}` before removal.
  """
  @impl A2UI.Transport.UIStream
  def close(pid, surface_id) do
    GenServer.call(pid, {:close, surface_id})
  end

  @doc """
  Sends a UI message to the consumer registered for a surface.

  This is called by the agent/generator side to deliver messages.

  ## Returns

  - `:ok` - Message delivered
  - `{:error, :no_consumer}` - No consumer registered for this surface
  """
  @spec send_ui_message(pid(), String.t(), String.t()) :: :ok | {:error, :no_consumer}
  def send_ui_message(pid, surface_id, json_line) do
    GenServer.call(pid, {:send_ui_message, surface_id, json_line})
  end

  @doc """
  Sends multiple UI messages to a surface consumer.

  Convenience function for sending a batch of messages.
  """
  @spec send_ui_messages(pid(), String.t(), [String.t()]) :: :ok | {:error, :no_consumer}
  def send_ui_messages(pid, surface_id, json_lines) when is_list(json_lines) do
    Enum.reduce_while(json_lines, :ok, fn line, _acc ->
      case send_ui_message(pid, surface_id, line) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @doc """
  Sends an event envelope to the configured event handler.
  """
  @impl A2UI.Transport.Events
  def send_event(pid, event_envelope, _opts \\ []) do
    GenServer.call(pid, {:send_event, event_envelope})
  end

  @doc """
  Checks if the transport has any active streams.
  """
  @impl A2UI.Transport.UIStream
  def connected?(pid) do
    GenServer.call(pid, :connected?)
  end

  @doc """
  Lists all active surface streams.
  """
  @spec list_streams(pid()) :: [String.t()]
  def list_streams(pid) do
    GenServer.call(pid, :list_streams)
  end

  @doc """
  Signals stream completion for a surface.

  Sends `{:a2ui_stream_done, meta}` to the consumer.
  """
  @spec complete_stream(pid(), String.t(), map()) :: :ok | {:error, :no_consumer}
  def complete_stream(pid, surface_id, meta \\ %{}) do
    GenServer.call(pid, {:complete_stream, surface_id, meta})
  end

  @doc """
  Signals a stream error for a surface.

  Sends `{:a2ui_stream_error, reason}` to the consumer.
  """
  @spec stream_error(pid(), String.t(), term()) :: :ok | {:error, :no_consumer}
  def stream_error(pid, surface_id, reason) do
    GenServer.call(pid, {:stream_error, surface_id, reason})
  end

  # ============================================
  # GenServer Callbacks
  # ============================================

  @impl GenServer
  def init(opts) do
    event_handler = Keyword.get(opts, :event_handler, fn _ -> :ok end)

    {:ok,
     %__MODULE__{
       streams: %{},
       event_handler: event_handler
     }}
  end

  @impl GenServer
  def handle_call({:open, surface_id, consumer}, _from, state) do
    # Monitor the consumer so we can clean up if it dies
    Process.monitor(consumer)

    streams = Map.put(state.streams, surface_id, consumer)
    {:reply, :ok, %{state | streams: streams}}
  end

  def handle_call({:close, surface_id}, _from, state) do
    case Map.get(state.streams, surface_id) do
      nil ->
        {:reply, :ok, state}

      consumer ->
        send(consumer, {:a2ui_stream_done, %{}})
        streams = Map.delete(state.streams, surface_id)
        {:reply, :ok, %{state | streams: streams}}
    end
  end

  def handle_call({:send_ui_message, surface_id, json_line}, _from, state) do
    case Map.get(state.streams, surface_id) do
      nil ->
        {:reply, {:error, :no_consumer}, state}

      consumer ->
        send(consumer, {:a2ui, json_line})
        {:reply, :ok, state}
    end
  end

  def handle_call({:send_event, event_envelope}, _from, state) do
    result =
      case A2UI.Transport.Events.validate_envelope(event_envelope) do
        :ok ->
          state.event_handler.(event_envelope)

        error ->
          error
      end

    {:reply, result, state}
  end

  def handle_call(:connected?, _from, state) do
    {:reply, map_size(state.streams) > 0, state}
  end

  def handle_call(:list_streams, _from, state) do
    {:reply, Map.keys(state.streams), state}
  end

  def handle_call({:complete_stream, surface_id, meta}, _from, state) do
    case Map.get(state.streams, surface_id) do
      nil ->
        {:reply, {:error, :no_consumer}, state}

      consumer ->
        send(consumer, {:a2ui_stream_done, meta})
        streams = Map.delete(state.streams, surface_id)
        {:reply, :ok, %{state | streams: streams}}
    end
  end

  def handle_call({:stream_error, surface_id, reason}, _from, state) do
    case Map.get(state.streams, surface_id) do
      nil ->
        {:reply, {:error, :no_consumer}, state}

      consumer ->
        send(consumer, {:a2ui_stream_error, reason})
        {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove any streams for the dead consumer
    streams =
      state.streams
      |> Enum.reject(fn {_surface_id, consumer} -> consumer == pid end)
      |> Map.new()

    {:noreply, %{state | streams: streams}}
  end
end
