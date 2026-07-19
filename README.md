# A2UI LiveView

A2UI LiveView is a Phoenix LiveView renderer and session engine for the Agent-to-UI [A2UI](https://a2ui.org/) protocol. It consumes JSONL protocol messages and renders declarative UIs in real time, while forwarding user actions back to your agent or backend.

It supports A2UI [v0.8](https://a2ui.org/specification/v0.8-a2ui/), released [v0.9](https://a2ui.org/specification/v0.9-a2ui/), and [v0.9.1](https://a2ui.org/specification/v0.9.1-a2ui/), including the released Basic Catalog and A2A extension contracts.

The tested runtime matrix covers Elixir 1.16 through 1.20 on compatible Erlang/OTP 26 through 29 releases.

## Features

- Parse and apply A2UI JSONL messages with `A2UI.Session`.
- Render surfaces in LiveView via `A2UI.Phoenix.Live`.
- Complete released Basic Catalog renderer with layout, display, input, theme, action, and function support.
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
- Released v0.9 and v0.9.1 messages require a top-level `"version"`; actions use `{"version":"v0.9.1","action": ...}`.
- `createSurface.sendDataModel` enables versioned `a2uiClientDataModel` synchronization.
- Data-model metadata is limited to the surface that originated the outgoing event.
- v0.9 surface IDs are unique for the session lifetime; v0.9.1 permits reuse after `deleteSurface`.

Catalog negotiation is version-aware. v0.9 and v0.9.1 share the released Basic Catalog ID: `https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json`.

### Support matrix

| Protocol | Catalog support | Validation | A2A binding |
|---|---|---|---|
| v0.8 | Standard Catalog aliases | Legacy envelope validation and renderer safety checks | Legacy URI, MIME, and map payloads |
| v0.9 | Released Basic Catalog | Official Draft 2020-12 envelope and catalog schemas plus lifecycle/pointer checks | v0.9 URI, `application/a2ui+json`, ordered message arrays, `v0.9` capabilities |
| v0.9.1 | Released Basic Catalog | Official Draft 2020-12 envelope and catalog schemas plus v0.9.1 lifecycle/pointer rules | v0.9.1 URI, `application/a2ui+json`, ordered message arrays, `v0.9.1` capabilities |
| v0.9/v0.9.1 custom catalogs | Registered renderer modules with an accompanying catalog schema | The registered Draft 2020-12 catalog schema | Advertised only when explicitly included in client capabilities |

Inline catalogs are not advertised or accepted. Register a custom catalog with `A2UI.Catalog.Registry.register/3`, passing its ID, renderer module, and schema. Data-model synchronization is emitted only for the event's surface and only to the transport identity that created that surface.

For A2A, call version-aware APIs such as `A2UI.A2A.DataPart.wrap_envelopes(messages, :v0_9_1)`. Released DataParts use `application/a2ui+json` and contain ordered arrays; `A2UI.Session.apply_envelopes/2` applies each message atomically and continues after individual failures. The no-version DataPart APIs retain their v0.8 behavior for compatibility.

### Locale-aware catalog functions

`formatNumber`, `formatCurrency`, `formatDate`, and `pluralize` use Unicode CLDR data. English is compiled by default. Configure every locale your renderer serves before compiling the dependency, and select the active locale at runtime:

```elixir
# config/config.exs
config :a2ui_lv,
  locales: ["en", "pl", "de"],
  locale: "pl"
```

## Demo

The demo application lives in `demo/` and shows both v0.8 and v0.9 flows with LiveView surfaces, plus an HTTP+SSE and A2A transport for external agents.

## Links

- [A2UI docs](https://a2ui.org/)
- A2UI protocol specs:
  - [v0.8](https://a2ui.org/specification/v0.8-a2ui/)
  - [v0.9](https://a2ui.org/specification/v0.9-a2ui/)
  - [v0.9.1](https://a2ui.org/specification/v0.9.1-a2ui/)
  - [v0.9.1 A2A extension](https://a2ui.org/specification/v0.9.1-a2ui-extension-specification/)
- [A2A docs](https://a2a-protocol.org/latest/)
- Demo app: [demo]
