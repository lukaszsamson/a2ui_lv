defmodule A2UI.SSE.StreamStateTest do
  use ExUnit.Case, async: true

  alias A2UI.SSE.StreamState
  alias A2UI.SSE.Event

  describe "new/1" do
    test "creates state with defaults" do
      state = StreamState.new()

      assert state.url == nil
      assert state.surface_id == nil
      assert state.retry_ms == 2000
      assert state.connected == false
      assert state.buffer == ""
      assert state.messages_received == 0
    end

    test "accepts options" do
      state = StreamState.new(url: "http://test/stream", surface_id: "main", retry_ms: 5000)

      assert state.url == "http://test/stream"
      assert state.surface_id == "main"
      assert state.retry_ms == 5000
    end
  end

  describe "mark_connected/1" do
    test "sets connected to true" do
      state = StreamState.new() |> StreamState.mark_connected()
      assert state.connected == true
    end

    test "sets connected_at timestamp" do
      state = StreamState.new() |> StreamState.mark_connected()
      assert %DateTime{} = state.connected_at
    end
  end

  describe "mark_disconnected/1" do
    test "sets connected to false" do
      state =
        StreamState.new()
        |> StreamState.mark_connected()
        |> StreamState.mark_disconnected()

      assert state.connected == false
    end

    test "clears buffer" do
      state = %StreamState{buffer: "partial data", connected: true}
      state = StreamState.mark_disconnected(state)
      assert state.buffer == ""
    end

    test "preserves last_event_id for resumption" do
      state = %StreamState{last_event_id: "42", connected: true}
      state = StreamState.mark_disconnected(state)
      assert state.last_event_id == "42"
    end

    test "preserves retry_ms" do
      state = %StreamState{retry_ms: 5000, connected: true}
      state = StreamState.mark_disconnected(state)
      assert state.retry_ms == 5000
    end
  end

  describe "update_from_event/2" do
    test "updates last_event_id" do
      event = %Event{id: "event-42", data: "{}"}
      state = StreamState.new() |> StreamState.update_from_event(event)
      assert state.last_event_id == "event-42"
    end

    test "updates retry_ms" do
      event = %Event{retry: 10000, data: "{}"}
      state = StreamState.new() |> StreamState.update_from_event(event)
      assert state.retry_ms == 10000
    end

    test "increments messages_received" do
      event = %Event{data: "{}"}
      state = StreamState.new()

      state = StreamState.update_from_event(state, event)
      assert state.messages_received == 1

      state = StreamState.update_from_event(state, event)
      assert state.messages_received == 2
    end

    test "sets last_message_at" do
      event = %Event{data: "{}"}
      state = StreamState.new() |> StreamState.update_from_event(event)
      assert %DateTime{} = state.last_message_at
    end

    test "preserves existing values when event fields are nil" do
      state = %StreamState{last_event_id: "old", retry_ms: 3000}
      event = %Event{id: nil, retry: nil, data: "{}"}

      state = StreamState.update_from_event(state, event)
      assert state.last_event_id == "old"
      assert state.retry_ms == 3000
    end
  end

  describe "process_chunk/2" do
    test "parses complete events from chunk" do
      state = StreamState.new()
      chunk = "data: {\"a\":1}\n\ndata: {\"b\":2}\n\n"

      {events, state} = StreamState.process_chunk(state, chunk)

      assert length(events) == 2
      assert state.messages_received == 2
    end

    test "buffers incomplete events" do
      state = StreamState.new()
      chunk = "data: {\"complete\":true}\n\ndata: {\"incom"

      {events, state} = StreamState.process_chunk(state, chunk)

      assert length(events) == 1
      assert state.buffer == "data: {\"incom"
    end

    test "continues from previous buffer" do
      state = %StreamState{buffer: "data: {\"partial\":"}
      chunk = "true}\n\n"

      {events, state} = StreamState.process_chunk(state, chunk)

      assert length(events) == 1
      assert Enum.at(events, 0).data == "{\"partial\":true}"
      assert state.buffer == ""
    end

    test "tracks bytes_received" do
      state = StreamState.new()
      chunk = "data: {}\n\n"

      {_events, state} = StreamState.process_chunk(state, chunk)
      assert state.bytes_received == byte_size(chunk)

      {_events, state} = StreamState.process_chunk(state, chunk)
      assert state.bytes_received == byte_size(chunk) * 2
    end

    test "updates state from events with ids" do
      state = StreamState.new()
      chunk = "id: 1\ndata: {}\n\nid: 2\ndata: {}\n\n"

      {_events, state} = StreamState.process_chunk(state, chunk)
      assert state.last_event_id == "2"
    end
  end

  describe "reconnect_headers/1" do
    test "includes Last-Event-ID when available" do
      state = %StreamState{last_event_id: "event-99"}
      headers = StreamState.reconnect_headers(state)

      assert {"accept", "text/event-stream"} in headers
      assert {"last-event-id", "event-99"} in headers
    end

    test "omits Last-Event-ID when not set" do
      state = StreamState.new()
      headers = StreamState.reconnect_headers(state)

      assert {"accept", "text/event-stream"} in headers
      refute Enum.any?(headers, fn {k, _} -> k == "last-event-id" end)
    end
  end

  describe "retry_delay/1" do
    test "returns server-provided retry" do
      state = %StreamState{retry_ms: 10000}
      assert StreamState.retry_delay(state) == 10000
    end

    test "returns default when retry_ms is nil" do
      state = %StreamState{retry_ms: nil}
      assert StreamState.retry_delay(state) == 2000
    end
  end

  describe "completion_meta/1" do
    test "returns stream statistics" do
      state =
        StreamState.new(surface_id: "main")
        |> StreamState.mark_connected()
        |> Map.put(:messages_received, 42)
        |> Map.put(:bytes_received, 1234)
        |> Map.put(:last_event_id, "final-event")

      meta = StreamState.completion_meta(state)

      assert meta.messages_received == 42
      assert meta.bytes_received == 1234
      assert meta.last_event_id == "final-event"
      assert meta.surface_id == "main"
      assert is_integer(meta.duration_ms)
    end

    test "handles nil connected_at" do
      state = StreamState.new()
      meta = StreamState.completion_meta(state)
      assert meta.duration_ms == nil
    end
  end
end
