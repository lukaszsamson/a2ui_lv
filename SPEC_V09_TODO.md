# A2UI v0.9 Spec Conformance TODO (Renderer Core)

Tracks what is still missing, stubbed, or non-conformant for **A2UI protocol v0.9** based on the local docs and schemas shipped in this repo.

**Primary sources (v0.9):**
- Protocol spec: `docs/A2UI/specification/v0_9/docs/a2ui_protocol.md`
- Evolution guide: `docs/A2UI/specification/v0_9/docs/evolution_guide.md`
- Wire schemas: `docs/A2UI/specification/v0_9/json/server_to_client.json`, `docs/A2UI/specification/v0_9/json/client_to_server.json`
- Catalog + types: `docs/A2UI/specification/v0_9/json/standard_catalog.json`, `docs/A2UI/specification/v0_9/json/common_types.json`
- Prompt rules: `docs/A2UI/specification/v0_9/json/standard_catalog_rules.txt`
- Metadata schemas: `docs/A2UI/specification/v0_9/json/a2ui_client_capabilities.json`, `docs/A2UI/specification/v0_9/json/a2ui_data_broadcast.json`

**Out of scope in this file:** concrete transports (HTTP/SSE/WebSocket/A2A wiring). Plumbing may exist; end-to-end transport conformance is tracked elsewhere.

---

## Implementation snapshot (today)

**Renderer library:**
- Session/state machine: `A2UI.Session`, `A2UI.Surface` (`lib/a2ui/session.ex`, `lib/a2ui/surface.ex`)
- JSONL parsing: `A2UI.Parser` + versioned parsers (`lib/a2ui/parser*.ex`)
- Catalog negotiation (minimal): `A2UI.Catalog.Resolver`, `A2UI.Catalog.Registry` (`lib/a2ui/catalog/*`)
- Binding (version-aware scoping): `A2UI.Binding` (`lib/a2ui/binding.ex`)
- Canonical data model ops: `A2UI.JsonPointer`, `A2UI.DataPatch` (`lib/a2ui/json_pointer.ex`, `lib/a2ui/data_patch.ex`)
- v0.9 entrypoints: `A2UI.V0_9.Adapter` (`lib/a2ui/v0_9/adapter.ex`)
- Phoenix adapter + catalog: `A2UI.Phoenix.Live`, `A2UI.Phoenix.Renderer`, `A2UI.Phoenix.Catalog.Standard` (`lib/a2ui/phoenix/*`)

**Compatibility strategy decision:** ✅ **Canonical internal model = v0.9**, adapt v0.8 into it at parse time.

---

## ✅ Implemented (v0.9 core)

### Server → client envelopes

- ✅ `createSurface` → parsed as `A2UI.Messages.BeginRendering` (root_id forced to `"root"`) and applied via `A2UI.Session`/`A2UI.Surface`
- ✅ `updateComponents` → parsed as `A2UI.Messages.SurfaceUpdate` (v0.9 discriminator format)
- ✅ `updateDataModel` → parsed as `A2UI.Messages.DataModelUpdate` and applied with v0.9 replace/delete semantics
- ✅ `deleteSurface`

### Version-aware path scoping

- ✅ v0.8 vs v0.9 template scoping is versioned in `A2UI.Binding.expand_path/3` and used by the Phoenix catalog via `binding_opts/1`.

### Data model updates (v0.9 semantics)

- ✅ `updateDataModel` replaces value at `path` (or replaces root for `nil`/`/`)
- ✅ delete semantics when `value` is omitted (internal sentinel + `JsonPointer.delete/2`)

### Catalog negotiation (minimal)

- ✅ v0.9 requires `catalogId` (schema requires it; resolver enforces it)
- ✅ standard catalog ID defined in `A2UI.V0_9.Adapter.standard_catalog_id/0`
- ✅ inline catalogs not supported (negotiation rejects them)

### `broadcastDataModel`

- ✅ stored per-surface in `A2UI.Surface.broadcast_data_model?`
- ✅ payload builder exists: `A2UI.DataBroadcast.build/1`
- ✅ Phoenix adapter passes broadcast payload to event transport via `opts[:data_broadcast]`

### v0.9 component-level compatibility (single Phoenix catalog)

- ✅ all 18 standard components render in `A2UI.Phoenix.Catalog.Standard`
- ✅ v0.8↔v0.9 prop renames normalized by `A2UI.Props.Adapter` (justify/align, variant, trigger/content, tabs, ChoicePicker, Slider min/max, TextField value, etc.)
- ✅ template rendering supports both:
  - v0.9 collections: lists
  - v0.8 legacy collections: numeric-key maps

### Checks + `string_format` implementation

- ✅ checks evaluation engine exists (`A2UI.Checks`)
- ✅ string interpolation engine exists (`A2UI.Functions.string_format/4`)

---

## P0 — Still missing / incorrect (v0.9 conformance)

### P0.1 Dynamic values: FunctionCall evaluation is not wired

Per `docs/A2UI/specification/v0_9/json/common_types.json`, `DynamicString`, `DynamicNumber`, `DynamicBoolean`, and `DynamicStringList` may be:
- literal values
- `{ "path": "..." }`
- **FunctionCall** (`%{"call" => ..., "args" => ..., "returnType" => ...}`)

**Current gap:**
- `A2UI.Binding.resolve/4` does not evaluate `FunctionCall` dynamic values; catalog renderers frequently call `Binding.resolve/4`, so FunctionCall values can leak into HEEx and crash (non-HTML-safe maps), and required v0.9 behaviors like `string_format` won’t run.

**TODO:**
- Introduce a versioned dynamic-value evaluator (either in `A2UI.Binding` or a dedicated `A2UI.DynamicValue`) that:
  - detects `%{"call" => ...}` and evaluates via the negotiated catalog functions (at minimum the standard functions)
  - resolves `args` recursively as `DynamicValue` (path/literal/nested call)
  - validates `returnType` consistency (especially for `DynamicBoolean`/`LogicExpression`)

### P0.2 v0.9 `action.context` shape is not handled

Per the v0.9 protocol examples, a component’s `action.context` is an **object map** of `DynamicValue`s (not the v0.8 adjacency-list array).

**Current gap:**
- `A2UI.Phoenix.Live` resolves v0.8 list-style context entries (`[%{"key" => ..., "value" => ...}]`) but ignores the v0.9 map form, producing an empty context for v0.9 actions.

**TODO:**
- Support both shapes:
  - v0.8 list-of-entries
  - v0.9 map-of-values
- When resolving v0.9 map values, use the dynamic-value evaluator (P0.1) so context can include `FunctionCall`s (e.g., `now`) and `{path: ...}`.

### P0.3 `now()` support

The v0.9 protocol docs use `now()` in examples:
- as a `FunctionCall` dynamic value (`%{"call":"now","returnType":"string"}`)
- inside `${...}` interpolation examples

**TODO:**
- Decide whether `now` is treated as a built-in function (not listed in `standard_catalog.json`) and implement it accordingly.

---

## P1 — Remaining “strict renderer” items (not blocked by transports)

### P1.1 Property-level schema validation

Current validation focuses on:
- unknown component types
- safety limits (count/depth/data size)

**TODO:**
- Validate incoming v0.9 components against the negotiated catalog schemas:
  - required fields (including the `component` discriminator)
  - enums (`Icon.name`, justify/align, variants, etc.)
  - `unevaluatedProperties` / `additionalProperties: false`

### P1.2 Markdown rendering for `Text`

v0.9 docs state `Text` supports simple Markdown (no HTML/images/links).

**TODO:** render a restricted subset (or explicitly document the unsupported status).

### P1.3 v0.9 “VALIDATION_FAILED” error format (recommended by docs)

The v0.9 protocol docs recommend a standard payload for validation feedback loops:
`%{"error" => %{"code" => "VALIDATION_FAILED", "surfaceId" => ..., "path" => ..., "message" => ...}}`

**Status:**
- `A2UI.Event.validation_failed/3` exists.

**TODO:**
- Ensure renderer-generated validation errors for v0.9 surfaces can be emitted in this format (where applicable), and decide how to map internal validation failures to `{path, message}`.

### P1.4 Create-surface ordering (optional strictness)

The v0.9 protocol says `updateComponents` must not be sent before `createSurface`.

**Current behavior:** updates can arrive early and are buffered implicitly (surface not ready until `createSurface`).

**TODO (strict mode only):** reject or flag updates for unknown surfaces until `createSurface` is received.

---

## Test gaps

- Add tests exercising:
  - `DynamicString` with FunctionCall (`string_format`) in `Text.text`
  - v0.9 `action.context` as a map with both `{path: ...}` and `FunctionCall` values
  - `now()` behavior (once decided/implemented)
