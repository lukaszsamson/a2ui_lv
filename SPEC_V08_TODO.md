# A2UI v0.8 Spec Conformance TODO

This document tracks what's missing or stubbed in the current PoC implementation for full A2UI v0.8 specification conformance.

**References:**
- [A2UI v0.8 Specification](https://a2ui.org/specification/v0.8-a2ui/)
- [A2UI v0.8 A2A Extension](https://a2ui.org/specification/v0.8-a2a-extension/)
- [Renderer Development Guide](https://a2ui.org/guides/renderer-development/)
- [Component Reference](https://a2ui.org/reference/components/)
- [Message Types Reference](https://a2ui.org/reference/messages/)

---

## 1. Missing Components

The v0.8 standard catalog includes components not yet implemented:

### Display Components

| Component | Status | Notes |
|-----------|--------|-------|
| Text | ✅ Implemented | |
| Divider | ✅ Implemented | |
| Image | ❌ **Not Implemented** | Needs `source` (URL), `alt`, `aspectRatio` props |
| Icon | ❌ **Not Implemented** | Material Icons support, `name`, `size` props |
| Video | ❌ **Not Implemented** | Needs `source`, `autoPlay`, `controls` props |
| AudioPlayer | ❌ **Not Implemented** | Needs `source`, `controls` props |

### Layout Components

| Component | Status | Notes |
|-----------|--------|-------|
| Column | ✅ Implemented | |
| Row | ✅ Implemented | |
| List | ❌ **Not Implemented** | Scrollable list with `children` (template/explicitList) |

### Container Components

| Component | Status | Notes |
|-----------|--------|-------|
| Card | ✅ Implemented | |
| Tabs | ❌ **Not Implemented** | Needs `tabs` array with `label` and `content` per tab |
| Modal | ❌ **Not Implemented** | Needs `entryPoint`, `content` child, overlay behavior |

### Interactive Components

| Component | Status | Notes |
|-----------|--------|-------|
| Button | ✅ Implemented | |
| TextField | ✅ Implemented | |
| Checkbox | ✅ Implemented | Also accepts `CheckBox` spelling |
| DateTimeInput | ❌ **Not Implemented** | Date/time picker, `value` binding, `mode` (date/time/datetime) |
| MultipleChoice | ❌ **Not Implemented** | Radio/select, `options`, `selections` binding |
| Slider | ❌ **Not Implemented** | Range input, `min`, `max`, `value`, `step` props |

### Component Property Gaps

| Property | Status | Notes |
|----------|--------|-------|
| `weight` | ❌ **Not Implemented** | Flex-grow weight for child sizing in Row/Column |

---

## 2. Missing Client-to-Server Messages

### `error` Message

**Status:** ❌ **Not Implemented**

Per spec, renderers should send an `error` message when client-side errors occur:

```json
{
  "error": {
    "surfaceId": "main",
    "message": "Component 'missing-id' not found",
    "code": "COMPONENT_NOT_FOUND",
    "details": { ... }
  }
}
```

**Required work:**
- Define error codes/types
- Add error reporting callback in `A2UI.Live`
- Hook into render failures and validation errors

---

## 3. Catalog Negotiation

**Status:** ❌ **Not Implemented**

### Agent Capabilities (A2A Extension)

Per v0.8 A2A extension, agents advertise:
```json
{
  "supportedCatalogIds": ["https://a2ui.org/catalogs/standard/v0.8"],
  "acceptsInlineCatalogs": false
}
```

### Client Capabilities

Per spec, clients must include `a2uiClientCapabilities` in every A2A message metadata:
```json
{
  "a2uiClientCapabilities": {
    "supportedCatalogIds": ["https://a2ui.org/catalogs/standard/v0.8"]
  }
}
```

### Catalog Selection

The `catalogId` from `beginRendering` is stored in `Surface.catalog_id` but:
- ❌ Not validated against supported catalogs
- ❌ Not used for component dispatch (always uses Standard catalog)
- ❌ No inline catalog support

**Required work:**
- Define catalog behavior/protocol
- Validate `catalogId` matches renderer capabilities
- Support multiple catalog registrations

---

## 4. Styles from `beginRendering`

**Status:** ❌ **Not Implemented**

Per spec, `beginRendering` can include a `styles` object:
```json
{
  "beginRendering": {
    "surfaceId": "main",
    "root": "root",
    "styles": {
      "font": "Inter",
      "primaryColor": "#3B82F6"
    }
  }
}
```

**Current state:**
- `styles` field is parsed in `BeginRendering.from_map/1` ✅
- `Surface` struct does NOT store styles ❌
- Styles are NOT applied to rendered components ❌

**Required work:**
- Add `styles` field to `Surface` struct
- Pass styles through rendering context
- Apply `font` to text components
- Apply `primaryColor` to primary buttons, links, focus rings

---

## 5. Transport Layer

**Status:** ⚠️ **Stubbed (Mock Only)**

### Current State
Only `A2UI.MockAgent` exists - sends messages via `send(pid, {:a2ui, json})`.

### Required Transports (per spec)

| Transport | Status | Notes |
|-----------|--------|-------|
| Mock/In-Process | ✅ Implemented | For testing |
| SSE (Server-Sent Events) | ❌ **Not Implemented** | Primary streaming transport |
| WebSocket | ❌ **Not Implemented** | Alternative streaming transport |
| A2A Protocol | ❌ **Not Implemented** | Full agent-to-agent protocol |

### A2A Extension Requirements

Per v0.8 A2A extension spec:
- Messages wrapped as A2A `DataPart` with `mimeType: "application/json+a2ui"`
- Extension activation via `X-A2A-Extensions` header
- Client capabilities in message metadata
- Extension URI: `https://a2ui.org/a2a-extension/a2ui/v0.8`

**Required work:**
- Define `A2UI.Transport` behaviour
- Implement SSE client (e.g., using `Req` + SSE parsing)
- Implement WebSocket client
- Implement A2A DataPart wrapping/unwrapping

---

## 6. Progressive Rendering

**Status:** ⚠️ **Partially Implemented**

### Implemented
- ✅ Components buffered until `beginRendering`
- ✅ `ready?` flag prevents premature render

### Not Implemented

| Feature | Status | Notes |
|---------|--------|-------|
| Batching window (16ms) | ❌ | Per spec: buffer updates for 16ms, batch render |
| Component diffing | ⚠️ | LiveView handles DOM diffing, but no A2UI-level optimization |
| Partial re-render | ⚠️ | LiveView re-renders entire surface on any change |

**Note:** LiveView's diffing engine partially addresses this, but explicit 16ms batching is not implemented.

---

## 7. Data Binding Gaps

### valueArray in Contents

**Status:** ⚠️ **Partial Implementation**

Current `extract_typed_value/1` handles `valueArray` but recursively calls itself:
```elixir
defp extract_typed_value(%{"valueArray" => v}), do: Enum.map(v, &extract_typed_value/1)
```

This assumes array elements have typed wrappers. Per spec, `valueArray` contents may be:
- Direct values (strings, numbers, booleans)
- Nested typed objects (`{"valueString": "..."}`)
- Nested maps (`{"valueMap": [...]}`)

**Required work:**
- Verify array element handling matches spec exactly
- Add tests for nested array structures

### Two-Way Binding for Missing Components

| Component | Binding Property | Status |
|-----------|-----------------|--------|
| MultipleChoice | `selections` (array path) | ❌ Not implemented |
| Slider | `value` (number path) | ❌ Not implemented |
| DateTimeInput | `value` (datetime path) | ❌ Not implemented |

---

## 8. Validation & Security

### Implemented
- ✅ Max components per surface (1000)
- ✅ Max render depth (30)
- ✅ Max template items (200)
- ✅ Max data model size (100KB)
- ✅ Component type allowlist

### Not Implemented

| Validation | Status | Notes |
|------------|--------|-------|
| Path validation | ❌ | Prevent access to unintended data |
| Component ID format | ❌ | Validate ID characters/length |
| Circular reference detection | ❌ | Detect child → parent cycles |
| URL validation (Image/Video) | ❌ | Validate/sanitize source URLs |

---

## 9. Stubbed/Placeholder Behaviors

### Initializer Pass

**Status:** ✅ **Implemented** (in `A2UI.Initializers`)

The path+literal initialization behavior is implemented and called from `Surface.apply_message/2` after `SurfaceUpdate`.

### Catalog Registration

**Status:** ❌ **Hardcoded**

Currently `A2UI.Catalog.Standard` is the only catalog, hardcoded in the dispatch. No registration mechanism exists.

**Required work:**
- Define `A2UI.Catalog` behaviour
- Create catalog registry
- Support runtime catalog registration
- Support catalog selection per surface

---

## 10. Testing Gaps

### Unit Tests

| Module | Coverage | Notes |
|--------|----------|-------|
| Parser | ✅ Basic | Needs edge cases |
| Binding | ✅ Good | |
| Surface | ✅ Basic | Needs more message combinations |
| Validator | ✅ Good | |
| Component | ✅ Basic | |

### Integration Tests

| Test | Status | Notes |
|------|--------|-------|
| LiveView rendering | ❌ | `DemoLiveTest` outlined but not implemented |
| Two-way binding | ❌ | Form interaction tests |
| Action dispatch | ❌ | Button click → callback tests |
| Template rendering | ❌ | Dynamic list tests |

### Missing Test Scenarios

- [ ] Multiple surfaces simultaneously
- [ ] Surface deletion mid-session
- [ ] Component updates (ID reuse)
- [ ] Large data model handling
- [ ] Invalid message handling
- [ ] Template with nested templates
- [ ] Scoped path resolution in deep nesting

---

## 11. Documentation Gaps

### Missing
- [ ] HexDocs for public modules
- [ ] Usage examples in moduledocs
- [ ] Architecture diagram
- [ ] Transport integration guide
- [ ] Custom catalog development guide

---

## Priority Order for Full Conformance

### P0 - Core Spec Compliance
1. Missing display components (Image, Icon)
2. Missing interactive components (MultipleChoice, Slider, DateTimeInput)
3. Missing container components (List, Tabs, Modal)
4. `weight` property support
5. `styles` from `beginRendering`

### P1 - Protocol Completeness
6. `error` message (client → server)
7. Catalog negotiation
8. SSE transport

### P2 - Production Readiness
9. A2A protocol support
10. WebSocket transport
11. Validation enhancements
12. Integration test suite

### P3 - Polish
13. Documentation
14. Performance optimization (batching)
15. Custom catalog support

---

## Summary

| Category | Implemented | Missing/Stubbed |
|----------|-------------|-----------------|
| Components | 8/14 | 6 (Image, Icon, Video, AudioPlayer, List, Tabs, Modal, DateTimeInput, MultipleChoice, Slider) |
| Message Types (S→C) | 4/4 | 0 |
| Message Types (C→S) | 1/2 | 1 (error) |
| Transport | 1/4 | 3 (SSE, WS, A2A) |
| Catalog Negotiation | 0% | 100% |
| Styles | 0% | 100% |
| Core Behaviors | ~80% | ~20% |

**Estimated effort for full v0.8 conformance:** Medium-High

The core architecture (parsing, binding, rendering, two-way binding) is solid. Main gaps are:
- Missing components (straightforward additions)
- Transport layer (requires external integration)
- Catalog negotiation (design decision needed)
- Styles system (moderate effort)
