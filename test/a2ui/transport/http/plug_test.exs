defmodule A2UI.Transport.HTTP.PlugTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Plug.Test

  alias A2UI.Transport.HTTP.Plug, as: HTTPPlug
  alias A2UI.Transport.HTTP.Registry

  setup do
    pubsub_name = :"test_pubsub_#{System.unique_integer([:positive])}"
    registry_name = :"test_registry_#{System.unique_integer([:positive])}"

    start_supervised!({Phoenix.PubSub, name: pubsub_name})
    start_supervised!({Registry, pubsub: pubsub_name, name: registry_name})

    opts =
      HTTPPlug.init(
        pubsub: pubsub_name,
        registry: registry_name
      )

    %{opts: opts, pubsub: pubsub_name, registry: registry_name}
  end

  describe "POST /sessions" do
    test "creates a new session", %{opts: opts, registry: registry} do
      conn =
        conn(:post, "/sessions", %{"metadata" => %{"prompt" => "test"}})
        |> put_req_header("content-type", "application/json")
        |> HTTPPlug.call(opts)

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert is_binary(body["sessionId"])

      # Verify session was created
      assert Registry.session_exists?(registry, body["sessionId"])
    end
  end

  describe "POST /message" do
    test "broadcasts message to session", %{opts: opts, pubsub: pubsub, registry: registry} do
      # Create a session
      {:ok, session_id} = Registry.create_session(registry)

      # Subscribe to receive broadcasts
      topic = Registry.topic(registry, session_id)
      Phoenix.PubSub.subscribe(pubsub, topic)

      # POST a message
      conn =
        conn(:post, "/message", %{
          "sessionId" => session_id,
          "message" => ~s({"surfaceUpdate":{"surfaceId":"test"}})
        })
        |> put_req_header("content-type", "application/json")
        |> HTTPPlug.call(opts)

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["ok"] == true
      assert is_integer(body["eventId"])

      # Should receive the broadcast with event ID
      assert_receive {:a2ui, ~s({"surfaceUpdate":{"surfaceId":"test"}}), event_id}
      assert is_integer(event_id)
    end

    test "returns 404 for non-existent session", %{opts: opts} do
      conn =
        conn(:post, "/message", %{
          "sessionId" => "nonexistent",
          "message" => "{}"
        })
        |> put_req_header("content-type", "application/json")
        |> HTTPPlug.call(opts)

      assert conn.status == 404
    end

    test "returns 400 for missing parameters", %{opts: opts} do
      conn =
        conn(:post, "/message", %{})
        |> put_req_header("content-type", "application/json")
        |> HTTPPlug.call(opts)

      assert conn.status == 400
    end
  end

  describe "POST /events" do
    test "accepts events", %{opts: opts, registry: registry} do
      {:ok, session_id} = Registry.create_session(registry)

      conn =
        conn(:post, "/events", %{
          "sessionId" => session_id,
          "event" => %{"userAction" => %{"name" => "click"}}
        })
        |> put_req_header("content-type", "application/json")
        |> HTTPPlug.call(opts)

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"ok" => true}
    end

    test "returns 400 for missing parameters", %{opts: opts} do
      conn =
        conn(:post, "/events", %{})
        |> put_req_header("content-type", "application/json")
        |> HTTPPlug.call(opts)

      assert conn.status == 400
    end
  end

  describe "POST /done" do
    test "broadcasts stream done", %{opts: opts, pubsub: pubsub, registry: registry} do
      {:ok, session_id} = Registry.create_session(registry)

      topic = Registry.topic(registry, session_id)
      Phoenix.PubSub.subscribe(pubsub, topic)

      conn =
        conn(:post, "/done", %{
          "sessionId" => session_id,
          "meta" => %{"count" => 3}
        })
        |> put_req_header("content-type", "application/json")
        |> HTTPPlug.call(opts)

      assert conn.status == 200

      assert_receive {:a2ui_stream_done, %{"count" => 3}}
    end
  end

  describe "unknown routes" do
    test "returns 404", %{opts: opts} do
      conn = conn(:get, "/unknown") |> HTTPPlug.call(opts)
      assert conn.status == 404
    end
  end
end
