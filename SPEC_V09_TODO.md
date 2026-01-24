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

**Transport status (FYI):**
- HTTP+SSE transport is implemented in `lib/a2ui/transport/http/*` and documented in `TRANSPORT_SSE.md`.
- ✅ SSE `data:` stream contains only valid A2UI envelopes (no transport-level JSON like `{"streamDone": ...}` or ad-hoc `{"error": ...}`). Stream completion and errors are signaled via HTTP connection close + optional SSE comments.

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
- ✅ `${now()}` function call support in string interpolation

### Dynamic values: FunctionCall evaluation

- ✅ `A2UI.DynamicValue` module evaluates FunctionCall dynamic values
- ✅ `A2UI.Binding.resolve/4` detects `%{"call" => ...}` and delegates to `DynamicValue.evaluate/4`
- ✅ Recursive arg resolution for nested FunctionCalls
- ✅ Standard functions supported: `required`, `email`, `regex`, `length`, `numeric`, `string_format` (see P0.1), plus built-in `now`

### v0.9 `action.context` shape

- ✅ `A2UI.Phoenix.Live.resolve_action_context/4` supports both:
  - v0.8 list-of-entries (`[%{"key" => ..., "value" => ...}]`)
  - v0.9 map-of-values (`%{"key" => <DynamicValue>}`)
- ✅ v0.9 map values resolved via `DynamicValue.evaluate/4` (supports FunctionCalls, paths, literals)

### `now()` function

- ✅ Implemented as built-in function in `A2UI.DynamicValue` (FunctionCall evaluation)
- ✅ Returns ISO 8601 timestamp string

---

## P0 — Spec / schema mismatches (must-fix for v0.9 conformance)

### P0.1 `string_format` FunctionCall args key

**Status:** ✅ Fixed.

Per the v0.9 standard catalog schema, `string_format` uses `args.value` (not `args.template`).

**Implementation:**
- `A2UI.DynamicValue.execute_function("string_format", ...)` now uses `args["value"]` as the canonical key
- `args["template"]` is supported as a legacy fallback for backward compatibility
- All tests updated to use `args.value` per spec
- Added explicit test for legacy `args.template` fallback

### P0.2 `string_format` interpolation `${now()}` support

**Status:** ✅ Fixed.

The v0.9 standard catalog description for `string_format` explicitly includes function calls such as `${now()}`.

**Implementation:**
- Added `execute_function("now", [], ...)` handler in `A2UI.Functions` that returns ISO 8601 timestamp
- Updated moduledoc to document supported function calls in interpolation
- Added tests for `${now()}` interpolation (standalone, mixed with text, combined with paths)
- Unknown functions return `nil` (interpolated as empty string) - this is documented and tested

---

## P1 — Remaining "strict renderer" items (not blocked by transports)

### P1.1 Schema + structural validation

Current validation focuses on:
- unknown component types
- safety limits (count/depth/data size)
- ✅ root component validation (v0.9 only)

**Status:** Partially implemented.

**Implemented:**
- ✅ v0.9 requires component with `id: "root"` - validated during `createSurface`/BeginRendering
  - `A2UI.Validator.validate_has_root/1` checks for root component
  - `A2UI.Session.apply_message/2` for BeginRendering validates root exists (v0.9 only)
  - v0.8 surfaces allow any component as root (specified by `root_id` in beginRendering)
  - Returns `{:error, :missing_root_component}` if validation fails

**TODO (remaining):**
- Validate incoming v0.9 components against the negotiated catalog schemas:
  - required fields (including the `component` discriminator)
  - enums (`Icon.name`, justify/align, variants, etc.)
  - `unevaluatedProperties` / `additionalProperties: false`
- Validate protocol-level and structural rules:
  - envelope must contain exactly one of: `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`
  - optional strict ordering: reject/flag `updateComponents` for unknown `surfaceId` (see P1.4)

### P1.2 Markdown rendering for `Text`

v0.9 docs state `Text` supports simple Markdown (no HTML/images/links).

**Status:** Not implemented. Requires design decision on markdown subset and adding a markdown library.

**TODO:** render a restricted subset (or explicitly document the unsupported status).

### P1.3 v0.9 "VALIDATION_FAILED" error format

The v0.9 protocol docs recommend a standard payload for validation feedback loops:
`%{"error" => %{"code" => "VALIDATION_FAILED", "surfaceId" => ..., "path" => ..., "message" => ...}}`

**Status:** ✅ Implemented.
- `A2UI.Event.validation_failed/3` builds the correct format
- `A2UI.Event.generic_error/4` handles other error types

**Note:** Usage of `VALIDATION_FAILED` in response to input validation is a design decision - currently validation errors are displayed locally via component checks without emitting to transport.

### P1.4 Create-surface ordering (optional strictness)

The v0.9 protocol says `updateComponents` must not be sent before `createSurface`.

**Current behavior:** updates can arrive early and are buffered implicitly (surface not ready until `createSurface`).

**Status:** Not implemented (optional strictness).

**TODO (strict mode only):** reject or flag updates for unknown surfaces until `createSurface` is received.

---

## Test gaps

- ✅ `DynamicValue` tests: `test/a2ui/dynamic_value_test.exs`
- ✅ v0.9 `action.context` map tests: `test/a2ui/phoenix/live_test.exs`
- ✅ `now()` tests: `test/a2ui/dynamic_value_test.exs`
- ✅ `DynamicString` with FunctionCall (`string_format`) in `Text.text` component rendering: `test/a2ui/dynamic_value_test.exs` "Text component integration" section
- ✅ `string_format` FunctionCall args using spec-correct `args.value`: `test/a2ui/dynamic_value_test.exs`
- ✅ Legacy `args.template` fallback for backward compatibility: `test/a2ui/dynamic_value_test.exs`
- ✅ `${now()}` inside `A2UI.Functions.string_format/4`: `test/a2ui/functions_test.exs` "string_format/4 - function calls" section
- ✅ Root component validation: `test/a2ui/validator_test.exs` "validate_has_root/1" section + `test/a2ui/session_test.exs` "root component validation on beginRendering" section
