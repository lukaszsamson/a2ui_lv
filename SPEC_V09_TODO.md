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

### ~~P0.1 Make path expansion version-aware (v0.8 vs v0.9 scoping differs)~~ ✅ DONE

**Implementation:**

`A2UI.Binding` now supports version-aware path expansion:

- `expand_path(path, scope_path)` - defaults to v0.8 behavior (backwards compatible)
- `expand_path(path, scope_path, version: :v0_8 | :v0_9)` - explicit version
- `resolve_path(path, data_model, scope_path, version: :v0_8 | :v0_9)` - version-aware resolution

**Scoping differences:**

| Path | v0.8 (scope: `/items/0`) | v0.9 (scope: `/items/0`) |
|------|-------------------------|-------------------------|
| `/name` | `/items/0/name` (scoped) | `/name` (absolute) |
| `name` | `/items/0/name` (scoped) | `/items/0/name` (scoped) |
| `./name` | `/items/0/name` (scoped) | `/items/0/name` (scoped) |

**Remaining work for v0.9:**
- Update `A2UI.Phoenix.Catalog.Standard` to pass version when rendering v0.9 surfaces
- Store version on `A2UI.Surface` struct (from `createSurface` message)

### ~~P0.2 Introduce an internal "data model patch" abstraction~~ ✅ DONE

**Implementation:**

`A2UI.DataPatch` provides a version-agnostic internal representation for data model updates:

**Patch Operations:**
- `{:replace_root, value}` - Replace entire data model with a map value
- `{:set_at, pointer, value}` - Set any JSON value at a JSON Pointer path
- `{:merge_at, pointer, map_value}` - Deep merge a map at a path

**Wire Format Decoders:**
- `DataPatch.from_v0_8_contents(path, contents)` - Decodes v0.8 adjacency-list format
- `DataPatch.from_v0_9_update(path, value)` - Decodes v0.9 native JSON format (prep)

**Integration:**
- `A2UI.Surface.apply_message/2` now uses DataPatch internally for DataModelUpdate
- `A2UI.Surface.apply_patch/2` - Apply a single patch to surface
- `A2UI.Surface.apply_patches/2` - Apply multiple patches in order

**Remaining work for v0.9:**
- Update `A2UI.Session` to use `from_v0_9_update/2` when parsing v0.9 `updateDataModel` messages

### ~~P0.3 Split parsing per version (and keep adapters thin)~~ ✅ DONE

**Implementation:**

Version-specific parsers with auto-detection:

**Parser Modules:**
- `A2UI.Parser` - Auto-detecting dispatcher (detects v0.8 vs v0.9 by envelope keys)
- `A2UI.Parser.V0_8` - v0.8 wire format: `surfaceUpdate`, `dataModelUpdate`, `beginRendering`
- `A2UI.Parser.V0_9` - v0.9 wire format: `createSurface`, `updateComponents`, `updateDataModel`

**Version Entrypoints:**
- `A2UI.V0_8.parse_line/1`, `A2UI.V0_8.parse_map/1` - Explicit v0.8 parsing
- `A2UI.V0_9.Adapter.parse_line/1`, `A2UI.V0_9.Adapter.parse_map/1` - Explicit v0.9 parsing
- `A2UI.V0_9.Adapter.standard_catalog_id/0` - v0.9 catalog ID

**Internal Message Compatibility:**
Both versions produce the same internal message structs (`SurfaceUpdate`, `BeginRendering`, etc.)
enabling version-agnostic downstream processing.

**Key Additions:**
- `BeginRendering.from_map_v09/1` - Handles v0.9 `createSurface` (no explicit root, has `broadcastDataModel`)
- `DataModelUpdate.from_map_v09/1` - Handles v0.9 native JSON values (includes `:delete` sentinel)
- `DataPatch.{:delete_at, pointer}` - New patch type for v0.9 delete operations
- `Binding.delete_at_pointer/2` - JSON Pointer deletion

**Remaining work for v0.9:**
- Catalog rendering needs version flag to use v0.9 path scoping rules (see P0.1)

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

