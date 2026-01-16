defmodule A2UI.SSE.ProtocolTest do
  use ExUnit.Case, async: true

  alias A2UI.SSE.Protocol

  describe "content_type/0" do
    test "returns SSE content type" do
      assert Protocol.content_type() == "text/event-stream"
    end
  end

  describe "event_stream?/1" do
    test "returns true for exact match" do
      assert Protocol.event_stream?("text/event-stream")
    end

    test "returns true with charset suffix" do
      assert Protocol.event_stream?("text/event-stream; charset=utf-8")
    end

    test "returns true regardless of case" do
      assert Protocol.event_stream?("TEXT/EVENT-STREAM")
      assert Protocol.event_stream?("Text/Event-Stream")
    end

    test "returns false for other content types" do
      refute Protocol.event_stream?("application/json")
      refute Protocol.event_stream?("text/plain")
      refute Protocol.event_stream?("text/html")
    end

    test "returns false for nil" do
      refute Protocol.event_stream?(nil)
    end
  end

  describe "response_headers/1" do
    test "returns required SSE headers" do
      headers = Protocol.response_headers()

      assert {"content-type", "text/event-stream"} in headers
      assert {"cache-control", "no-cache"} in headers
      assert {"connection", "keep-alive"} in headers
    end

    test "excludes buffering header by default" do
      headers = Protocol.response_headers()
      refute Enum.any?(headers, fn {k, _} -> k == "x-accel-buffering" end)
    end

    test "includes buffering header when requested" do
      headers = Protocol.response_headers(disable_buffering: true)
      assert {"x-accel-buffering", "no"} in headers
    end
  end

  describe "request_headers/0" do
    test "returns accept header for SSE" do
      headers = Protocol.request_headers()
      assert {"accept", "text/event-stream"} in headers
    end
  end

  describe "request_headers_with_resume/1" do
    test "includes Last-Event-ID when provided" do
      headers = Protocol.request_headers_with_resume("event-42")

      assert {"accept", "text/event-stream"} in headers
      assert {"last-event-id", "event-42"} in headers
    end

    test "omits Last-Event-ID when nil" do
      headers = Protocol.request_headers_with_resume(nil)

      assert {"accept", "text/event-stream"} in headers
      refute Enum.any?(headers, fn {k, _} -> k == "last-event-id" end)
    end
  end

  describe "default_retry_ms/0" do
    test "returns 2000ms per spec" do
      assert Protocol.default_retry_ms() == 2000
    end
  end
end
