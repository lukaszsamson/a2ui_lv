# A2UI v0.9 Prep / Conformance TODO

This repo currently implements a v0.8 renderer. This document lists what is needed to (a) make adding v0.9 support easy and (b) eventually claim v0.9 conformance.

**Primary sources (v0.9):**
- Protocol spec: `docs/A2UI/specification/v0_9/docs/a2ui_protocol.md`
- Evolution guide: `docs/A2UI/specification/v0_9/docs/evolution_guide.md`
- Wire schemas: `docs/A2UI/specification/v0_9/json/server_to_client.json`, `docs/A2UI/specification/v0_9/json/client_to_server.json`
- Catalog + rules: `docs/A2UI/specification/v0_9/json/standard_catalog.json`, `docs/A2UI/specification/v0_9/json/standard_catalog_rules.txt`
- Client metadata schemas: `docs/A2UI/specification/v0_9/json/a2ui_client_capabilities.json`, `docs/A2UI/specification/v0_9/json/a2ui_data_broadcast.json`

---

## High-level v0.9 changes (why it’s not a small patch)

Per `docs/A2UI/specification/v0_9/docs/evolution_guide.md`, v0.9 changes:
- Server→client envelopes: `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface` (replaces `beginRendering`/`surfaceUpdate`/`dataModelUpdate`)
- Component instances: discriminator field (`"component": "Text"`) instead of wrapper objects (`{"Text": {...}}`)
- Data model update: `path` + `value` (native JSON), not adjacency-list `contents`
- Binding: “prompt-first” values; native JSON types + `{ "path": ... }` (no `literalString` etc)
- Path scoping: in templates, **absolute paths remain absolute** (start with `/`); relative paths do **not** start with `/`
- Adds expression/function system + string interpolation + `checks` validation
- Client→server envelope renamed: `action` replaces `userAction`
- Error semantics tightened: `VALIDATION_FAILED` error format for validation feedback loop
- Adds `broadcastDataModel` and A2A metadata data model broadcast

---

## P0 — Refactors to do now (make v0.9 easy later)

### P0.1 Make path expansion version-aware (v0.8 vs v0.9 scoping differs)

Current `A2UI.Binding.expand_path/2` implements v0.8 template scoping where `"/name"` is relative when `scope_path` is set.

v0.9 requires:
- `"/company"` is always absolute, even inside templates
- `"name"` is relative in templates (joins scope)

Prep work:
- Introduce version-aware expansion, e.g.:
  - `A2UI.Binding.expand_path_v08/2`
  - `A2UI.Binding.expand_path_v09/2`
  - or `expand_path(path, scope_path, version: :v0_8 | :v0_9)`
- Ensure all bindings and two-way input writes call the correct variant for their message version.

### P0.2 Introduce an internal “data model patch” abstraction

v0.8 updates use adjacency-list `contents`; v0.9 updates are arbitrary JSON `value`.

Prep work:
- Refactor `A2UI.Surface` to support an internal update representation like:
  - `{:replace_root, value}`
  - `{:merge_at, pointer, map_value}`
  - `{:set_at, pointer, any_json_value}`
- Keep v0.8 decoding as one input format and v0.9 `updateDataModel` as another.

### P0.3 Split parsing per version (and keep adapters thin)

Prep work:
- Create `A2UI.Parser.V0_8` and `A2UI.Parser.V0_9` (or a versioned dispatcher).
- Implement `A2UI.V0_9.Adapter` to translate v0.9 messages into internal operations without forcing the rest of the renderer to care about version.
- Avoid coupling Phoenix catalog rendering to v0.8-only property names.

---

## P1 — Core v0.9 protocol implementation

### P1.1 Server→client message support

Implement parsing + application for:
- `createSurface` (replaces `beginRendering`)
  - must create/init surface and mark render-ready
  - root component semantics: v0.9 expects a component with id `"root"` (no explicit `root` field)
  - apply surface-level options like `broadcastDataModel` (see below)
- `updateComponents` (replaces `surfaceUpdate`)
  - parse component instances using `A2UI.Component.from_map_v09/1` (already exists)
  - store `weight` as in v0.8
- `updateDataModel` (replaces `dataModelUpdate`)
  - apply `{path, value}` updates (native JSON)
  - define root update semantics (path omitted vs `/`)
- `deleteSurface`

### P1.2 Client→server event support

Implement v0.9 event envelopes from `docs/A2UI/specification/v0_9/json/client_to_server.json`:
- `{"action": {...}}` (rename from v0.8 `userAction`)
- `{"error": {...}}` with strong support for:
  - `{"code": "VALIDATION_FAILED", "surfaceId": ..., "path": ..., "message": ...}`

This will likely require:
- a new error builder for v0.9 (or versioned `A2UI.Error`)
- wiring `A2UI.Transport.Events` implementations to send these envelopes

---

## P2 — v0.9 catalog and evaluation engine

### P2.1 Support v0.9 dynamic values

v0.9 replaces `literalString` / `literalNumber` / etc with:
- native JSON values, OR
- `{ "path": "..." }`

The current `A2UI.Binding.resolve/3` already accepts native strings/numbers/booleans and `{ "path": ... }`, but:
- see P0.1: v0.9 path scoping rules differ and must be versioned.

### P2.2 Implement string interpolation + function calls

v0.9 introduces:
- expression language (e.g. `${now()}`, `${formatDate(${/currentDate}, 'yyyy-MM-dd')}`)
- function catalog + `standard_catalog_rules.txt` prompt rules

Prep/design work:
- Introduce a small evaluation engine (`A2UI.Expr` + `A2UI.FunctionCatalog`) with:
  - JSON Pointer reads (absolute + relative)
  - string interpolation / `string_format`
  - safe, whitelisted functions only

### P2.3 Implement `checks` for validation

v0.9 components define `checks` that:
- produce validation messages on inputs
- disable buttons when invalid

This requires:
- evaluating boolean checks against current data model
- associating failures with specific components (UI display)

---

## P3 — Component changes from v0.8 to v0.9

From the evolution guide:
- `MultipleChoice` → `ChoicePicker` (new variants `multipleSelection` / `mutuallyExclusive`)
- `TextField.text` → `TextField.value`
- `TextField.validationRegexp` → `TextField.checks`
- `Row/Column.distribution` → `justify`
- `Row/Column.alignment` → `align`
- `usageHint` → `variant` (many components)
- `Modal.entryPointChild` → `trigger`, `Modal.contentChild` → `content`
- `Tabs.tabItems` → `tabs`
- `Slider.minValue/maxValue` → `min/max`

Plan:
- Build an adapter layer that maps v0.9 props to the current Phoenix catalog props, OR
- Add a dedicated v0.9 Phoenix catalog module implementing the v0.9 schema directly.

---

## P4 — A2A data model broadcasting (`broadcastDataModel`)

v0.9 introduces `broadcastDataModel` (surface option) which, when enabled:
- includes the **entire surface data model** in the metadata of every outgoing A2A message
- must match `docs/A2UI/specification/v0_9/json/a2ui_data_broadcast.json`

Prep work:
- store `broadcast_data_model?` per surface (from `createSurface`)
- teach `A2UI.Transport.Events` A2A implementation to attach the broadcast payload when enabled

---

## Compatibility strategy decision (recommended to document early)

Two reasonable strategies:

1) **Canonical internal model = v0.9**, adapt v0.8 into it
   - Pros: aligns with future spec direction; internal structures become simpler (native JSON objects/maps)
   - Cons: bigger refactor now; v0.8 strictness work becomes “legacy adapter”

2) **Canonical internal model = v0.8**, adapt v0.9 into it (current direction)
   - Pros: minimal short-term disruption
   - Cons: adapter must “explode” v0.9 objects into v0.8-style adjacency updates or expand internal surface update logic anyway (P0.2)

Given v0.9’s native JSON data model updates, strategy (1) is usually less work long-term, but requires agreeing on versioned path scoping semantics first (P0.1).

