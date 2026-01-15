# A2UI Phoenix Renderer Library — v1 Design

This document plans how to split this repo into (1) an A2UI renderer library and (2) a demo/storybook app, and how to model “transports” in a way that matches the v0.8 protocol docs (`docs/A2UI/specification/v0_8/docs/a2ui_protocol.md`) and renderer guide (`docs/A2UI/docs/guides/renderer-development.md`).

## 1) Clarify responsibilities (spec-aligned)

Per the v0.8 protocol docs:

- **Renderer**: consumes a *server→client* JSONL stream (`surfaceUpdate`, `dataModelUpdate`, `beginRendering`, `deleteSurface`), buffers state, and renders surfaces once `beginRendering` arrives.
- **Event sender**: emits *client→server* single-event envelopes containing exactly one of `userAction` or `error`.
- **Transport**: a delivery mechanism. The spec explicitly calls out “one-way stream (often SSE) for UI updates” + “separate channel (often A2A) for events”.
- **Agent / generator**: decides what UI to send. This is *not* part of a renderer library. In this repo we currently co-locate “agent connectors” (Ollama HTTP, Claude bridge over ZMQ) for convenience; those should not live in the renderer library.

## 2) Target split (what becomes “the library”)

### 2.1 Packages (recommended end state)

An umbrella split makes the library extractable to Hex without forcing demo-only dependencies:

```
apps/
  a2ui_core/          # protocol + state machine, no Phoenix
  a2ui_phoenix/       # Phoenix LiveView renderer + standard catalog implementation
  a2ui_transport/     # transport behaviours + implementations (SSE/WebSocket/A2A/etc)
  a2ui_demo/          # storybook + interactive demos + local agent connectors
```

If an umbrella is too heavy right now, keep a single app but keep *namespacing* identical to the above so extraction is mostly file moves.

### 2.2 Module ownership (mapping from current code)

**Core (no Phoenix):**
- `A2UI.Messages.*` (wire message structs)
- `A2UI.Parser` (JSONL line parsing + message dispatch)
- `A2UI.Surface` (surface state: components buffer, data model, rootId, ready flag, styles, catalogId)
- `A2UI.Binding` (BoundValue resolution + JSON Pointer utilities)
- `A2UI.Validator` (limits + schema-adjacent checks)
- `A2UI.Error` (builds client→server `{"error": ...}` envelopes)
- `A2UI.V0_8` (constants: standard catalog id, schema references)
- `A2UI.V0_9.*` (optional adapters, if kept)

**Phoenix renderer (depends on `a2ui_core`):**
- `A2UI.Renderer` → rename to `A2UI.Phoenix.Renderer` (renders a surface; applies `beginRendering.styles`)
- `A2UI.Catalog.Standard` → rename to `A2UI.Phoenix.Catalog.Standard` (HEEx components; uses `<.icon>`, `<.input>`, etc.)
- `A2UI.Live` → rename to `A2UI.Phoenix.Live` (socket assigns, `handle_info`/`handle_event` helpers)

**Demo-only (stays out of the library):**
- `A2UI.StorybookSamples` (currently `lib/a2ui/storybook_samples.ex`)
- `A2UI.MockAgent` (demo scaffolding)
- `A2UI.OllamaClient`, `A2UI.Ollama.PromptBuilder` (agent connector + prompt/schema shaping)
- `A2UI.ClaudeClient` and `priv/claude_bridge/*` (agent connector + bridge process)
- `A2uiLvWeb.StorybookLive`, `A2uiLvWeb.DemoLive`

Rationale: the renderer library should not ship “how to talk to an LLM” or “storybook example payloads”; those are app concerns.

## 3) State machine API (library boundary)

The renderer guide describes a state machine that:
- buffers `surfaceUpdate` + `dataModelUpdate`
- flips “ready” on `beginRendering` (root id + optional catalogId + optional styles)
- supports `deleteSurface`

In the library, model this as a pure state container so it’s usable outside Phoenix:

```elixir
defmodule A2UI.Session do
  @type t :: %__MODULE__{surfaces: %{String.t() => A2UI.Surface.t()}, ...}

  def new(opts \\ []), do: ...
  def apply_json_line(session, json_line), do: {:ok, session} | {:error, A2UI.Error.t()}
  def apply_message(session, %A2UI.Messages.SurfaceUpdate{} = msg), do: ...
  # etc.
end
```

Phoenix integration becomes a thin adapter that stores `session.surfaces` (or the whole session) in assigns.

## 4) Catalogs and negotiation

Per v0.8:
- `beginRendering.catalogId` selects the catalog for a surface.
- if omitted, the client **must** default to the standard catalog id for the protocol version.
- A2A metadata can include `a2uiClientCapabilities.supportedCatalogIds` + optional `inlineCatalogs` (if server accepts).

Library design:

1) `A2UI.Catalog.Registry` (core): maps `catalogId` → renderer-specific catalog module (for Phoenix: `A2UI.Phoenix.Catalog.*`).
2) `A2UI.ClientCapabilities` (core): holds `supported_catalog_ids` + `inline_catalogs`.
3) `A2UI.Phoenix.Renderer` selects the catalog per surface:
   - `surface.catalog_id || A2UI.V0_8.standard_catalog_id()`
   - lookup in registry; render error + fallback if unknown
4) Keep a TODO for “catalog negotiation” (client capabilities exchange is transport-level, not renderer-level).

## 5) Transport abstractions (spec-aligned)

The existing “transport = generate(prompt)” idea conflates **agent generation** with **message delivery**. The v0.8 docs separate:
- server→client UI message stream (often SSE / JSONL)
- client→server event messages (often A2A; could also be HTTP POST, WebSocket, etc.)

Model this as two behaviours:

### 5.1 `A2UI.Transport.UIStream` (server→client)

Responsibility: deliver an ordered JSONL stream and emit decoded lines to a consumer process.

Suggested contract:

```elixir
defmodule A2UI.Transport.UIStream do
  @callback start_link(opts :: keyword()) :: GenServer.on_start()
  @callback open(pid, surface_id :: String.t(), consumer :: pid(), opts :: keyword()) ::
              :ok | {:error, term()}
  @callback close(pid, surface_id :: String.t()) :: :ok
end
```

Delivery format to the consumer stays simple and transport-agnostic:
- `send(consumer, {:a2ui, json_line})`
- `send(consumer, {:a2ui_stream_error, reason})`
- `send(consumer, {:a2ui_stream_done, meta})`

### 5.2 `A2UI.Transport.Events` (client→server)

Responsibility: send *single-event* envelopes where the payload has exactly one top-level key: `userAction` or `error` (per `client_to_server.json` and `a2ui_protocol.md` section 5).

Suggested contract:

```elixir
defmodule A2UI.Transport.Events do
  @callback send_event(pid, event_envelope :: map(), opts :: keyword()) :: :ok | {:error, term()}
end
```

Transport implementations are free to wrap the event:
- A2A: wrap in an A2A message and include `metadata.a2uiClientCapabilities`.
- REST: POST raw `event_envelope` to an endpoint.
- WebSocket: send `event_envelope` as a frame.

### 5.3 Implementations to target

Renderer-facing (transport-only, spec-aligned):
- `A2UI.Transport.SSE` (UI stream) + `A2UI.Transport.REST` (events)
- `A2UI.Transport.WebSocket` (both directions over one channel)
- `A2UI.Transport.A2A` (events; UI stream could still be SSE, or A2A depending on system)

Demo-only “agent connectors” (not part of the renderer library):
- “Ollama over HTTP streaming” and “Claude bridge over ZMQ” can be implemented *on top of* the transport behaviours, but should live in `a2ui_demo` (or a separate `a2ui_agents` package) because they embed prompts, schemas, and provider quirks.

## 6) Data model representation (v0.8 strictness note)

The v0.8 wire schema (`docs/A2UI/specification/v0_8/json/server_to_client.json`) allows:
- `valueString`, `valueNumber`, `valueBoolean`, and `valueMap` (one-level adjacency list)
- no nested `valueMap` inside `valueMap`, and no `valueList`

The library should treat this as the “strict wire format” and:
- decode `dataModelUpdate.contents` exactly per schema
- treat deeper/nested structures as renderer-internal (built via multiple `dataModelUpdate` messages with `path`, or by agent-side conventions) rather than relying on nested `valueMap` on the wire

## 7) Extraction plan (incremental, low-risk)

1) **Move demo-only modules out of `A2UI.*`** (storybook samples, mock agent, demo LLM connectors) into `A2uiLv.Demo.*` (or equivalent) so the renderer library namespace stays clean.
2) **Rename Phoenix-coupled modules** to `A2UI.Phoenix.*` and make `a2ui_core` compile without Phoenix.
3) Introduce the two transport behaviours (`UIStream` + `Events`) and refactor demo connectors to implement them.
4) Add `A2UI.Catalog.Registry` + catalog selection by `beginRendering.catalogId` (keep TODO for negotiation).
5) Once stable, move `a2ui_core` + `a2ui_phoenix` into an umbrella or separate repo for Hex publishing.
