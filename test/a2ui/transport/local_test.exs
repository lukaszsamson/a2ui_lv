defmodule A2UI.Transport.LocalTest do
  use ExUnit.Case, async: true

  alias A2UI.Transport.Local

  describe "start_link/1" do
    test "starts the transport process" do
      assert {:ok, pid} = Local.start_link()
      assert Process.alive?(pid)
    end

    test "accepts name option" do
      assert {:ok, pid} = Local.start_link(name: :test_transport)
      assert Process.whereis(:test_transport) == pid
    end

    test "accepts event_handler option" do
      handler = fn _event -> :handled end
      assert {:ok, pid} = Local.start_link(event_handler: handler)
      assert Process.alive?(pid)
    end
  end

  describe "open/4 and close/2" do
    test "opens a stream for a surface" do
      {:ok, transport} = Local.start_link()

      assert :ok = Local.open(transport, "surface-1", self())
      assert Local.connected?(transport)
      assert "surface-1" in Local.list_streams(transport)
    end

    test "closes a stream and sends done message" do
      {:ok, transport} = Local.start_link()

      :ok = Local.open(transport, "surface-1", self())
      assert :ok = Local.close(transport, "surface-1")

      assert_receive {:a2ui_stream_done, %{}}
      refute "surface-1" in Local.list_streams(transport)
    end

    test "close is idempotent for nonexistent surface" do
      {:ok, transport} = Local.start_link()
      assert :ok = Local.close(transport, "nonexistent")
    end

    test "supports multiple surfaces" do
      {:ok, transport} = Local.start_link()

      :ok = Local.open(transport, "surface-1", self())
      :ok = Local.open(transport, "surface-2", self())

      streams = Local.list_streams(transport)
      assert length(streams) == 2
      assert "surface-1" in streams
      assert "surface-2" in streams
    end
  end

  describe "send_ui_message/3" do
    test "delivers message to consumer" do
      {:ok, transport} = Local.start_link()

      :ok = Local.open(transport, "test", self())

      json_line = ~s({"surfaceUpdate":{"surfaceId":"test","components":[]}})
      assert :ok = Local.send_ui_message(transport, "test", json_line)

      assert_receive {:a2ui, ^json_line}
    end

    test "returns error for unknown surface" do
      {:ok, transport} = Local.start_link()

      assert {:error, :no_consumer} =
               Local.send_ui_message(transport, "unknown", ~s({"test":"data"}))
    end

    test "delivers multiple messages in order" do
      {:ok, transport} = Local.start_link()

      :ok = Local.open(transport, "test", self())

      :ok = Local.send_ui_message(transport, "test", "line1")
      :ok = Local.send_ui_message(transport, "test", "line2")
      :ok = Local.send_ui_message(transport, "test", "line3")

      assert_receive {:a2ui, "line1"}
      assert_receive {:a2ui, "line2"}
      assert_receive {:a2ui, "line3"}
    end
  end

  describe "send_ui_messages/3" do
    test "sends batch of messages" do
      {:ok, transport} = Local.start_link()

      :ok = Local.open(transport, "test", self())

      lines = ["line1", "line2", "line3"]
      assert :ok = Local.send_ui_messages(transport, "test", lines)

      assert_receive {:a2ui, "line1"}
      assert_receive {:a2ui, "line2"}
      assert_receive {:a2ui, "line3"}
    end

    test "returns error if consumer not found" do
      {:ok, transport} = Local.start_link()

      assert {:error, :no_consumer} =
               Local.send_ui_messages(transport, "unknown", ["line1", "line2"])
    end
  end

  describe "send_event/3" do
    test "passes event to handler" do
      test_pid = self()

      handler = fn event ->
        send(test_pid, {:handled, event})
        :ok
      end

      {:ok, transport} = Local.start_link(event_handler: handler)

      event = %{
        "userAction" => %{
          "name" => "click",
          "surfaceId" => "test",
          "sourceComponentId" => "btn",
          "timestamp" => "2024-01-15T10:00:00Z",
          "context" => %{}
        }
      }

      assert :ok = Local.send_event(transport, event)

      assert_receive {:handled, ^event}
    end

    test "validates envelope before passing to handler" do
      {:ok, transport} = Local.start_link(event_handler: fn _ -> :ok end)

      # Invalid envelope with multiple keys
      invalid = %{"userAction" => %{}, "error" => %{}}
      assert {:error, :multiple_envelope_keys} = Local.send_event(transport, invalid)

      # Invalid envelope type
      invalid2 = %{"unknown" => %{}}
      assert {:error, :invalid_envelope_type} = Local.send_event(transport, invalid2)
    end

    test "accepts error envelopes" do
      test_pid = self()

      handler = fn event ->
        send(test_pid, {:handled, event})
        :ok
      end

      {:ok, transport} = Local.start_link(event_handler: handler)

      event = %{
        "error" => %{
          "type" => "validation_error",
          "message" => "Something went wrong",
          "surfaceId" => "test",
          "timestamp" => "2024-01-15T10:00:00Z"
        }
      }

      assert :ok = Local.send_event(transport, event)

      assert_receive {:handled, ^event}
    end
  end

  describe "connected?/1" do
    test "returns false when no streams" do
      {:ok, transport} = Local.start_link()
      refute Local.connected?(transport)
    end

    test "returns true when has streams" do
      {:ok, transport} = Local.start_link()
      :ok = Local.open(transport, "test", self())
      assert Local.connected?(transport)
    end
  end

  describe "complete_stream/3" do
    test "sends done message with metadata" do
      {:ok, transport} = Local.start_link()

      :ok = Local.open(transport, "test", self())

      meta = %{bytes_received: 1024, messages_count: 10}
      assert :ok = Local.complete_stream(transport, "test", meta)

      assert_receive {:a2ui_stream_done, ^meta}
      refute "test" in Local.list_streams(transport)
    end

    test "returns error for unknown surface" do
      {:ok, transport} = Local.start_link()

      assert {:error, :no_consumer} = Local.complete_stream(transport, "unknown", %{})
    end
  end

  describe "stream_error/3" do
    test "sends error message to consumer" do
      {:ok, transport} = Local.start_link()

      :ok = Local.open(transport, "test", self())

      reason = {:connection_error, "timeout"}
      assert :ok = Local.stream_error(transport, "test", reason)

      assert_receive {:a2ui_stream_error, ^reason}
    end

    test "returns error for unknown surface" do
      {:ok, transport} = Local.start_link()

      assert {:error, :no_consumer} = Local.stream_error(transport, "unknown", :timeout)
    end
  end

  describe "consumer process monitoring" do
    test "cleans up streams when consumer dies" do
      {:ok, transport} = Local.start_link()

      # Start a consumer process that we'll kill
      consumer =
        spawn(fn ->
          receive do
            :exit -> :ok
          end
        end)

      :ok = Local.open(transport, "test", consumer)
      assert "test" in Local.list_streams(transport)

      # Kill the consumer
      Process.exit(consumer, :kill)

      # Give the transport time to process the DOWN message
      Process.sleep(50)

      refute "test" in Local.list_streams(transport)
    end
  end
end
