# A2UI LiveView Demo

This Phoenix application demonstrates rendering [A2UI](https://a2ui.org/) surfaces with LiveView for both protocol v0.8 and v0.9. It includes a simple HTTP+SSE and [A2A](https://a2a-protocol.org/latest/) transport so external agents can push JSONL messages into the LiveView session.

## Running the demo

```bash
cd demo
mix setup
mix phx.server
```

Then open:

- `http://localhost:4000/demo` for the v0.8 demo
- `http://localhost:4000/demo-v0.9` for the v0.9 demo
- `http://localhost:4000/storybook` for component previews

## Transport endpoint

The demo exposes an HTTP+SSE transport for pushing A2UI messages:

- `POST /a2ui/:session_id` to send JSONL
- `GET /a2ui/:session_id` to stream server events

## Optional LLM integrations

The demo can be wired to external agents (Claude, Ollama, etc.). If they are not running, tests may emit connection-refused warnings while still passing.

### Testing with Ollama

The demo can connect with locally running Ollama server and use LLM models for rendering A2UI protocol messages. Note that small models are not capable enough to reliably handle the protocol message schema.

### Testing with Claude Agent SDK

To showcase the A2UI protocol an agent using a decent LLM is required. Claude Opus 4.5 is able to render A2UI protocol reliably. `claude_bridge_http` and `claude_bridge_a2a` are example agents with an A2UI-friendly system prompt. They speak the A2UI protocol (JSONL messages) and are useful for testing end-to-end agent-driven UI flows without writing your own agent from scratch.

To use Claude, run either bridge alongside the demo and configure your Claude agent credentials.

HTTP+SSE bridge:

```bash
cd demo/priv/claude_bridge_http
npm install
npm start
```

A2A bridge:

```bash
cd demo/priv/claude_bridge_a2a
npm install
npm start
```

For setup details, see the official Claude agent SDK docs:

- https://platform.claude.com/docs/en/agent-sdk/overview
