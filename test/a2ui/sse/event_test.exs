defmodule A2UI.SSE.EventTest do
  use ExUnit.Case, async: true

  alias A2UI.SSE.Event

  describe "parse/1" do
    test "parses simple data event" do
      event_text = "data: {\"test\":1}\n\n"
      assert {:ok, event} = Event.parse(event_text)
      assert event.data == "{\"test\":1}"
      assert event.id == nil
      assert event.retry == nil
    end

    test "parses event with id" do
      event_text = "id: 42\ndata: {}\n\n"
      assert {:ok, event} = Event.parse(event_text)
      assert event.id == "42"
      assert event.data == "{}"
    end

    test "parses event with retry" do
      event_text = "retry: 5000\ndata: {}\n\n"
      assert {:ok, event} = Event.parse(event_text)
      assert event.retry == 5000
      assert event.data == "{}"
    end

    test "parses event with all fields" do
      event_text = "id: abc-123\nretry: 3000\nevent: message\ndata: {\"key\":\"value\"}\n\n"
      assert {:ok, event} = Event.parse(event_text)
      assert event.id == "abc-123"
      assert event.retry == 3000
      assert event.event_type == "message"
      assert event.data == "{\"key\":\"value\"}"
    end

    test "handles multi-line data" do
      event_text = "data: {\"multi\":\ndata: \"line\"}\n\n"
      assert {:ok, event} = Event.parse(event_text)
      assert event.data == "{\"multi\":\n\"line\"}"
    end

    test "ignores comments" do
      event_text = ": this is a comment\ndata: {}\n\n"
      assert {:ok, event} = Event.parse(event_text)
      assert event.data == "{}"
    end

    test "handles data with leading space" do
      event_text = "data: {\"spaced\": true}\n\n"
      assert {:ok, event} = Event.parse(event_text)
      assert event.data == "{\"spaced\": true}"
    end

    test "returns error for empty event" do
      assert {:error, :empty_event} = Event.parse("")
      assert {:error, :empty_event} = Event.parse("\n\n")
    end

    test "returns error for event without data" do
      assert {:error, :empty_event} = Event.parse("id: 123\nretry: 1000\n\n")
    end

    test "ignores invalid retry values" do
      event_text = "retry: not-a-number\ndata: {}\n\n"
      assert {:ok, event} = Event.parse(event_text)
      assert event.retry == nil
      assert event.data == "{}"
    end
  end

  describe "parse_stream/1" do
    test "parses multiple complete events" do
      data = "data: {\"a\":1}\n\ndata: {\"b\":2}\n\n"
      {events, buffer} = Event.parse_stream(data)

      assert length(events) == 2
      assert Enum.at(events, 0).data == "{\"a\":1}"
      assert Enum.at(events, 1).data == "{\"b\":2}"
      assert buffer == ""
    end

    test "returns incomplete data as buffer" do
      data = "data: {\"complete\":true}\n\ndata: {\"incomp"
      {events, buffer} = Event.parse_stream(data)

      assert length(events) == 1
      assert Enum.at(events, 0).data == "{\"complete\":true}"
      assert buffer == "data: {\"incomp"
    end

    test "returns empty list when no complete events" do
      data = "data: {\"incomplete"
      {events, buffer} = Event.parse_stream(data)

      assert events == []
      assert buffer == "data: {\"incomplete"
    end

    test "handles CRLF line endings" do
      data = "data: {\"a\":1}\r\n\r\ndata: {\"b\":2}\r\n\r\n"
      {events, buffer} = Event.parse_stream(data)

      assert length(events) == 2
      assert buffer == ""
    end

    test "processes events with ids for resumption" do
      data = "id: 1\ndata: {}\n\nid: 2\ndata: {}\n\n"
      {events, _buffer} = Event.parse_stream(data)

      assert Enum.at(events, 0).id == "1"
      assert Enum.at(events, 1).id == "2"
    end
  end

  describe "extract_payload/1" do
    test "returns data field from event" do
      {:ok, event} = Event.parse("data: {\"test\":true}\n\n")
      assert {:ok, "{\"test\":true}"} = Event.extract_payload(event)
    end

    test "returns error for event without data" do
      event = %Event{data: nil}
      assert {:error, :no_data} = Event.extract_payload(event)
    end
  end

  describe "format/2" do
    test "formats simple envelope" do
      envelope = %{"beginRendering" => %{"surfaceId" => "main", "root" => "root"}}
      result = Event.format(envelope)

      assert result =~ "data: "
      assert result =~ "\"beginRendering\""
      assert String.ends_with?(result, "\n\n")
    end

    test "formats with id" do
      result = Event.format(%{"test" => 1}, id: "42")
      assert result =~ "id: 42\n"
      assert result =~ "data: "
    end

    test "formats with retry" do
      result = Event.format(%{"test" => 1}, retry: 5000)
      assert result =~ "retry: 5000\n"
      assert result =~ "data: "
    end

    test "formats with all options" do
      result = Event.format(%{"test" => 1}, id: "event-1", retry: 3000)
      assert result =~ "id: event-1\n"
      assert result =~ "retry: 3000\n"
      assert result =~ "data: "
    end

    test "formats pre-encoded JSON string" do
      json = "{\"already\":\"encoded\"}"
      result = Event.format(json)
      assert result == "data: {\"already\":\"encoded\"}\n\n"
    end

    test "handles multi-line JSON" do
      json = "{\n  \"pretty\": true\n}"
      result = Event.format(json)
      assert result == "data: {\ndata:   \"pretty\": true\ndata: }\n\n"
    end
  end
end
