# A2UI Phoenix Library v1.0 Design

This document outlines the architecture for separating the A2UI renderer library from the demo application, and designing an extensible transport abstraction layer.

## Overview

Based on the A2UI specification, the architecture separates three concerns:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Agents    │ --> │ Transports  │ --> │  Renderer   │
│ (LLM/A2UI   │     │ (Message    │     │ (Phoenix    │
│  Generators)│     │  Delivery)  │     │  LiveView)  │
└─────────────┘     └─────────────┘     └─────────────┘
```

- **Agents**: Generate A2UI JSONL messages (Claude, Ollama, custom LLMs)
- **Transports**: Deliver messages to clients (HTTP, WebSocket, SSE, ZMQ, A2A)
- **Renderer**: Parse messages, manage state, render native UI (Phoenix LiveView)

## Package Structure

### Option A: Monorepo with Umbrella App (Recommended)

```
a2ui_phoenix/
├── apps/
│   ├── a2ui/                    # Core renderer library (hex: a2ui_phoenix)
│   │   ├── lib/
│   │   │   └── a2ui/
│   │   │       ├── binding.ex
│   │   │       ├── catalog/
│   │   │       ├── component.ex
│   │   │       ├── error.ex
│   │   │       ├── initializers.ex
│   │   │       ├── live.ex
│   │   │       ├── messages/
│   │   │       ├── parser.ex
│   │   │       ├── renderer.ex
│   │   │       ├── surface.ex
│   │   │       ├── transport.ex        # Transport behaviour
│   │   │       ├── validator.ex
│   │   │       └── v0_8.ex
│   │   └── priv/
│   │       └── a2ui/
│   │           └── spec/
│   │
│   ├── a2ui_transports/          # Transport implementations (hex: a2ui_transports)
│   │   └── lib/
│   │       └── a2ui/
│   │           └── transports/
│   │               ├── ollama.ex
│   │               ├── claude_zmq.ex
│   │               ├── websocket.ex
│   │               ├── sse.ex
│   │               └── a2a.ex
│   │
│   └── a2ui_demo/                # Demo/Storybook app (not published)
│       └── lib/
│           ├── demo/
│           │   ├── mock_agent.ex
│           │   └── storybook_samples.ex
│           └── demo_web/
│               └── live/
│                   ├── demo_live.ex
│                   └── storybook_live.ex
│
└── config/
```

### Option B: Single Package with Optional Dependencies

```
a2ui_phoenix/
├── lib/
│   ├── a2ui/                     # Core (always included)
│   │   ├── binding.ex
│   │   ├── catalog/
│   │   ├── ...
│   │   └── transport.ex          # Behaviour only
│   │
│   └── a2ui/transports/          # Optional (via config)
│       ├── ollama.ex
│       ├── claude_zmq.ex
│       └── ...
│
└── priv/
```

## Module Organization

### Core Renderer (Required)

These modules form the core A2UI renderer and are always required:

```elixir
# lib/a2ui/
├── binding.ex          # BoundValue resolution (path, literal, combined)
├── component.ex        # Component struct definition
├── error.ex            # Client-to-server error message construction
├── initializers.ex     # Data model initialization from bound values
├── live.ex             # Phoenix LiveView integration (init, handle_info, handle_event)
├── parser.ex           # JSONL stream parsing and message dispatch
├── renderer.ex         # Component tree rendering to HEEx
├── surface.ex          # Surface state management (components, data_model, root)
├── validator.ex        # Message validation (limits, allowed types)
│
├── messages/
│   ├── begin_rendering.ex
│   ├── data_model_update.ex
│   ├── delete_surface.ex
│   └── surface_update.ex
│
├── catalog/
│   └── standard.ex     # v0.8 standard catalog component implementations
│
└── v0_8.ex             # v0.8 schema constants and helpers
```

### Transport Behaviour

A behaviour that defines how messages flow from agents to the renderer:

```elixir
defmodule A2UI.Transport do
  @moduledoc """
  Behaviour for A2UI message transports.

  Transports deliver A2UI JSONL messages from agents to clients.
  A2UI is transport-agnostic - any method that can send JSON works.
  """

  @doc """
  Start the transport connection.

  Returns {:ok, state} on success or {:error, reason} on failure.
  """
  @callback connect(opts :: keyword()) :: {:ok, term()} | {:error, term()}

  @doc """
  Send a user action to the agent.

  This is the client-to-server path for user interactions.
  """
  @callback send_action(state :: term(), action :: map()) :: :ok | {:error, term()}

  @doc """
  Generate A2UI messages from a user prompt.

  Returns generated messages or streams them via callback.
  """
  @callback generate(state :: term(), prompt :: String.t(), opts :: keyword()) ::
              {:ok, [String.t()]} | {:error, term()}

  @doc """
  Generate A2UI messages in response to a user action (follow-up).
  """
  @callback generate_with_action(
              state :: term(),
              original_prompt :: String.t(),
              user_action :: map(),
              data_model :: map(),
              opts :: keyword()
            ) :: {:ok, [String.t()]} | {:error, term()}

  @doc """
  Check if the transport is available/connected.
  """
  @callback available?(state :: term()) :: boolean()

  @doc """
  Disconnect and clean up resources.
  """
  @callback disconnect(state :: term()) :: :ok

  @optional_callbacks [send_action: 2, generate_with_action: 5]
end
```

### Transport Implementations

#### HTTP/REST Transport (Ollama-style)

```elixir
defmodule A2UI.Transports.HTTP do
  @behaviour A2UI.Transport

  @moduledoc """
  HTTP transport for A2UI agents that expose REST APIs.

  Supports both synchronous and streaming (SSE/NDJSON) responses.

  ## Configuration

      config :a2ui, A2UI.Transports.HTTP,
        base_url: "http://localhost:11434",
        timeout: 120_000
  """

  defstruct [:base_url, :timeout, :headers, :stream_handler]

  @impl true
  def connect(opts) do
    state = %__MODULE__{
      base_url: opts[:base_url] || "http://localhost:11434",
      timeout: opts[:timeout] || 120_000,
      headers: opts[:headers] || []
    }
    {:ok, state}
  end

  @impl true
  def generate(state, prompt, opts) do
    # POST to /api/generate with prompt
    # Parse JSONL response or stream via callback
  end

  @impl true
  def available?(state) do
    # HEAD or GET to health endpoint
  end

  @impl true
  def disconnect(_state), do: :ok
end
```

#### WebSocket Transport

```elixir
defmodule A2UI.Transports.WebSocket do
  @behaviour A2UI.Transport
  use WebSockex

  @moduledoc """
  WebSocket transport for bidirectional A2UI communication.

  ## Configuration

      config :a2ui, A2UI.Transports.WebSocket,
        url: "wss://agent.example.com/a2ui"
  """

  # Full duplex: receive surfaceUpdate/dataModelUpdate, send userAction
end
```

#### Server-Sent Events (SSE) Transport

```elixir
defmodule A2UI.Transports.SSE do
  @behaviour A2UI.Transport

  @moduledoc """
  SSE transport for server-push A2UI streams.

  Uses HTTP POST for userAction (client-to-server) and
  SSE stream for UI updates (server-to-client).
  """

  # Separate paths for send (POST) and receive (SSE stream)
end
```

#### ZeroMQ Transport (Claude Bridge)

```elixir
defmodule A2UI.Transports.ZeroMQ do
  @behaviour A2UI.Transport
  use GenServer

  @moduledoc """
  ZeroMQ DEALER transport for high-performance IPC.

  Connects to a ZMQ ROUTER (e.g., Claude Agent SDK bridge)
  for bidirectional async messaging.

  ## Configuration

      config :a2ui, A2UI.Transports.ZeroMQ,
        endpoint: "tcp://127.0.0.1:5555"
  """
end
```

#### A2A Protocol Transport

```elixir
defmodule A2UI.Transports.A2A do
  @behaviour A2UI.Transport

  @moduledoc """
  A2A (Agent2Agent) protocol transport.

  Wraps A2UI messages in A2A Message format with:
  - a2uiClientCapabilities metadata
  - Catalog negotiation
  - Security/auth via A2A

  ## Configuration

      config :a2ui, A2UI.Transports.A2A,
        agent_url: "https://agent.example.com/.well-known/agent.json",
        supported_catalogs: [
          "https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json"
        ]
  """

  # A2A Message wrapper with a2uiClientCapabilities
  # Catalog negotiation via supportedCatalogIds
end
```

### Transport Registry

A registry for managing multiple transports:

```elixir
defmodule A2UI.TransportRegistry do
  @moduledoc """
  Registry for managing multiple transport connections.

  Allows switching between transports at runtime.

  ## Example

      # Register transports
      A2UI.TransportRegistry.register(:ollama, A2UI.Transports.HTTP, base_url: "...")
      A2UI.TransportRegistry.register(:claude, A2UI.Transports.ZeroMQ, endpoint: "...")

      # Use a transport
      {:ok, messages} = A2UI.TransportRegistry.generate(:claude, "show weather")
  """

  use GenServer

  def register(name, transport_module, opts)
  def unregister(name)
  def get(name)
  def list()
  def generate(name, prompt, opts \\ [])
end
```

## LiveView Integration

The `A2UI.Live` module provides LiveView integration:

```elixir
defmodule A2UI.Live do
  @moduledoc """
  Phoenix LiveView integration for A2UI rendering.

  ## Usage

      defmodule MyAppWeb.ChatLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          socket = A2UI.Live.init(socket,
            transport: :claude,  # or transport module
            action_callback: &handle_action/2,
            error_callback: &handle_error/2
          )
          {:ok, socket}
        end

        def handle_info({:a2ui, json}, socket) do
          A2UI.Live.handle_a2ui_message({:a2ui, json}, socket)
        end

        def handle_event("a2ui:" <> _ = event, params, socket) do
          A2UI.Live.handle_a2ui_event(event, params, socket)
        end
      end
  """

  # Existing implementation + transport integration
end
```

## Catalog System

Support for custom catalogs beyond the standard v0.8:

```elixir
defmodule A2UI.Catalog do
  @moduledoc """
  Behaviour for component catalogs.

  The standard v0.8 catalog is provided by `A2UI.Catalog.Standard`.
  Custom catalogs can extend or replace it.
  """

  @doc "Render a component to HEEx"
  @callback render_component(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "List supported component types"
  @callback supported_types() :: [String.t()]

  @doc "Get catalog ID (URI)"
  @callback catalog_id() :: String.t()
end

defmodule A2UI.Catalog.Standard do
  @behaviour A2UI.Catalog

  @impl true
  def catalog_id do
    "https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json"
  end

  # Existing implementation
end
```

## Configuration

```elixir
# config/config.exs

config :a2ui,
  # Default catalog
  catalog: A2UI.Catalog.Standard,

  # Validation limits
  max_components: 1000,
  max_data_model_size: 1_000_000,

  # Protocol version
  protocol_version: "0.8"

# config/runtime.exs

config :a2ui, :transports,
  ollama: [
    module: A2UI.Transports.HTTP,
    base_url: System.get_env("OLLAMA_URL", "http://localhost:11434")
  ],
  claude: [
    module: A2UI.Transports.ZeroMQ,
    endpoint: System.get_env("CLAUDE_ZMQ_ENDPOINT", "tcp://127.0.0.1:5555")
  ]
```

## Migration Path

### Phase 1: Extract Core Library

1. Create `a2ui` hex package with:
   - Core rendering modules
   - Transport behaviour (no implementations)
   - Standard catalog
   - LiveView integration

2. Move these files:
   ```
   lib/a2ui/binding.ex         -> a2ui/lib/a2ui/binding.ex
   lib/a2ui/catalog/           -> a2ui/lib/a2ui/catalog/
   lib/a2ui/component.ex       -> a2ui/lib/a2ui/component.ex
   lib/a2ui/error.ex           -> a2ui/lib/a2ui/error.ex
   lib/a2ui/initializers.ex    -> a2ui/lib/a2ui/initializers.ex
   lib/a2ui/live.ex            -> a2ui/lib/a2ui/live.ex
   lib/a2ui/messages/          -> a2ui/lib/a2ui/messages/
   lib/a2ui/parser.ex          -> a2ui/lib/a2ui/parser.ex
   lib/a2ui/renderer.ex        -> a2ui/lib/a2ui/renderer.ex
   lib/a2ui/surface.ex         -> a2ui/lib/a2ui/surface.ex
   lib/a2ui/validator.ex       -> a2ui/lib/a2ui/validator.ex
   lib/a2ui/v0_8.ex            -> a2ui/lib/a2ui/v0_8.ex
   priv/a2ui/                   -> a2ui/priv/a2ui/
   ```

### Phase 2: Extract Transport Implementations

1. Create `a2ui_transports` package (optional dependency):
   ```
   lib/a2ui/ollama_client.ex   -> a2ui_transports/lib/a2ui/transports/ollama.ex
   lib/a2ui/claude_client.ex   -> a2ui_transports/lib/a2ui/transports/claude_zmq.ex
   lib/a2ui/ollama/            -> a2ui_transports/lib/a2ui/transports/ollama/
   priv/claude_bridge/         -> a2ui_transports/priv/claude_bridge/
   ```

2. Add new transports:
   - `A2UI.Transports.WebSocket`
   - `A2UI.Transports.SSE`
   - `A2UI.Transports.A2A`

### Phase 3: Demo App Cleanup

1. Keep demo app as example/reference:
   ```
   lib/a2ui/mock_agent.ex         -> demo/lib/demo/mock_agent.ex
   lib/a2ui/storybook_samples.ex  -> demo/lib/demo/storybook_samples.ex
   lib/a2ui_lv_web/live/demo_live.ex      -> demo/lib/demo_web/live/demo_live.ex
   lib/a2ui_lv_web/live/storybook_live.ex -> demo/lib/demo_web/live/storybook_live.ex
   ```

## Public API

### Core Package (`a2ui`)

```elixir
# Rendering
A2UI.Renderer.surface(surface)

# LiveView Integration
A2UI.Live.init(socket, opts)
A2UI.Live.handle_a2ui_message(msg, socket)
A2UI.Live.handle_a2ui_event(event, params, socket)

# Parsing
A2UI.Parser.parse_line(json_line)
A2UI.Parser.parse_stream(stream)

# Surfaces
A2UI.Surface.new(surface_id)
A2UI.Surface.apply_message(surface, message)
A2UI.Surface.update_data_at_path(surface, path, value)

# Data Binding
A2UI.Binding.resolve(bound_value, data_model, scope_path)
A2UI.Binding.get_path(bound_value)

# Validation
A2UI.Validator.validate_surface_update(msg)
A2UI.Validator.validate_data_model_size(data_model)
```

### Transports Package (`a2ui_transports`)

```elixir
# Generic transport interface
A2UI.Transport.connect(module, opts)
A2UI.Transport.generate(state, prompt, opts)
A2UI.Transport.generate_with_action(state, prompt, action, data_model, opts)
A2UI.Transport.available?(state)
A2UI.Transport.disconnect(state)

# Specific transports
A2UI.Transports.HTTP.connect(base_url: "...")
A2UI.Transports.ZeroMQ.connect(endpoint: "...")
A2UI.Transports.WebSocket.connect(url: "...")
A2UI.Transports.SSE.connect(url: "...")
A2UI.Transports.A2A.connect(agent_url: "...")

# Registry
A2UI.TransportRegistry.register(name, module, opts)
A2UI.TransportRegistry.generate(name, prompt)
```

## Dependencies

### Core Package

```elixir
# mix.exs for a2ui
defp deps do
  [
    {:phoenix_live_view, "~> 1.0"},
    {:jason, "~> 1.4"},
    # Optional: for v0.9 compatibility
    {:protobuf, "~> 0.12", optional: true}
  ]
end
```

### Transports Package

```elixir
# mix.exs for a2ui_transports
defp deps do
  [
    {:a2ui, "~> 1.0"},
    {:req, "~> 0.4"},           # HTTP transport
    {:erlzmq, "~> 3.0", optional: true},  # ZeroMQ transport
    {:websockex, "~> 0.4", optional: true},  # WebSocket transport
    # A2A transport deps TBD
  ]
end
```

## Summary

The separation creates:

1. **`a2ui`** (hex package) - Core renderer library
   - JSONL parsing
   - Surface/component state management
   - Data binding resolution
   - LiveView integration
   - Standard catalog
   - Transport behaviour (interface only)

2. **`a2ui_transports`** (hex package, optional) - Transport implementations
   - HTTP/REST (Ollama)
   - ZeroMQ (Claude bridge)
   - WebSocket
   - SSE
   - A2A Protocol

3. **Demo app** (this repo) - Reference implementation
   - Mock agent for testing
   - Storybook for component showcase
   - Interactive LLM demo

This architecture follows the A2UI specification's separation of concerns:
- Agents generate messages
- Transports deliver them
- Renderers display them

Each layer is independently testable and replaceable.
