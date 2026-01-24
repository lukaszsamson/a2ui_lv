defmodule A2UI.Transport.HTTP.Registry do
  @moduledoc """
  Session registry for HTTP+SSE transport.

  Manages active sessions and broadcasts A2UI messages to connected SSE clients
  via PubSub. Each session has a unique ID and can have multiple connected
  consumers (SSE streams).

  ## Usage

  Add to your supervision tree:

      children = [
        {Phoenix.PubSub, name: MyApp.PubSub},
        {A2UI.Transport.HTTP.Registry, pubsub: MyApp.PubSub}
      ]

  Create a session and broadcast messages:

      {:ok, session_id} = A2UI.Transport.HTTP.Registry.create_session()
      :ok = A2UI.Transport.HTTP.Registry.broadcast(session_id, json_line)

  ## PubSub Topics

  Messages are broadcast to: `"a2ui:session:<session_id>"`

  The message format is: `{:a2ui, json_line}`
  """

  use GenServer
  require Logger

  @type session_id :: String.t()
  @type session :: %{
          id: session_id(),
          created_at: DateTime.t(),
          metadata: map()
        }

  defstruct [:pubsub, :topic_prefix, sessions: %{}]

  @default_topic_prefix "a2ui:session:"

  # ============================================
  # Client API
  # ============================================

  @doc """
  Starts the registry.

  ## Options

  - `:pubsub` - Required. The PubSub module to use for broadcasting
  - `:topic_prefix` - Topic prefix for sessions (default: "a2ui:session:")
  - `:name` - Process name (default: `__MODULE__`)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Creates a new session.

  Returns `{:ok, session_id}` where `session_id` is a unique identifier.

  ## Options

  - `:id` - Custom session ID (default: auto-generated UUID)
  - `:metadata` - Arbitrary metadata to associate with the session
  """
  @spec create_session(keyword()) :: {:ok, session_id()}
  @spec create_session(GenServer.server(), keyword()) :: {:ok, session_id()}
  def create_session(server \\ __MODULE__, opts \\ []) do
    GenServer.call(server, {:create_session, opts})
  end

  @doc """
  Gets session information.

  Returns `{:ok, session}` if found, or `{:error, :not_found}`.
  """
  @spec get_session(session_id()) :: {:ok, session()} | {:error, :not_found}
  @spec get_session(GenServer.server(), session_id()) :: {:ok, session()} | {:error, :not_found}
  def get_session(server \\ __MODULE__, session_id) do
    GenServer.call(server, {:get_session, session_id})
  end

  @doc """
  Checks if a session exists.
  """
  @spec session_exists?(session_id()) :: boolean()
  @spec session_exists?(GenServer.server(), session_id()) :: boolean()
  def session_exists?(server \\ __MODULE__, session_id) do
    GenServer.call(server, {:session_exists?, session_id})
  end

  @doc """
  Broadcasts a JSON line to all consumers of a session.

  The message is sent via PubSub to the topic `"a2ui:session:<session_id>"`.
  Consumers receive `{:a2ui, json_line}`.

  Returns `:ok` if the session exists, or `{:error, :not_found}`.
  """
  @spec broadcast(session_id(), String.t()) :: :ok | {:error, :not_found}
  @spec broadcast(GenServer.server(), session_id(), String.t()) :: :ok | {:error, :not_found}
  def broadcast(server \\ __MODULE__, session_id, json_line) do
    GenServer.call(server, {:broadcast, session_id, json_line})
  end

  @doc """
  Broadcasts stream completion to all consumers of a session.

  Consumers receive `{:a2ui_stream_done, meta}`.
  """
  @spec broadcast_done(session_id(), map()) :: :ok | {:error, :not_found}
  @spec broadcast_done(GenServer.server(), session_id(), map()) :: :ok | {:error, :not_found}
  def broadcast_done(server \\ __MODULE__, session_id, meta \\ %{}) do
    GenServer.call(server, {:broadcast_done, session_id, meta})
  end

  @doc """
  Broadcasts a stream error to all consumers of a session.

  Consumers receive `{:a2ui_stream_error, reason}`.
  """
  @spec broadcast_error(session_id(), term()) :: :ok | {:error, :not_found}
  @spec broadcast_error(GenServer.server(), session_id(), term()) :: :ok | {:error, :not_found}
  def broadcast_error(server \\ __MODULE__, session_id, reason) do
    GenServer.call(server, {:broadcast_error, session_id, reason})
  end

  @doc """
  Closes a session.

  This removes the session from the registry. Any connected SSE clients
  will stop receiving messages.
  """
  @spec close_session(session_id()) :: :ok
  @spec close_session(GenServer.server(), session_id()) :: :ok
  def close_session(server \\ __MODULE__, session_id) do
    GenServer.call(server, {:close_session, session_id})
  end

  @doc """
  Returns the PubSub topic for a session.

  This can be used by SSE servers to subscribe to session messages.
  """
  @spec topic(session_id()) :: String.t()
  @spec topic(GenServer.server(), session_id()) :: String.t()
  def topic(server \\ __MODULE__, session_id) do
    GenServer.call(server, {:topic, session_id})
  end

  @doc """
  Returns the PubSub module used by this registry.
  """
  @spec pubsub(GenServer.server()) :: module()
  def pubsub(server \\ __MODULE__) do
    GenServer.call(server, :pubsub)
  end

  @doc """
  Lists all active sessions.
  """
  @spec list_sessions() :: [session()]
  @spec list_sessions(GenServer.server()) :: [session()]
  def list_sessions(server \\ __MODULE__) do
    GenServer.call(server, :list_sessions)
  end

  # ============================================
  # GenServer Callbacks
  # ============================================

  @impl true
  def init(opts) do
    pubsub = Keyword.fetch!(opts, :pubsub)
    topic_prefix = Keyword.get(opts, :topic_prefix, @default_topic_prefix)

    {:ok,
     %__MODULE__{
       pubsub: pubsub,
       topic_prefix: topic_prefix,
       sessions: %{}
     }}
  end

  @impl true
  def handle_call({:create_session, opts}, _from, state) do
    session_id = Keyword.get_lazy(opts, :id, &generate_session_id/0)
    metadata = Keyword.get(opts, :metadata, %{})

    session = %{
      id: session_id,
      created_at: DateTime.utc_now(),
      metadata: metadata
    }

    sessions = Map.put(state.sessions, session_id, session)
    Logger.debug("Created HTTP transport session: #{session_id}")

    {:reply, {:ok, session_id}, %{state | sessions: sessions}}
  end

  def handle_call({:get_session, session_id}, _from, state) do
    result =
      case Map.fetch(state.sessions, session_id) do
        {:ok, session} -> {:ok, session}
        :error -> {:error, :not_found}
      end

    {:reply, result, state}
  end

  def handle_call({:session_exists?, session_id}, _from, state) do
    {:reply, Map.has_key?(state.sessions, session_id), state}
  end

  def handle_call({:broadcast, session_id, json_line}, _from, state) do
    result =
      if Map.has_key?(state.sessions, session_id) do
        topic = state.topic_prefix <> session_id
        Phoenix.PubSub.broadcast(state.pubsub, topic, {:a2ui, json_line})
        :ok
      else
        {:error, :not_found}
      end

    {:reply, result, state}
  end

  def handle_call({:broadcast_done, session_id, meta}, _from, state) do
    result =
      if Map.has_key?(state.sessions, session_id) do
        topic = state.topic_prefix <> session_id
        Phoenix.PubSub.broadcast(state.pubsub, topic, {:a2ui_stream_done, meta})
        :ok
      else
        {:error, :not_found}
      end

    {:reply, result, state}
  end

  def handle_call({:broadcast_error, session_id, reason}, _from, state) do
    result =
      if Map.has_key?(state.sessions, session_id) do
        topic = state.topic_prefix <> session_id
        Phoenix.PubSub.broadcast(state.pubsub, topic, {:a2ui_stream_error, reason})
        :ok
      else
        {:error, :not_found}
      end

    {:reply, result, state}
  end

  def handle_call({:close_session, session_id}, _from, state) do
    sessions = Map.delete(state.sessions, session_id)
    Logger.debug("Closed HTTP transport session: #{session_id}")
    {:reply, :ok, %{state | sessions: sessions}}
  end

  def handle_call({:topic, session_id}, _from, state) do
    {:reply, state.topic_prefix <> session_id, state}
  end

  def handle_call(:pubsub, _from, state) do
    {:reply, state.pubsub, state}
  end

  def handle_call(:list_sessions, _from, state) do
    {:reply, Map.values(state.sessions), state}
  end

  # ============================================
  # Private Helpers
  # ============================================

  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
  end
end
