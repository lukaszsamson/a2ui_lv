# A2UI LiveView Renderer - PoC Design Document

## Executive Summary

This document outlines a minimal Proof of Concept (PoC) for implementing an A2UI renderer using Phoenix LiveView. The goal is to validate the architectural fit between A2UI's streaming, declarative UI protocol and LiveView's server-rendered, reactive component model.

**Target Version**: A2UI v0.8 (with upgrade path to v0.9 documented)

## References

### A2UI Protocol
- [A2UI Official Site](https://a2ui.org/)
- [A2UI Quickstart](https://a2ui.org/quickstart/)
- [A2UI Concepts: Overview](https://a2ui.org/concepts/overview/)
- [A2UI Concepts: Data Flow](https://a2ui.org/concepts/data-flow/)
- [A2UI Concepts: Components](https://a2ui.org/concepts/components/)
- [A2UI Concepts: Data Binding](https://a2ui.org/concepts/data-binding/)
- [A2UI Specification v0.8](https://a2ui.org/specification/v0.8-a2ui/)
- [A2UI Specification v0.9](https://a2ui.org/specification/v0.9-a2ui/)
- [A2UI v0.9 Evolution Guide](https://a2ui.org/specification/v0.9-evolution-guide/)
- [Renderer Development Guide](https://a2ui.org/guides/renderer-development/)
- [Component Gallery](https://a2ui.org/reference/components/)
- [Message Types Reference](https://a2ui.org/reference/messages/)
- [Transports](https://a2ui.org/transports/)
- [GitHub Repository](https://github.com/google/A2UI)

### Phoenix LiveView
- [Phoenix.LiveView Documentation](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
- [Assigns and HEEx](https://hexdocs.pm/phoenix_live_view/assigns-eex.html)
- [Bindings](https://hexdocs.pm/phoenix_live_view/bindings.html)
- [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html)
- [Phoenix.LiveComponent](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html)

## PoC Goals

1. **Validate architectural fit**: Prove that A2UI's adjacency-list component model maps cleanly to LiveView assigns and HEEx rendering
2. **Demonstrate streaming**: Show progressive UI updates via JSONL message ingestion
3. **Test data binding**: Implement JSON Pointer path resolution (RFC 6901) for dynamic values
4. **Handle two-way binding**: Input components that update the local data model
5. **Handle user interactions**: Wire up A2UI actions to LiveView events and back to agent

## A2UI Protocol Overview

Based on the [Renderer Development Guide](https://a2ui.org/guides/renderer-development/), a renderer must implement:

### Core Systems
1. **Message Processing**: JSONL stream parser + message dispatcher
2. **State Management**: Component buffer (adjacency list) + data model store per surface
3. **Progressive Rendering**: Buffer updates, render on explicit signal

### Message Types (v0.8)

| Message | Purpose |
|---------|---------|
| `surfaceUpdate` | Defines/updates UI components in adjacency list format |
| `dataModelUpdate` | Updates application state via path-based entries |
| `beginRendering` | Signals client to render, specifying root component |
| `deleteSurface` | Removes a surface |

### Data Flow Lifecycle

From [Data Flow Concepts](https://a2ui.org/concepts/data-flow/):

```
Agent (LLM) → A2UI Generator → Transport (SSE/WS/A2A) → Client (Stream Reader)
           → Message Parser → Renderer → Native UI
```

**Lifecycle stages:**
1. **Structure Definition**: Agent sends `surfaceUpdate` with component definitions
2. **Data Population**: Agent sends `dataModelUpdate` with values
3. **Render Signal**: Agent sends `beginRendering` to display UI
4. **Local Updates**: User modifies inputs → renderer updates its local data model (no agent round-trip; in LiveView this still travels over the LiveView socket)
5. **User Action**: Explicit action (button click) → client sends `userAction` with resolved context
6. **Response**: Agent processes action, sends new updates or deletes surface

## Minimal Component Subset

For the PoC, we implement **8 core components** from the [standard catalog](https://a2ui.org/reference/components/):

### Layout Components
| Component | Purpose | Key Properties |
|-----------|---------|----------------|
| `Column` | Vertical flex container | `children`, `distribution`, `alignment` |
| `Row` | Horizontal flex container | `children`, `distribution`, `alignment` |
| `Card` | Elevated visual container | `child` |

### Display Components
| Component | Purpose | Key Properties |
|-----------|---------|----------------|
| `Text` | Text display with semantic hints | `text`, `usageHint` (h1-h5, body, caption) |
| `Divider` | Visual separator | `axis` (horizontal/vertical) |

### Interactive Components
| Component | Purpose | Key Properties |
|-----------|---------|----------------|
| `Button` | Clickable action trigger | `child`, `action`, `primary` |
| `TextField` | Text input with label | `label`, `text`, `textFieldType` |
| `Checkbox` | Boolean toggle | `label`, `value` |

Notes:
- The A2UI component reference uses the type name `Checkbox` (not `CheckBox`). For renderer robustness, accept both spellings and normalize internally.

This subset enables building meaningful forms, layouts, and interactive flows.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          Phoenix LiveView Process                             │
│                                                                              │
│  ┌──────────────┐    ┌───────────────┐    ┌────────────────────────────┐    │
│  │ A2UI.Parser  │ →  │ A2UI.Surface  │ →  │ A2UI.Renderer              │    │
│  │ (JSONL)      │    │ (State Mgmt)  │    │ (Component Dispatch)       │    │
│  └──────────────┘    └───────────────┘    └────────────────────────────┘    │
│         ↑                   │                         ↓                      │
│         │            ┌──────┴──────┐          ┌──────────────┐              │
│         │            │             │          │ A2UI.Catalog │              │
│         │      ┌─────┴─────┐  ┌────┴────┐    │ .Standard    │              │
│         │      │ Component │  │  Data   │    │ (HEEx Comps) │              │
│         │      │  Buffer   │  │  Model  │    └──────────────┘              │
│         │      │ (by ID)   │  │ (JSON)  │           ↓                       │
│         │      └───────────┘  └─────────┘    ┌──────────────┐              │
│         │                          ↑         │ A2UI.Binding │              │
│         │                          │         │ (JSON Ptr)   │              │
│         │                          │         └──────────────┘              │
│         │                          │                                        │
│  ┌──────┴────────────────────────┐ │  User Input (two-way binding)         │
│  │     handle_info/handle_event   │←┘  phx-change → update data_model      │
│  └────────────────────────────────┘                                         │
│         │                                                                    │
│         │ userAction                                                         │
│         ↓                                                                    │
└──────────────────────────────────────────────────────────────────────────────┘
          │ JSONL stream                      ↑ userAction (JSON)
          ↓                                   │
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Agent Backend (Mock/SSE/A2A)                           │
│                     Generates A2UI messages via LLM                           │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Data Binding Design

From [Data Binding Concepts](https://a2ui.org/concepts/data-binding/):

### JSON Pointer Paths (RFC 6901)

```
/user/name          → object property access
/cart/items/0       → array index (zero-based)
/cart/items/0/price → nested path
```

### BoundValue Resolution

Three patterns:
1. **Literal only**: `{"literalString": "Static text"}` → fixed value
2. **Path only**: `{"path": "/user/name"}` → reactive, updates when data changes
3. **Path + Literal**: `{"path": "/user/name", "literalString": "Guest"}` → path with fallback

### Scoped Paths in Templates

When using template children, paths are **scoped** to the current array item:

```json
{"children": {"template": {"dataBinding": "/products", "componentId": "card"}}}
```

In v0.8 docs, scoped bindings inside templates still appear as JSON Pointer strings that start with `/` (example: `{"path": "/name"}`), but they are interpreted as **relative to the template item**. In practice for this LiveView renderer we implement this by prefixing the computed `scope_path` (e.g. `/products/0`) to any `BoundValue.path` used while rendering a template item.

### Two-Way Binding for Inputs

From the documentation: "Interactive components update the data model bidirectionally":
- **TextField**: User types → updates bound path in data model
- **Checkbox**: User toggles → updates bound boolean path
- Updates happen locally in the **renderer’s data model** (the “client-side” model in A2UI terms)
- In this PoC, the renderer lives in the LiveView process, so input events still travel over the LiveView socket; the key constraint is: **no agent round-trip is required** until an explicit action (`userAction`)

## Guardrails & Safety Limits

Per DESIGN_GPT.md, implement safety limits to prevent runaway agent outputs:

| Limit | Value | Rationale |
|-------|-------|-----------|
| Max depth | 30 | Prevent infinite recursion |
| Max components per surface | 1000 | Memory/render performance |
| Max template expansion | 200 items | Prevent huge lists |
| Max data model size | 100KB | Memory bounds |

These are enforced in validation and rendering.

## Core Modules

### 1. `A2UI.V0_8` - Versioned Protocol Module

Following DESIGN_GPT.md's versioned adapter pattern for cleaner separation:

```elixir
defmodule A2UI.V0_8 do
  @moduledoc """
  A2UI v0.8 protocol implementation.

  Handles parsing and validation of v0.8 messages:
  - surfaceUpdate, dataModelUpdate, beginRendering, deleteSurface

  A separate A2UI.V0_9.Adapter can translate v0.9 messages
  to the internal normalized format.
  """

  alias A2UI.{Surface, Component}
  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}

  @doc "Parses a v0.8 message map into internal format"
  def parse_message(%{"surfaceUpdate" => data}),
    do: {:ok, {:surface_update, SurfaceUpdate.from_map(data)}}
  def parse_message(%{"dataModelUpdate" => data}),
    do: {:ok, {:data_model_update, DataModelUpdate.from_map(data)}}
  def parse_message(%{"beginRendering" => data}),
    do: {:ok, {:begin_rendering, BeginRendering.from_map(data)}}
  def parse_message(%{"deleteSurface" => data}),
    do: {:ok, {:delete_surface, DeleteSurface.from_map(data)}}
  def parse_message(_),
    do: {:error, :unknown_message_type}

  @doc "Parses v0.8 component format: {\"component\": {\"Text\": {...}}}"
  def parse_component(%{"id" => id, "component" => component_def}) do
    [{type, props}] = Map.to_list(component_def)
    %Component{id: id, type: type, props: props}
  end
end

defmodule A2UI.V0_9.Adapter do
  @moduledoc """
  Notes for a v0.9 upgrade path (correct per the v0.9 spec):

  v0.9 changes the envelope and some payload shapes:
  - `beginRendering` is replaced by `createSurface` and **there is no root field**; instead a component with `id: "root"` must exist.
  - `surfaceUpdate` is renamed to `updateComponents` and component objects are flattened (`%{"component" => "Text", ...props...}`).
  - `dataModelUpdate` is renamed to `updateDataModel` and uses CRDT metadata:
    - `%{"updateDataModel" => %{"surfaceId" => ..., "actorId" => ..., "updates" => [%{"path" => ..., "value" => ..., "hlc" => ...}], "versions" => %{...}}}`
  - `watchDataModel` configures when the renderer sends `dataModelChanged` back to the agent.

  The PoC renderer targets v0.8 end-to-end; do not implement partial v0.9 parsing in production code unless it matches the above shapes.

  Minimal PoC-compatible v0.9 strategy (if added later):
  - Treat `createSurface` as “surface exists + ready to render”.
  - Apply each `updateDataModel.updates[]` entry as a replace-at-path operation in the renderer’s data model, ignoring conflict resolution metadata for PoC (but document this is not spec-compliant for convergence).
  """
end
```

### 2. `A2UI.Parser` - Message Decoding

```elixir
defmodule A2UI.Parser do
  @moduledoc """
  Parses A2UI JSONL messages.

  Per the Renderer Development Guide, implements:
  - JSONL Stream Parser: Process streaming responses line-by-line
  - Message Dispatcher: Route to appropriate handlers
  """

  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}

  @type message ::
    {:surface_update, SurfaceUpdate.t()} |
    {:data_model_update, DataModelUpdate.t()} |
    {:begin_rendering, BeginRendering.t()} |
    {:delete_surface, DeleteSurface.t()} |
    {:error, term()}

  @doc "Parses a single JSONL line into a typed message"
  @spec parse_line(String.t()) :: message()
  def parse_line(json_line) do
    with {:ok, decoded} <- Jason.decode(json_line) do
      dispatch_message(decoded)
    else
      {:error, reason} -> {:error, {:json_decode, reason}}
    end
  end

  # v0.8 message dispatch
  defp dispatch_message(%{"surfaceUpdate" => data}),
    do: {:surface_update, SurfaceUpdate.from_map(data)}
  defp dispatch_message(%{"dataModelUpdate" => data}),
    do: {:data_model_update, DataModelUpdate.from_map(data)}
  defp dispatch_message(%{"beginRendering" => data}),
    do: {:begin_rendering, BeginRendering.from_map(data)}
  defp dispatch_message(%{"deleteSurface" => data}),
    do: {:delete_surface, DeleteSurface.from_map(data)}

  defp dispatch_message(_), do: {:error, :unknown_message_type}
end
```

### 3. `A2UI.Component` - Component Definition

```elixir
defmodule A2UI.Component do
  @moduledoc """
  Represents a component in the adjacency list.

  From the Components Concepts doc:
  "Components are stored as a flat list with ID-based references"

  Each component has:
  - id: Unique identifier
  - type: Component category from catalog (e.g., "Text", "Button")
  - props: Type-specific configuration
  """

  defstruct [:id, :type, :props]

  @type t :: %__MODULE__{
    id: String.t(),
    type: String.t(),
    props: map()
  }

  @doc """
  Parses v0.8 component format.

  v0.8: {"id": "x", "component": {"Text": {"text": {...}}}}
  """
  def from_map(%{"id" => id, "component" => component_def}) do
    [{type, props}] = Map.to_list(component_def)
    %__MODULE__{id: id, type: type, props: props}
  end

  @doc """
  Parses v0.9 component format.

  v0.9: {"id": "x", "component": "Text", "text": {...}}
  """
  def from_map_v09(%{"id" => id, "component" => type} = data) do
    props = Map.drop(data, ["id", "component"])
    %__MODULE__{id: id, type: type, props: props}
  end
end
```

### 4. `A2UI.Messages.*` - Message Structs

```elixir
defmodule A2UI.Messages.SurfaceUpdate do
  @moduledoc """
  surfaceUpdate (v0.8) / updateComponents (v0.9)

  Adds or updates components within a surface using adjacency list structure.
  Per Message Types Reference: "sending duplicate IDs updates existing components"
  """

  defstruct [:surface_id, :components]

  @type t :: %__MODULE__{
    surface_id: String.t(),
    components: [A2UI.Component.t()]
  }

  def from_map(%{"surfaceId" => sid, "components" => comps}) do
    %__MODULE__{
      surface_id: sid,
      components: Enum.map(comps, &A2UI.Component.from_map/1)
    }
  end

  def from_map_v09(%{"surfaceId" => sid, "components" => comps}) do
    %__MODULE__{
      surface_id: sid,
      components: Enum.map(comps, &A2UI.Component.from_map_v09/1)
    }
  end
end

defmodule A2UI.Messages.DataModelUpdate do
  @moduledoc """
  dataModelUpdate (v0.8) / updateDataModel (v0.9)

  Updates application state via path-based entries.
  Per Data Binding Concepts: "Components automatically update when bound data changes"

  IMPORTANT: The v0.9 message shape is **not** compatible with v0.8:
  - v0.8: `%{"dataModelUpdate" => %{"surfaceId" => ..., "path" => optional, "contents" => [%{"key" => ..., "valueString" => ...} | %{"valueMap" => [...]}, ...]}}`
  - v0.9: `%{"updateDataModel" => %{"surfaceId" => ..., "actorId" => ..., "updates" => [%{"path" => ..., "value" => ..., "hlc" => ...}], "versions" => %{...}}}`

  For the PoC, we only implement v0.8 parsing/apply; v0.9 is documented as an upgrade path.
  """

  defstruct [:surface_id, :path, :contents]

  @type t :: %__MODULE__{surface_id: String.t(), path: String.t() | nil, contents: list()}

  # v0.8: contents is array of key-value entries with typed values
  def from_map(%{"surfaceId" => sid} = data) do
    %__MODULE__{
      surface_id: sid,
      path: Map.get(data, "path"),
      contents: Map.get(data, "contents", [])
    }
  end
end

defmodule A2UI.Messages.BeginRendering do
  @moduledoc """
  beginRendering (v0.8) / createSurface (v0.9)

  Signals client to render the surface.
  Per Data Flow Concepts: "Prevents flash of incomplete content"

  v0.9 note: "There must be exactly one component with ID 'root'"
  rather than explicit root specification.
  """

  defstruct [:surface_id, :root_id, :catalog_id, :styles]

  @type t :: %__MODULE__{
    surface_id: String.t(),
    root_id: String.t(),
    catalog_id: String.t() | nil,
    styles: map() | nil
  }

  def from_map(%{"surfaceId" => sid, "root" => root} = data) do
    %__MODULE__{
      surface_id: sid,
      root_id: root,
      catalog_id: Map.get(data, "catalogId"),
      styles: Map.get(data, "styles")
    }
  end
end

defmodule A2UI.Messages.DeleteSurface do
  @moduledoc "deleteSurface - removes a surface (idempotent)"

  defstruct [:surface_id]

  @type t :: %__MODULE__{surface_id: String.t()}

  def from_map(%{"surfaceId" => sid}), do: %__MODULE__{surface_id: sid}
end
```

### 5. `A2UI.Surface` - Surface State Management

```elixir
defmodule A2UI.Surface do
  @moduledoc """
  Manages state for a single A2UI surface.

  Per Renderer Development Guide, maintains:
  - Component Buffer: Map keyed by ID (adjacency list model)
  - Data Model Store: Separate data model for binding
  - Interpreter State: Readiness flag
  """

  defstruct [
    :id,
    :root_id,
    :catalog_id,
    components: %{},
    data_model: %{},
    ready?: false
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    root_id: String.t() | nil,
    catalog_id: String.t() | nil,
    components: %{String.t() => A2UI.Component.t()},
    data_model: map(),
    ready?: boolean()
  }

  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering}

  def new(surface_id), do: %__MODULE__{id: surface_id}

  @doc "Applies a message to the surface state"
  def apply_message(%__MODULE__{} = surface, %SurfaceUpdate{components: components}) do
    # Merge components by ID (duplicates update existing)
    new_components =
      Enum.reduce(components, surface.components, fn comp, acc ->
        Map.put(acc, comp.id, comp)
      end)
    surface = %{surface | components: new_components}

    # v0.8 renderer checklist: if a BoundValue includes both `path` and `literal*`,
    # initialize the data model at `path` with the literal (if missing) before binding.
    # Implement this as a dedicated initializer pass that scans newly added/updated components
    # and updates `surface.data_model` deterministically (no side effects in render/resolve).
    #
    # surface = A2UI.Initializers.apply(surface)
    surface
  end

  def apply_message(%__MODULE__{} = surface, %DataModelUpdate{} = update) do
    new_data = apply_data_update(surface.data_model, update.path, update.contents)
    %{surface | data_model: new_data}
  end

  def apply_message(%__MODULE__{} = surface, %BeginRendering{root_id: root, catalog_id: catalog}) do
    %{surface | root_id: root, catalog_id: catalog, ready?: true}
  end

  @doc "Updates a single path in the data model (for two-way binding)"
  def update_data_at_path(%__MODULE__{} = surface, path, value) do
    # Two-way binding uses RFC6901 pointers (same resolver as reads).
    # Normalize and apply as a replace-at-path operation.
    pointer = A2UI.Binding.expand_path(path, nil)
    new_data = A2UI.Binding.set_at_pointer(surface.data_model, pointer, value)
    %{surface | data_model: new_data}
  end

  # Private helpers for data model manipulation

  defp apply_data_update(data_model, nil, contents) do
    merge_contents(data_model, contents)
  end

  defp apply_data_update(data_model, path, contents) do
    keys = parse_path(path)
    update_at_path(data_model, keys, fn existing ->
      merge_contents(existing || %{}, contents)
    end)
  end

  defp parse_path("/" <> path), do: String.split(path, "/", trim: true)
  defp parse_path(path), do: String.split(path, "/", trim: true)

  defp update_at_path(data, [], updater), do: updater.(data)
  defp update_at_path(data, [key | rest], updater) do
    current = Map.get(data || %{}, key, %{})
    Map.put(data || %{}, key, update_at_path(current, rest, updater))
  end

  defp put_at_path(data, [key], value), do: Map.put(data || %{}, key, value)
  defp put_at_path(data, [key | rest], value) do
    current = Map.get(data || %{}, key, %{})
    Map.put(data || %{}, key, put_at_path(current, rest, value))
  end

  # v0.8 format: array of {key, valueType} entries
  defp merge_contents(existing, contents) when is_list(contents) do
    Enum.reduce(contents, existing, fn entry, acc ->
      key = entry["key"]
      value = extract_typed_value(entry)
      Map.put(acc, key, value)
    end)
  end

  defp extract_typed_value(%{"valueString" => v}), do: v
  defp extract_typed_value(%{"valueNumber" => v}), do: v
  defp extract_typed_value(%{"valueBoolean" => v}), do: v
  defp extract_typed_value(%{"valueArray" => v}), do: Enum.map(v, &extract_typed_value/1)
  defp extract_typed_value(%{"valueMap" => v}), do: merge_contents(%{}, v)
  defp extract_typed_value(v) when is_binary(v) or is_number(v) or is_boolean(v), do: v
  defp extract_typed_value(_), do: nil
end
```

### 6. `A2UI.Binding` - Data Binding Resolution

Per DESIGN_GPT.md, implements proper RFC 6901 JSON Pointer with:
- Unescaping (`~1` → `/`, `~0` → `~`)
- Path+literal initializer behavior (from the v0.8 renderer checklist)
- Template scope_path approach (pass path string, not full scope object)

```elixir
defmodule A2UI.Binding do
  @moduledoc """
  Resolves A2UI BoundValue objects against a data model.

  From Data Binding Concepts:
  - Literal values: fixed content
  - Path-bound values: reactive, update when data changes
  - Scoped paths: relative resolution in template contexts

  JSON Pointer paths per RFC 6901, with proper unescaping.
  """

  @type bound_value :: map() | String.t() | number() | boolean() | nil
  @type data_model :: map()
  @type scope_path :: String.t() | nil

  @doc """
  Resolves a BoundValue to its actual value.

  The `scope_path` parameter is the base JSON Pointer path for template contexts
  (for example: `"/products/0"`). This avoids embedding large scope objects in the DOM.
  Instead we pass a short pointer string and resolve on the server at render/event time.

  ## BoundValue Resolution Rules (from Renderer Guide)

  1. **Literal Only**: Return the literal value directly
  2. **Path Only**: Resolve path against data_model
  3. **Path + Literal**: The v0.8 renderer checklist describes an initializer behavior:
     if both `path` and `literal*` exist, the renderer should initialize the data model at
     `path` with the literal (if missing) and then treat the property as bound to `path`.
     In a server-rendered LiveView renderer, do not mutate assigns inside `resolve/3`;
     apply initializers during message ingestion (after `surfaceUpdate`) or in a dedicated
     “initializer pass” that returns an updated surface state.
  """
  @spec resolve(bound_value(), data_model(), scope_path()) :: term()
  def resolve(bound_value, data_model, scope_path \\ nil)

  # Literal-only values (v0.8 format)
  def resolve(%{"literalString" => value}, _data, _scope), do: value
  def resolve(%{"literalNumber" => value}, _data, _scope), do: value
  def resolve(%{"literalBoolean" => value}, _data, _scope), do: value
  def resolve(%{"literalArray" => value}, _data, _scope), do: value

  # Path-only values
  def resolve(%{"path" => path}, data_model, scope_path) when is_binary(path) do
    resolve_path(path, data_model, scope_path)
  end

  # Path + Literal: resolver returns fallback value only.
  # Initializing the data model (the “write” part) is handled outside this module.
  def resolve(%{"path" => path} = bound, data_model, scope_path) do
    case resolve_path(path, data_model, scope_path) do
      nil -> get_literal_fallback(bound)
      value -> value
    end
  end

  # v0.9 simplified format: direct values
  def resolve(value, _data, _scope) when is_binary(value), do: value
  def resolve(value, _data, _scope) when is_number(value), do: value
  def resolve(value, _data, _scope) when is_boolean(value), do: value
  def resolve(nil, _data, _scope), do: nil

  # Map without path - could be nested structure
  def resolve(%{} = value, _data, _scope), do: value

  @doc """
  Resolves a JSON Pointer path against data model.

  Scope handling per spec:
  - v0.8: Scoped paths inside templates are written like `/name` but resolve against the item
    (we implement this by prefixing `scope_path`).
  - v0.9: Relative paths like `firstName` resolve as `{scope_path}/firstName`.
  """
  def resolve_path(path, data_model, scope_path) do
    get_at_pointer(data_model, expand_path(path, scope_path))
  end

  @doc "Expands a potentially relative path to absolute"
  def expand_path(path, nil), do: normalize_pointer(path)

  def expand_path(path, scope_path) when is_binary(scope_path) do
    path = to_string(path)

    cond do
      path == "" ->
        scope_path

      String.starts_with?(path, "./") ->
        join_pointer(scope_path, "/" <> String.trim_leading(path, "./"))

      # v0.8 template scoping: `/name` is scoped to the template item.
      String.starts_with?(path, "/") ->
        join_pointer(scope_path, path)

      # v0.9 scoped relative segments: `firstName`
      true ->
        join_pointer(scope_path, "/" <> path)
    end
  end

  defp normalize_pointer(nil), do: ""
  defp normalize_pointer(""), do: ""
  defp normalize_pointer("/" <> _ = path), do: path
  defp normalize_pointer(path), do: "/" <> path

  defp join_pointer(scope_path, "/"), do: scope_path
  defp join_pointer(scope_path, "/" <> rest), do: scope_path <> "/" <> rest

  @doc "Extracts the binding path from a BoundValue (for two-way binding)"
  def get_path(%{"path" => path}), do: path
  def get_path(_), do: nil

  @doc """
  Get value at JSON Pointer path (RFC 6901).

  Handles:
  - `/foo/bar` - object traversal
  - `/items/0` - array indexing
  - `~0` unescaping to `~`
  - `~1` unescaping to `/`
  """
  def get_at_pointer(data, "/" <> path) do
    segments = path
      |> String.split("/", trim: true)
      |> Enum.map(&unescape_pointer_segment/1)

    traverse(data, segments)
  end
  def get_at_pointer(data, ""), do: data
  def get_at_pointer(_data, _), do: nil

  @doc """
  Set value at JSON Pointer path (for two-way binding).
  Returns updated data model.
  """
  def set_at_pointer(data, "/" <> path, value) do
    segments = path
      |> String.split("/", trim: true)
      |> Enum.map(&unescape_pointer_segment/1)

    if segments == [] do
      value
    else
      put_at_path(data, segments, value)
    end
  end
  def set_at_pointer(data, "", value), do: value
  def set_at_pointer(data, _, _value), do: data

  # RFC 6901 JSON Pointer unescaping
  defp unescape_pointer_segment(segment) do
    segment
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
  end

  # Traversal implementation
  defp traverse(data, []), do: data
  defp traverse(nil, _), do: nil

  defp traverse(data, [key | rest]) when is_map(data) do
    value = Map.get(data, key)
    traverse(value, rest)
  end

  defp traverse(data, [key | rest]) when is_list(data) do
    case Integer.parse(key) do
      {index, ""} when index >= 0 -> traverse(Enum.at(data, index), rest)
      _ -> nil
    end
  end

  defp traverse(_, _), do: nil

  # Path setting implementation
  defp put_at_path(data, [key], value) do
    cond do
      is_list(data) ->
        case Integer.parse(key) do
          {index, ""} when index >= 0 -> List.replace_at(data, index, value)
          _ -> data
        end

      true ->
        Map.put(data || %{}, key, value)
    end
  end

  defp put_at_path(data, [key | rest], value) do
    cond do
      is_list(data) ->
        case Integer.parse(key) do
          {index, ""} when index >= 0 ->
            current = Enum.at(data, index) || %{}
            List.replace_at(data, index, put_at_path(current, rest, value))

          _ ->
            data
        end

      true ->
        current = Map.get(data || %{}, key, %{})
        Map.put(data || %{}, key, put_at_path(current, rest, value))
    end
  end

  defp get_literal_fallback(%{"literalString" => v}), do: v
  defp get_literal_fallback(%{"literalNumber" => v}), do: v
  defp get_literal_fallback(%{"literalBoolean" => v}), do: v
  defp get_literal_fallback(_), do: nil
end
```

### 6b. `A2UI.Initializers` - Path+Literal Initialization Pass

The v0.8 renderer checklist specifies an initializer behavior for `BoundValue`s that include both `path` and a `literal*`:
- If the data model has no value at `path`, initialize it with the literal.
- Then treat the component property as bound to `path`.

In this LiveView renderer, implement this as a deterministic pass that runs:
- after every `surfaceUpdate` (and optionally once after `beginRendering`), scanning only the components that changed,
- producing a set of `set_at_pointer/3` operations applied to `surface.data_model`,
- never mutating assigns inside `render/1` or inside `A2UI.Binding.resolve/3`.

This avoids hidden side effects during rendering and keeps LiveView diffs predictable.

### 7. `A2UI.Catalog.Standard` - Component Implementations

Using Phoenix function components (not LiveComponents) per LiveView best practices:
"Prefer function components unless you need encapsulated event handling AND additional state."

```elixir
defmodule A2UI.Catalog.Standard do
  @moduledoc """
  Standard A2UI component catalog as Phoenix function components.

  From LiveView docs on change tracking:
  - Be explicit about which data each component needs
  - Prefer stable DOM ids for efficient diffs
  """

  use Phoenix.Component
  alias A2UI.Binding

  # ============================================
  # Component Dispatch
  # ============================================

  @doc """
  Dispatches to the appropriate component by type.

  This is the main entry point - looks up component by ID,
  then delegates to the type-specific renderer.

  Per DESIGN_GPT.md: Pass `scope_path` (a JSON Pointer string like "/items/0")
  instead of the full scope object. This keeps DOM payloads small and
  bindings are resolved at render/event time.
  """
  attr :id, :string, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def render_component(assigns) do
    component = assigns.surface.components[assigns.id]

    if component do
      assigns = assign(assigns, :component, component)

      ~H"""
      <div class="a2ui-component" id={"a2ui-#{@surface.id}-#{@id}"}>
        <%= case @component.type do %>
          <% "Column" -> %>
            <.a2ui_column props={@component.props} surface={@surface} scope_path={@scope_path} />
          <% "Row" -> %>
            <.a2ui_row props={@component.props} surface={@surface} scope_path={@scope_path} />
          <% "Card" -> %>
            <.a2ui_card props={@component.props} surface={@surface} scope_path={@scope_path} id={@id} />
          <% "Text" -> %>
            <.a2ui_text props={@component.props} surface={@surface} scope_path={@scope_path} />
          <% "Divider" -> %>
            <.a2ui_divider props={@component.props} />
          <% "Button" -> %>
            <.a2ui_button props={@component.props} surface={@surface} scope_path={@scope_path} id={@id} />
          <% "TextField" -> %>
            <.a2ui_text_field props={@component.props} surface={@surface} scope_path={@scope_path} id={@id} />
          <% "Checkbox" -> %>
            <.a2ui_checkbox props={@component.props} surface={@surface} scope_path={@scope_path} id={@id} />
          <% "CheckBox" -> %>
            <.a2ui_checkbox props={@component.props} surface={@surface} scope_path={@scope_path} id={@id} />
          <% unknown -> %>
            <.a2ui_unknown type={unknown} />
        <% end %>
      </div>
      """
    else
      ~H"""
      <div class="a2ui-missing text-red-500">Missing component: <%= @id %></div>
      """
    end
  end

  # ============================================
  # Layout Components
  # ============================================

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_column(assigns) do
    distribution = assigns.props["distribution"] || "start"
    alignment = assigns.props["alignment"] || "stretch"
    assigns = assign(assigns, distribution: distribution, alignment: alignment)

    ~H"""
    <div
      class="a2ui-column flex flex-col gap-2"
      style={flex_style(@distribution, @alignment)}
    >
      <.render_children props={@props} surface={@surface} scope_path={@scope_path} />
    </div>
    """
  end

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_row(assigns) do
    distribution = assigns.props["distribution"] || "start"
    alignment = assigns.props["alignment"] || "center"
    assigns = assign(assigns, distribution: distribution, alignment: alignment)

    ~H"""
    <div
      class="a2ui-row flex flex-row gap-2"
      style={flex_style(@distribution, @alignment)}
    >
      <.render_children props={@props} surface={@surface} scope_path={@scope_path} />
    </div>
    """
  end

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true

  def a2ui_card(assigns) do
    ~H"""
    <div class="a2ui-card rounded-lg border bg-white p-4 shadow-sm">
      <.render_component
        :if={@props["child"]}
        id={@props["child"]}
        surface={@surface}
        scope_path={@scope_path}
      />
    </div>
    """
  end

  # ============================================
  # Display Components
  # ============================================

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_text(assigns) do
    text = Binding.resolve(assigns.props["text"], assigns.surface.data_model, assigns.scope_path)
    hint = assigns.props["usageHint"] || "body"
    assigns = assign(assigns, text: text, hint: hint)

    ~H"""
    <span class={text_classes(@hint)}><%= @text %></span>
    """
  end

  attr :props, :map, required: true

  def a2ui_divider(assigns) do
    axis = assigns.props["axis"] || "horizontal"
    assigns = assign(assigns, axis: axis)

    ~H"""
    <hr class={divider_classes(@axis)} />
    """
  end

  # ============================================
  # Interactive Components
  # ============================================

  @doc """
  Button - clickable action trigger.

  Per DESIGN_GPT.md: Don't embed action JSON in DOM - just pass surface_id
  and component_id. Server looks up the component definition and resolves
  action.context at event time. This avoids large DOM payloads.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true

  def a2ui_button(assigns) do
    primary = assigns.props["primary"] || false
    assigns = assign(assigns, primary: primary)

    ~H"""
    <button
      class={button_classes(@primary)}
      phx-click="a2ui:action"
      phx-value-surface-id={@surface.id}
      phx-value-component-id={@id}
      phx-value-scope-path={@scope_path || ""}
    >
      <.render_component
        :if={@props["child"]}
        id={@props["child"]}
        surface={@surface}
        scope_path={@scope_path}
      />
    </button>
    """
  end

  @doc """
  TextField - text input with label and two-way binding.

  Per DESIGN_GPT.md: Uses the project's `<.input>` component from
  core_components.ex rather than raw HTML inputs. Wraps in a small
  form with phx-change for proper LiveView form handling.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true

  def a2ui_text_field(assigns) do
    label = Binding.resolve(assigns.props["label"], assigns.surface.data_model, assigns.scope_path)
    # v0.8 uses "text", v0.9 uses "value"
    text_prop = assigns.props["text"] || assigns.props["value"]
    text = Binding.resolve(text_prop, assigns.surface.data_model, assigns.scope_path)
    # v0.8 uses "textFieldType", v0.9 uses "variant"
    field_type = assigns.props["textFieldType"] || assigns.props["variant"] || "shortText"

    # Get absolute path for binding (expand if relative)
    raw_path = Binding.get_path(text_prop)
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path), else: nil

    assigns = assign(assigns, label: label, text: text, field_type: field_type, path: path)

    ~H"""
    <%!-- In real code, build the form with to_form/2 so params use string keys --%>
    <% form = Phoenix.Component.to_form(%{"surface_id" => @surface.id, "path" => @path, "value" => @text || ""}, as: :a2ui_input) %>

    <.form for={form} phx-change="a2ui:input" class="a2ui-text-field" id={"a2ui-form-#{@surface.id}-#{@id}"}>
      <.input field={form[:surface_id]} type="hidden" />
      <.input field={form[:path]} type="hidden" />

      <%!-- NOTE: core_components <.input> currently does not allow phx-* attrs via :rest.
            For the PoC implementation, extend it to accept at least phx-debounce/phx-throttle. --%>
      <.input
        field={form[:value]}
        id={"a2ui-input-#{@surface.id}-#{@id}"}
        label={@label}
        type={if @field_type == "longText", do: "textarea", else: input_type(@field_type)}
        phx-debounce="300"
      />
    </.form>
    """
  end

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true

  def a2ui_checkbox(assigns) do
    label = Binding.resolve(assigns.props["label"], assigns.surface.data_model, assigns.scope_path)
    value = Binding.resolve(assigns.props["value"], assigns.surface.data_model, assigns.scope_path)

    # Get absolute path for binding
    raw_path = Binding.get_path(assigns.props["value"])
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path), else: nil

    assigns = assign(assigns, label: label, value: !!value, path: path)

    ~H"""
    <% form = Phoenix.Component.to_form(%{"surface_id" => @surface.id, "path" => @path, "value" => @value}, as: :a2ui_input) %>

    <.form for={form} phx-change="a2ui:toggle" id={"a2ui-form-#{@surface.id}-#{@id}"}>
      <.input field={form[:surface_id]} type="hidden" />
      <.input field={form[:path]} type="hidden" />
      <.input
        field={form[:value]}
        id={"a2ui-checkbox-#{@surface.id}-#{@id}"}
        type="checkbox"
        label={@label}
      />
    </.form>
    """
  end

  # ============================================
  # Children Rendering
  # ============================================

  @doc """
  Renders children from explicitList or template.

  Per DESIGN_GPT.md: For templates, pass scope_path (e.g., "/items/0")
  rather than the full scope object. This keeps DOM payloads small
  and resolves bindings at render/event time.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def render_children(assigns) do
    children_spec = assigns.props["children"]

    cond do
      # Explicit list of component IDs
      is_map(children_spec) && Map.has_key?(children_spec, "explicitList") ->
        assigns = assign(assigns, child_ids: children_spec["explicitList"])

        ~H"""
        <%= for child_id <- @child_ids do %>
          <.render_component id={child_id} surface={@surface} scope_path={@scope_path} />
        <% end %>
        """

      # Template (dynamic list from data binding)
      is_map(children_spec) && Map.has_key?(children_spec, "template") ->
        template = children_spec["template"]
        data_binding = template["dataBinding"]
        template_id = template["componentId"]

        # Resolve the array path to get items
        items = Binding.resolve(%{"path" => data_binding}, assigns.surface.data_model, assigns.scope_path) || []

        # Compute base path for template items
        base_path = Binding.expand_path(data_binding, assigns.scope_path)

        assigns = assign(assigns, items: items, template_id: template_id, base_path: base_path)

        ~H"""
        <%= for {_item, idx} <- Enum.with_index(@items) do %>
          <.render_component
            id={@template_id}
            surface={@surface}
            scope_path={"#{@base_path}/#{idx}"}
          />
        <% end %>
        """

      true ->
        ~H""
    end
  end

  # ============================================
  # Unknown Component Handler
  # ============================================

  attr :type, :string, required: true

  def a2ui_unknown(assigns) do
    ~H"""
    <div class="a2ui-unknown text-orange-500 border border-orange-300 rounded p-2 text-sm">
      Unsupported component type: <%= @type %>
    </div>
    """
  end

  # ============================================
  # Style Helpers
  # ============================================

  defp flex_style(distribution, alignment) do
    justify = case distribution do
      "center" -> "center"
      "end" -> "flex-end"
      "start" -> "flex-start"
      "spaceAround" -> "space-around"
      "spaceBetween" -> "space-between"
      "spaceEvenly" -> "space-evenly"
      _ -> "flex-start"
    end

    align = case alignment do
      "center" -> "center"
      "end" -> "flex-end"
      "start" -> "flex-start"
      "stretch" -> "stretch"
      _ -> "stretch"
    end

    "justify-content: #{justify}; align-items: #{align};"
  end

  defp text_classes(hint) do
    case hint do
      "h1" -> "text-3xl font-bold text-gray-900"
      "h2" -> "text-2xl font-bold text-gray-900"
      "h3" -> "text-xl font-semibold text-gray-900"
      "h4" -> "text-lg font-semibold text-gray-800"
      "h5" -> "text-base font-medium text-gray-800"
      "caption" -> "text-sm text-gray-500"
      "body" -> "text-base text-gray-700"
      _ -> "text-base text-gray-700"
    end
  end

  defp divider_classes("vertical"), do: "border-l border-gray-200 h-full mx-2"
  defp divider_classes(_), do: "border-t border-gray-200 w-full my-2"

  defp button_classes(true) do
    "px-4 py-2 rounded-md bg-blue-600 text-white font-medium " <>
    "hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
  end
  defp button_classes(false) do
    "px-4 py-2 rounded-md border border-gray-300 text-gray-700 font-medium " <>
    "hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
  end

  defp input_type("number"), do: "number"
  defp input_type("date"), do: "date"
  defp input_type("obscured"), do: "password"
  defp input_type(_), do: "text"
end
```

### 8. `A2UI.Renderer` - Top-Level Surface Renderer

```elixir
defmodule A2UI.Renderer do
  @moduledoc """
  Top-level renderer for A2UI surfaces.

  Per Renderer Development Guide:
  - Buffer updates without immediate rendering
  - beginRendering signals explicit render initiation
  """

  use Phoenix.Component
  alias A2UI.Catalog.Standard

  @doc "Renders an A2UI surface"
  attr :surface, :map, required: true

  def surface(assigns) do
    ~H"""
    <div
      class="a2ui-surface"
      id={"a2ui-surface-#{@surface.id}"}
      data-surface-id={@surface.id}
    >
      <%= if @surface.ready? do %>
        <Standard.render_component
          id={@surface.root_id}
          surface={@surface}
          scope_path={nil}
        />
      <% else %>
        <div class="a2ui-loading flex items-center justify-center p-8 text-gray-500">
          <svg class="animate-spin h-5 w-5 mr-2" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"/>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"/>
          </svg>
          Loading...
        </div>
      <% end %>
    </div>
    """
  end
end
```

### 9. `A2UI.Live` - LiveView Integration

```elixir
defmodule A2UI.Live do
  @moduledoc """
  LiveView behavior for A2UI rendering.

  Handles:
  - Message ingestion via handle_info
  - User events via handle_event
  - Two-way binding for input components
  - userAction construction and dispatch

  Per LiveView docs on bindings:
  - phx-click for button actions
  - phx-change with phx-debounce for text inputs
  - phx-value-* for passing data to server

  Phoenix v1.8 project detail:
  - The generated `core_components.ex` `<.input>` component restricts which attributes are forwarded via its `:rest` allowlist.
  - To implement A2UI TextField debouncing cleanly while still using `<.input>`, extend that allowlist to include `phx-debounce` (and optionally `phx-throttle`).
  """

  alias A2UI.{Parser, Surface, Binding}
  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}

  @doc """
  Call this from your LiveView's mount/3 to initialize A2UI state.
  Returns socket with :a2ui_surfaces assign.
  """
  def init(socket, opts \\ []) do
    Phoenix.LiveView.assign(socket,
      a2ui_surfaces: %{},
      a2ui_action_callback: opts[:action_callback]
    )
  end

  @doc """
  Handle incoming A2UI JSONL messages.
  Call from your LiveView's handle_info/2.
  """
  def handle_a2ui_message({:a2ui, json_line}, socket) do
    case Parser.parse_line(json_line) do
      {:surface_update, %SurfaceUpdate{surface_id: sid} = msg} ->
        {:noreply, update_surface(socket, sid, msg)}

      {:data_model_update, %DataModelUpdate{surface_id: sid} = msg} ->
        {:noreply, update_surface(socket, sid, msg)}

      {:begin_rendering, %BeginRendering{surface_id: sid} = msg} ->
        {:noreply, update_surface(socket, sid, msg)}

      {:delete_surface, %DeleteSurface{surface_id: sid}} ->
        surfaces = Map.delete(socket.assigns.a2ui_surfaces, sid)
        {:noreply, Phoenix.LiveView.assign(socket, :a2ui_surfaces, surfaces)}

      {:error, reason} ->
        require Logger
        Logger.warning("A2UI parse error: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @doc """
  Handle A2UI user events.
  Call from your LiveView's handle_event/3.

  Per DESIGN_GPT.md: Button action data (name, context) is NOT embedded in DOM.
  We only pass surface_id, component_id, and scope_path via phx-value-*.
  The action is looked up from the component definition at event time.
  This keeps DOM payloads small and avoids JSON serialization issues.
  """
  def handle_a2ui_event("a2ui:action", params, socket) do
    surface_id = params["surface-id"]
    component_id = params["component-id"]
    scope_path = case params["scope-path"] do
      "" -> nil
      nil -> nil
      path -> path
    end

    surface = socket.assigns.a2ui_surfaces[surface_id]

    # Look up the component definition to get the action
    component = surface && surface.components[component_id]
    action = component && component.props["action"]

    if action do
      action_name = action["name"]
      action_context = action["context"] || []

      # Resolve all context bindings against current data model
      resolved_context = resolve_action_context(action_context, surface.data_model, scope_path)

      user_action = %{
        "userAction" => %{
          "name" => action_name,
          "surfaceId" => surface_id,
          "sourceComponentId" => component_id,
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "context" => resolved_context
        }
      }

      # Transport note (A2A extension, v0.8):
      # - user events are sent separately from the server→client JSONL stream.
      # - when using A2A, wrap this JSON in a DataPart with metadata mimeType "application/json+a2ui"
      #   and include `a2uiClientCapabilities` in the A2A message metadata (supportedCatalogIds, etc.).

      # Dispatch to callback if configured
      if callback = socket.assigns[:a2ui_action_callback] do
        callback.(user_action, socket)
      end

      {:noreply, Phoenix.LiveView.assign(socket, :a2ui_last_action, user_action)}
    else
      require Logger
      Logger.warning("A2UI action event for component without action: #{component_id}")
      {:noreply, socket}
    end
  end

  def handle_a2ui_event("a2ui:input", params, socket) do
    # Two-way binding: update local data model on input change
    # Params come from the TextField form:
    #   %{"a2ui_input" => %{"surface_id" => "...", "path" => "...", "value" => "..."}}.
    input = params["a2ui_input"] || %{}
    surface_id = input["surface_id"]
    path = input["path"]
    value = input["value"]
    # Type note: LiveView form params arrive as strings. If the bound component is a number/date/etc,
    # coerce the value before writing to the data model (based on `textFieldType` or catalog metadata).

    if path && surface_id do
      socket = update_data_at_path(socket, surface_id, path, value)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_a2ui_event("a2ui:toggle", params, socket) do
    # Two-way binding: update boolean at path based on form param.
    input = params["a2ui_input"] || %{}
    surface_id = input["surface_id"]
    path = input["path"]
    value = input["value"]

    checked? =
      case value do
        true -> true
        "true" -> true
        "on" -> true
        _ -> false
      end

    if path && surface_id do
      {:noreply, update_data_at_path(socket, surface_id, path, checked?)}
    else
      {:noreply, socket}
    end
  end

  # Private helpers

  defp update_surface(socket, surface_id, message) do
    surfaces = socket.assigns.a2ui_surfaces
    surface = Map.get(surfaces, surface_id) || Surface.new(surface_id)
    updated = Surface.apply_message(surface, message)
    Phoenix.LiveView.assign(socket, :a2ui_surfaces, Map.put(surfaces, surface_id, updated))
  end

  defp update_data_at_path(socket, surface_id, path, value) do
    surfaces = socket.assigns.a2ui_surfaces
    surface = surfaces[surface_id]

    if surface do
      updated = Surface.update_data_at_path(surface, path, value)
      Phoenix.LiveView.assign(socket, :a2ui_surfaces, Map.put(surfaces, surface_id, updated))
    else
      socket
    end
  end

  defp resolve_action_context(context_list, data_model, scope_path) do
    Enum.reduce(context_list, %{}, fn
      %{"key" => key, "value" => bound_value}, acc ->
        resolved = Binding.resolve(bound_value, data_model, scope_path)
        Map.put(acc, key, resolved)
      _, acc ->
        acc
    end)
  end
end
```

## Demo Implementation

### Demo LiveView

Important (Phoenix v1.8 scaffolding in this repo):
- LiveView templates should start with `<Layouts.app ...>` and must pass `current_scope`.
- Ensure the demo route lives under the authenticated `live_session` so `@current_scope` is assigned (otherwise you’ll hit the “no current_scope assign” error).

```elixir
defmodule A2uiLvWeb.DemoLive do
  use A2uiLvWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket = A2UI.Live.init(socket, action_callback: &handle_action/2)

    if connected?(socket) do
      send(self(), :load_demo)
    end

    {:ok, assign(socket, :a2ui_last_action, nil)}
  end

  @impl true
  def handle_info(:load_demo, socket) do
    # Send mock A2UI messages
    A2UI.MockAgent.send_sample_form(self())
    {:noreply, socket}
  end

  @impl true
  def handle_info({:a2ui, _} = msg, socket) do
    A2UI.Live.handle_a2ui_message(msg, socket)
  end

  @impl true
  def handle_event("a2ui:" <> _ = event, params, socket) do
    A2UI.Live.handle_a2ui_event(event, params, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-gray-50 py-8">
        <div class="container mx-auto px-4">
          <h1 class="text-3xl font-bold text-gray-900 mb-8">A2UI LiveView Demo</h1>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <%!-- Rendered Surface --%>
            <div>
              <h2 class="text-lg font-semibold text-gray-700 mb-4">Rendered Surface</h2>
              <div class="bg-white rounded-lg shadow p-6">
                <%= for {_id, surface} <- @a2ui_surfaces do %>
                  <A2UI.Renderer.surface surface={surface} />
                <% end %>

                <%= if map_size(@a2ui_surfaces) == 0 do %>
                  <div class="text-gray-400 text-center py-8">
                    No surfaces loaded
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Debug Panel --%>
            <div>
              <h2 class="text-lg font-semibold text-gray-700 mb-4">Debug Info</h2>
              <div class="bg-gray-800 rounded-lg shadow p-4 text-sm font-mono text-gray-100 overflow-auto max-h-[600px]">
                <%= if @a2ui_last_action do %>
                  <div class="mb-4">
                    <div class="text-green-400 mb-1">Last Action:</div>
                    <pre class="text-gray-300 whitespace-pre-wrap"><%= Jason.encode!(@a2ui_last_action, pretty: true) %></pre>
                  </div>
                <% end %>

                <%= for {id, surface} <- @a2ui_surfaces do %>
                  <div class="mb-4">
                    <div class="text-blue-400 mb-1">Data Model (<%= id %>):</div>
                    <pre class="text-gray-300 whitespace-pre-wrap"><%= Jason.encode!(surface.data_model, pretty: true) %></pre>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp handle_action(user_action, _socket) do
    require Logger
    Logger.info("User action: #{inspect(user_action)}")
    # In a real app, send to agent here
  end
end
```

### Mock Agent

```elixir
defmodule A2UI.MockAgent do
  @moduledoc "Mock agent for PoC testing"

  def send_sample_form(pid) do
    # Surface update with components
    send(pid, {:a2ui, ~s({"surfaceUpdate":{"surfaceId":"main","components":[
      {"id":"root","component":{"Column":{"children":{"explicitList":["header","form","actions"]}}}},
      {"id":"header","component":{"Text":{"text":{"literalString":"Contact Form"},"usageHint":"h1"}}},
      {"id":"form","component":{"Card":{"child":"form_fields"}}},
      {"id":"form_fields","component":{"Column":{"children":{"explicitList":["name_field","email_field","message_field","subscribe"]}}}},
      {"id":"name_field","component":{"TextField":{"label":{"literalString":"Name"},"text":{"path":"/form/name"},"textFieldType":"shortText"}}},
      {"id":"email_field","component":{"TextField":{"label":{"literalString":"Email"},"text":{"path":"/form/email"},"textFieldType":"shortText"}}},
      {"id":"message_field","component":{"TextField":{"label":{"literalString":"Message"},"text":{"path":"/form/message"},"textFieldType":"longText"}}},
      {"id":"subscribe","component":{"Checkbox":{"label":{"literalString":"Subscribe to updates"},"value":{"path":"/form/subscribe"}}}},
      {"id":"actions","component":{"Row":{"children":{"explicitList":["reset_btn","submit_btn"]},"distribution":"end"}}},
      {"id":"reset_btn","component":{"Button":{"child":"reset_text","primary":false,"action":{"name":"reset_form"}}}},
      {"id":"reset_text","component":{"Text":{"text":{"literalString":"Reset"}}}},
      {"id":"submit_btn","component":{"Button":{"child":"submit_text","primary":true,"action":{"name":"submit_form","context":[{"key":"formData","value":{"path":"/form"}}]}}}},
      {"id":"submit_text","component":{"Text":{"text":{"literalString":"Submit"}}}}
    ]}})})

    # Data model
    send(pid, {:a2ui, ~s({"dataModelUpdate":{"surfaceId":"main","contents":[
      {"key":"form","valueMap":[
        {"key":"name","valueString":""},
        {"key":"email","valueString":""},
        {"key":"message","valueString":""},
        {"key":"subscribe","valueBoolean":false}
      ]}
    ]}})})

    # Begin rendering
    send(pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"main","root":"root"}})})
  end
end
```

## Directory Structure

Implementation note:
- In actual Elixir code, place **one module per file** to avoid cyclic dependencies and compilation issues.
- The multiple `defmodule` examples below are for documentation only and should be split accordingly.

```
lib/
├── a2ui/
│   ├── protocol.ex            # Version detection
│   ├── parser.ex              # JSONL message parsing
│   ├── surface.ex             # Surface state management
│   ├── binding.ex             # JSON Pointer resolution
│   ├── component.ex           # Component struct
│   ├── messages/
│   │   ├── surface_update.ex
│   │   ├── data_model_update.ex
│   │   ├── begin_rendering.ex
│   │   └── delete_surface.ex
│   ├── catalog/
│   │   └── standard.ex        # Standard component implementations
│   ├── renderer.ex            # Top-level render component
│   ├── live.ex                # LiveView integration helpers
│   └── mock_agent.ex          # Mock agent for testing
│
├── a2ui_lv_web/
│   ├── live/
│   │   └── demo_live.ex       # Demo page
│   └── ...
│
test/
├── a2ui/
│   ├── parser_test.exs
│   ├── surface_test.exs
│   ├── binding_test.exs
│   └── ...
└── ...
```

## Implementation Phases

### Phase 1: Core Infrastructure
1. `A2UI.Parser` - JSONL parsing
2. `A2UI.Surface` - State management
3. `A2UI.Binding` - JSON Pointer resolution
4. Message structs
5. Unit tests

### Phase 2: Component Catalog
1. Layout components (Column, Row, Card)
2. Display components (Text, Divider)
3. Interactive components (Button, TextField, Checkbox)
4. Children rendering (explicitList, template)

### Phase 3: LiveView Integration
1. `A2UI.Renderer` - Surface component
2. `A2UI.Live` - Event handling
3. Two-way binding
4. Demo page

### Phase 4: Polish
1. Error handling
2. CSS styling
3. Integration tests
4. Documentation

## Key Design Decisions

### 1. Server-Side Rendering

A2UI rendered entirely on server via LiveView. This differs from browser-based renderers but aligns with LiveView's model.

**Trade-offs:**
- (+) No JavaScript A2UI runtime
- (+) Full Elixir control
- (+) Natural Phoenix security integration
- (-) Server round-trip for input changes (mitigated by debouncing)

### 2. Function Components Over LiveComponents

Per LiveView docs: "Prefer function components unless you need encapsulated event handling AND additional state."

A2UI components are stateless renders - state lives in the Surface. Function components are simpler and sufficient.

### 3. Two-Way Binding Implementation

Per A2UI Data Binding concepts: user interactions immediately update the renderer’s local data model without an agent round-trip until an explicit action.

In LiveView, we update `data_model` in assigns on `phx-change`, with `phx-debounce` to reduce round-trips. The action sends resolved values.

### 4. v0.8 First, v0.9 Ready

Target v0.8 for PoC but structure code to support v0.9:
- Component parsing abstracted (`from_map` vs `from_map_v09`)
- Keep v0.9 changes isolated behind an adapter layer (documented above); do not claim v0.9 support until `updateDataModel` (CRDT updates + `watchDataModel`) is implemented.

## v0.8 vs v0.9 Differences

| Aspect | v0.8 | v0.9 |
|--------|------|------|
| Envelope messages | surfaceUpdate, dataModelUpdate, beginRendering, deleteSurface | createSurface, updateComponents, updateDataModel, deleteSurface, watchDataModel |
| Component format | `{"component": {"Text": {...}}}` | `{"component": "Text", ...}` |
| Data model updates | Typed adjacency list (`contents` with `valueString`/`valueMap`/...) | CRDT-style `updates[]` (path/value/hlc) + `versions` |
| Root specification | Explicit `beginRendering.root` | Convention: a component with `id: "root"` must exist; no root field in `createSurface` |
| Action context | Array of key-value | Standard map |
| Layout props | distribution, alignment | justify, align |
| TextField | text, textFieldType | value, variant |

## Security Considerations

### Message Validation

```elixir
defmodule A2UI.Validator do
  @max_components 1000
  @max_depth 30
  @allowed_types ~w(Column Row Card Text Divider Button TextField Checkbox CheckBox)

  def validate_surface_update(%{components: components}) do
    with :ok <- validate_count(components),
         :ok <- validate_types(components),
         :ok <- validate_depth(components) do
      :ok
    end
  end
end
```

### No Code Execution

A2UI is declarative - catalog maps type strings to known Elixir functions. No `eval` or dynamic code.

### Path Validation

JSON Pointer paths should be validated to prevent unintended data access.

## Testing Strategy

Per DESIGN_GPT.md, implement a comprehensive testing approach:

### Unit Tests

```elixir
# test/a2ui/binding_test.exs
defmodule A2UI.BindingTest do
  use ExUnit.Case, async: true

  alias A2UI.Binding

  describe "resolve/3" do
    test "resolves literal string" do
      assert Binding.resolve(%{"literalString" => "hello"}, %{}, nil) == "hello"
    end

    test "resolves path against data model" do
      data = %{"user" => %{"name" => "Alice"}}
      assert Binding.resolve(%{"path" => "/user/name"}, data, nil) == "Alice"
    end

    test "returns nil for missing path" do
      assert Binding.resolve(%{"path" => "/missing"}, %{}, nil) == nil
    end

    test "returns literal fallback when path is nil" do
      bound = %{"path" => "/missing", "literalString" => "default"}
      assert Binding.resolve(bound, %{}, nil) == "default"
    end

    test "resolves relative path with scope_path" do
      data = %{"items" => [%{"name" => "first"}, %{"name" => "second"}]}
      assert Binding.resolve(%{"path" => "name"}, data, "/items/0") == "first"
      assert Binding.resolve(%{"path" => "name"}, data, "/items/1") == "second"
    end
  end

  describe "get_at_pointer/2" do
    test "handles RFC 6901 unescaping" do
      data = %{"a/b" => %{"c~d" => "value"}}
      assert Binding.get_at_pointer(data, "/a~1b/c~0d") == "value"
    end

    test "handles array indexing" do
      data = %{"items" => ["a", "b", "c"]}
      assert Binding.get_at_pointer(data, "/items/1") == "b"
    end
  end
end

# test/a2ui/surface_test.exs
defmodule A2UI.SurfaceTest do
  use ExUnit.Case, async: true

  alias A2UI.Surface
  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering}

  test "apply_message merges components by ID" do
    surface = Surface.new("test")
    update = %SurfaceUpdate{
      surface_id: "test",
      components: [
        %A2UI.Component{id: "a", type: "Text", props: %{"text" => %{"literalString" => "hello"}}}
      ]
    }

    surface = Surface.apply_message(surface, update)
    assert Map.has_key?(surface.components, "a")
    assert surface.components["a"].type == "Text"
  end

  test "apply_message sets ready flag on begin_rendering" do
    surface = Surface.new("test")
    render = %BeginRendering{surface_id: "test", root_id: "root", catalog_id: nil, styles: nil}

    surface = Surface.apply_message(surface, render)
    assert surface.ready? == true
    assert surface.root_id == "root"
  end
end

# test/a2ui/parser_test.exs
defmodule A2UI.ParserTest do
  use ExUnit.Case, async: true

  alias A2UI.Parser

  test "parses v0.8 surfaceUpdate" do
    json = ~s({"surfaceUpdate":{"surfaceId":"main","components":[]}})
    assert {:surface_update, msg} = Parser.parse_line(json)
    assert msg.surface_id == "main"
  end

  test "parses v0.8 beginRendering" do
    json = ~s({"beginRendering":{"surfaceId":"main","root":"root"}})
    assert {:begin_rendering, msg} = Parser.parse_line(json)
    assert msg.root_id == "root"
  end

  test "returns error for invalid JSON" do
    assert {:error, {:json_decode, _}} = Parser.parse_line("not json")
  end
end
```

### Integration Tests

```elixir
# test/a2ui_lv_web/live/demo_live_test.exs
defmodule A2uiLvWeb.DemoLiveTest do
  use A2uiLvWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders surface after beginRendering", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/demo")

    # Simulate A2UI messages
    send(view.pid, {:a2ui, ~s({"surfaceUpdate":{"surfaceId":"test","components":[
      {"id":"root","component":{"Text":{"text":{"literalString":"Hello"}}}}
    ]}})})
    send(view.pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"test","root":"root"}})})

    # Assert component rendered
    assert render(view) =~ "Hello"
  end

  test "two-way binding updates data model on input", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/demo")

    # Setup surface with TextField
    # ... send messages ...

    # Simulate user input
    view
    |> form("#a2ui-form-test-email-input", %{
      "a2ui_input" => %{
        "surface_id" => "test",
        "path" => "/form/email",
        "value" => "new text"
      }
    })
    |> render_change()

    # Verify data model updated
    # (check via debug panel or internal state)
  end

  test "button click triggers action callback", %{conn: conn} do
    # Test that clicking button invokes the action callback
    # with properly resolved context
  end
end
```

### Property-Based Tests (Optional)

If you choose to add property-based tests, add `:stream_data` to deps and use it to exercise pointer traversal and template-scoping rules. Do not add it for the PoC unless you explicitly want that extra dependency.

## Open Questions

Per DESIGN_GPT.md, document areas requiring further clarification or decisions:

### 1. Error Handling Strategy
- **Question**: How should rendering failures for individual components be handled?
- **Options**:
  - a) Render error placeholder and continue
  - b) Skip component entirely
  - c) Fail entire surface render
- **Current approach**: Render `a2ui_unknown` placeholder for unsupported types

### 2. Transport Implementation
- **Question**: Which transport(s) should the PoC support?
- **Options**:
  - a) Mock only (GenServer sending messages)
  - b) SSE client (Req + SSE)
  - c) WebSocket client
  - d) A2A protocol adapter
- **Current approach**: Mock for PoC; abstract via `A2UI.Transport` behaviour for extensibility

### 3. Input Debounce Tuning
- **Question**: What's the optimal debounce value for TextField inputs?
- **Current**: 300ms
- **Considerations**: Balance between responsiveness and server load

### 4. Template Render Limits
- **Question**: Should template items use LiveView streams for large lists?
- **Options**:
  - a) Standard `for` comprehension (simpler, current approach)
  - b) `phx-update="stream"` for better performance
- **Consideration**: v0.8 spec doesn't require virtualization; defer to future

### 5. Custom Component Registration
- **Question**: How should applications register custom components?
- **Options**:
  - a) Module-based catalog (`defmodule MyApp.A2UI.Catalog`)
  - b) Runtime registration (`A2UI.Catalog.register("Chart", MyChart)`)
  - c) Behaviour-based with compile-time validation
- **Current approach**: Defer custom catalogs to post-PoC

### 6. Action Callback Interface
- **Question**: Should action callback be async or sync?
- **Current**: Sync callback `callback.(user_action, socket)`
- **Alternative**: PubSub broadcast or Task.async for non-blocking

### 7. v0.9 Migration Path
- **Question**: When to switch default protocol version?
- **Current**: v0.8 default, v0.9 via adapter
- **Future**: Once v0.9 is widely adopted, consider making it default

## Future Extensions (Out of Scope)

1. **Real Transport**: SSE/WebSocket to actual agent
2. **Full Catalog**: List, Tabs, Modal, Image, Icon, etc.
3. **Custom Catalogs**: Application-specific components
4. **Catalog Negotiation**: Capability exchange protocol
5. **v0.9 Full Support**: String interpolation, validation functions, HLC timestamps
6. **Performance**: Component diffing, batch updates

## Conclusion

This design validates that A2UI's architecture maps naturally to Phoenix LiveView:
- Adjacency list → Elixir map by ID
- Data binding → JSON Pointer traversal
- Two-way binding → `phx-change` + assign updates
- User actions → `phx-click` + context resolution

The 8-component subset demonstrates forms, layouts, and interactions. The architecture cleanly separates parsing, state, binding, and rendering for maintainability and testability.
