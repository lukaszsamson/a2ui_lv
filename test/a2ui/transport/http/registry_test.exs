defmodule A2UI.Transport.HTTP.RegistryTest do
  use ExUnit.Case, async: true

  alias A2UI.Transport.HTTP.Registry

  setup do
    # Start a test PubSub and Registry for each test
    pubsub_name = :"test_pubsub_#{System.unique_integer([:positive])}"
    registry_name = :"test_registry_#{System.unique_integer([:positive])}"

    start_supervised!({Phoenix.PubSub, name: pubsub_name})

    {:ok, _registry} =
      start_supervised({Registry, pubsub: pubsub_name, name: registry_name})

    %{pubsub: pubsub_name, registry: registry_name}
  end

  describe "create_session/2" do
    test "creates a session with auto-generated ID", %{registry: registry} do
      {:ok, session_id} = Registry.create_session(registry)

      assert is_binary(session_id)
      assert String.length(session_id) > 0
    end

    test "creates a session with custom ID", %{registry: registry} do
      {:ok, session_id} = Registry.create_session(registry, id: "my-custom-id")

      assert session_id == "my-custom-id"
    end

    test "creates a session with metadata", %{registry: registry} do
      {:ok, session_id} = Registry.create_session(registry, metadata: %{prompt: "test"})

      {:ok, session} = Registry.get_session(registry, session_id)
      assert session.metadata == %{prompt: "test"}
    end
  end

  describe "get_session/2" do
    test "returns session info for existing session", %{registry: registry} do
      {:ok, session_id} = Registry.create_session(registry, metadata: %{foo: "bar"})

      {:ok, session} = Registry.get_session(registry, session_id)

      assert session.id == session_id
      assert session.metadata == %{foo: "bar"}
      assert %DateTime{} = session.created_at
    end

    test "returns error for non-existent session", %{registry: registry} do
      assert {:error, :not_found} = Registry.get_session(registry, "nonexistent")
    end
  end

  describe "session_exists?/2" do
    test "returns true for existing session", %{registry: registry} do
      {:ok, session_id} = Registry.create_session(registry)

      assert Registry.session_exists?(registry, session_id)
    end

    test "returns false for non-existent session", %{registry: registry} do
      refute Registry.session_exists?(registry, "nonexistent")
    end
  end

  describe "broadcast/3" do
    test "broadcasts message to subscribed consumers", %{registry: registry, pubsub: pubsub} do
      {:ok, session_id} = Registry.create_session(registry)

      # Subscribe to session topic
      topic = Registry.topic(registry, session_id)
      Phoenix.PubSub.subscribe(pubsub, topic)

      # Broadcast message
      :ok = Registry.broadcast(registry, session_id, ~s({"test": 1}))

      # Should receive the message
      assert_receive {:a2ui, ~s({"test": 1})}
    end

    test "returns error for non-existent session", %{registry: registry} do
      assert {:error, :not_found} = Registry.broadcast(registry, "nonexistent", "data")
    end
  end

  describe "broadcast_done/3" do
    test "broadcasts done message", %{registry: registry, pubsub: pubsub} do
      {:ok, session_id} = Registry.create_session(registry)

      topic = Registry.topic(registry, session_id)
      Phoenix.PubSub.subscribe(pubsub, topic)

      :ok = Registry.broadcast_done(registry, session_id, %{count: 5})

      assert_receive {:a2ui_stream_done, %{count: 5}}
    end
  end

  describe "broadcast_error/3" do
    test "broadcasts error message", %{registry: registry, pubsub: pubsub} do
      {:ok, session_id} = Registry.create_session(registry)

      topic = Registry.topic(registry, session_id)
      Phoenix.PubSub.subscribe(pubsub, topic)

      :ok = Registry.broadcast_error(registry, session_id, :timeout)

      assert_receive {:a2ui_stream_error, :timeout}
    end
  end

  describe "close_session/2" do
    test "removes session from registry", %{registry: registry} do
      {:ok, session_id} = Registry.create_session(registry)
      assert Registry.session_exists?(registry, session_id)

      :ok = Registry.close_session(registry, session_id)

      refute Registry.session_exists?(registry, session_id)
    end
  end

  describe "list_sessions/1" do
    test "returns all sessions", %{registry: registry} do
      {:ok, id1} = Registry.create_session(registry)
      {:ok, id2} = Registry.create_session(registry)

      sessions = Registry.list_sessions(registry)

      assert length(sessions) == 2
      ids = Enum.map(sessions, & &1.id)
      assert id1 in ids
      assert id2 in ids
    end
  end
end
