# A2UI LiveView

A2UI LiveView is a Phoenix LiveView renderer and session engine for the Agent-to-UI [A2UI](https://a2ui.org/) protocol. It consumes JSONL protocol messages and renders declarative UIs in real time, while forwarding user actions back to your agent or backend.

It supports protocol [v0.8 (stable)](https://a2ui.org/specification/v0.8-a2ui/) and [v0.9 (draft)](https://a2ui.org/specification/v0.9-a2ui/), including version-aware catalog negotiation, action envelopes, data model broadcasting and [A2UI Extension for A2A Protocol](https://a2ui.org/specification/v0.8-a2a-extension/).

## Features

- Parse and apply A2UI JSONL messages with `A2UI.Session`.
- Render surfaces in LiveView via `A2UI.Phoenix.Live`.
- Standard Phoenix catalog with layout, display, and input components.
- Two-way data binding for inputs and version-aware user action envelopes.
- Optional event transport for forwarding actions/errors to external agents.

## Quickstart

Add a LiveView that delegates A2UI events to `A2UI.Phoenix.Live` and stream JSONL lines into the session.

```elixir
defmodule MyAppWeb.AgentUiLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, A2UI.Phoenix.Live.init(socket)}
  end

  def handle_info({:a2ui, json_line}, socket) do
    A2UI.Phoenix.Live.handle_a2ui_message({:a2ui, json_line}, socket)
  end

  def handle_event("a2ui:" <> _ = event, params, socket) do
    A2UI.Phoenix.Live.handle_a2ui_event(event, params, socket)
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <A2UI.Phoenix.LiveView.render surfaces={@a2ui_surfaces} />
    </Layouts.app>
    """
  end
end
```

To push protocol messages into the LiveView, send JSONL lines into the mailbox:

```elixir
send(pid, {:a2ui, json_line})
```

## Protocol Versions

The session detects the protocol version per surface and applies the correct envelopes:

- v0.8 uses `{"userAction": ...}` action envelopes.
- v0.9 uses `{"action": ...}` action envelopes and supports data model broadcasts.

Catalog negotiation is version-aware, so v0.8 and v0.9 clients can request the correct catalog identifiers.

## Demo

The demo application lives in `demo/` and shows both v0.8 and v0.9 flows with LiveView surfaces, plus an HTTP+SSE and A2A transport for external agents.

## Links

- A2UI docs: `docs/A2UI/docs`
- A2UI protocol specs: `docs/A2UI/specification`
- Demo app: `demo/`
