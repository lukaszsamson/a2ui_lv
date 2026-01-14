# A2UI v0.8 Spec Conformance TODO

This document tracks what is still missing, stubbed, or non-conformant in the current Phoenix LiveView A2UI renderer PoC for full **A2UI protocol v0.8** conformance.

**Primary sources (v0.8):**
- Spec & docs: https://a2ui.org/specification/v0.8-a2ui/ and https://a2ui.org/reference/messages/
- Renderer guide: https://a2ui.org/guides/renderer-development/
- Standard catalog definition (authoritative component list + props): https://raw.githubusercontent.com/google/A2UI/main/specification/v0_8/json/standard_catalog_definition.json
- Wire schemas:
  - Server→client: https://raw.githubusercontent.com/google/A2UI/main/specification/v0_8/json/server_to_client.json
  - Client→server: https://raw.githubusercontent.com/google/A2UI/main/specification/v0_8/json/client_to_server.json
- A2A extension: https://a2ui.org/specification/v0.8-a2a-extension/

---

## 1. Standard Catalog Components (18 total)

The v0.8 standard catalog defines **18** component types. **All 18 are now implemented.**

### Implemented (18/18)

**Layout Components:**
- ✅ `Column` (partial; template semantics mismatch, see §4)
- ✅ `Row` (partial; template semantics mismatch, see §4)
- ✅ `Card`
- ✅ `List` (direction, alignment)

**Display Components:**
- ✅ `Text`
- ✅ `Divider`
- ✅ `Icon` (mapped to Heroicons)
- ✅ `Image` (fit, usageHint)

**Media Components:**
- ✅ `AudioPlayer` (url, description)
- ✅ `Video` (url)

**Interactive Components:**
- ✅ `Button`
- ✅ `TextField` (with `validationRegexp` support)
- ✅ `CheckBox`
- ✅ `Slider` (value, minValue, maxValue)
- ✅ `DateTimeInput` (value, enableDate, enableTime)
- ✅ `MultipleChoice` (selections, options, maxAllowedSelections)

**Container Components:**
- ✅ `Tabs` (tabItems with JS-based switching)
- ✅ `Modal` (entryPointChild, contentChild with JS-based show/hide)

### Remaining gaps in implemented components

- `Row`/`Column` template expansion supports the v0.8 **map** semantics; it also includes a non-spec **list fallback** for robustness when agents send arrays.

---

## 2. Server→Client Wire Schema Conformance Gaps

### 2.1 `surfaceUpdate.components[].weight` ✅ IMPLEMENTED

The server→client schema includes optional `weight` alongside `id` and `component`:
- It corresponds to CSS `flex-grow`.
- It may only be set when the component is a direct descendant of a `Row` or `Column`.

**Current state:** ✅ The Component struct stores `weight`, and `render_children` applies `flex-grow` via wrapper divs when `apply_weight=true` (used by Row/Column).

### 2.2 `dataModelUpdate.path` root semantics ✅ IMPLEMENTED

The server→client schema says:
- If `path` is omitted **or** set to `/`, **the entire data model will be replaced**.

**Current state:** ✅ `Surface.apply_data_update/3` now replaces the entire data model when path is `nil` or `/`.

### 2.3 `dataModelUpdate.contents` value types ✅ IMPLEMENTED

The server→client schema allows only:
- `valueString`, `valueNumber`, `valueBoolean`, `valueMap`

**Notably, the schema does not include `valueArray`.**

**Current state:** ✅ Strict v0.8 decoding in `Surface.decode_entry/1` only accepts the four allowed value types. Non-schema extensions like `valueArray` are rejected with `{:error, :ambiguous_value}` or ignored.

### 2.4 `beginRendering.catalogId` default and catalog selection (missing)

The schema indicates the client MUST default to a standard catalog if `catalogId` is omitted, but different v0.8 docs/schemas disagree on the exact identifier string (see §7.1).

**Current state:**
- `catalogId` is parsed/stored, but component dispatch is always hardcoded to the PoC’s standard catalog implementation.
- No validation that the chosen `catalogId` is supported.
- No inline catalog support.

### 2.5 `beginRendering.styles` ✅ IMPLEMENTED

The standard catalog defines global styles:
- `font` (string)
- `primaryColor` (hex color `^#[0-9a-fA-F]{6}$`)

**Current state:** ✅ `styles` is stored in `Surface.styles` and applied by `Renderer.surface_style/1` as CSS custom properties (`--a2ui-font`, `--a2ui-primary-color`) with validation.

---

## 3. Client→Server Events (Wire-Level)

Per `client_to_server.json`, only two event envelopes exist:
- `userAction`
- `error`

### 3.1 `userAction` (partially implemented)

**Current state:**
- The PoC constructs `userAction` with `name`, `surfaceId`, `sourceComponentId`, ISO8601 `timestamp`, and resolved `context`.
- It is delivered to an application callback / stored in assigns, not sent over any standardized transport.

**Missing for conformance:**
- A transport that serializes and sends this envelope to the agent/server as defined by the selected transport (A2A extension or otherwise).

### 3.2 `error` (not implemented)

`error` is allowed to be “flexible content” per schema.

**Missing for conformance:**
- Decide which renderer failures must emit `error` (parse/validation failures, unknown component, binding errors, etc.).
- Provide a transport hook to deliver it to the agent/server.

---

## 4. Data Binding + Templates (Core Behavior)

### 4.1 BoundValue resolution (mostly implemented)

Renderer guide rules include:
- `literal*` used directly
- `path` resolved via RFC6901 JSON Pointer
- `path + literal*` should initialize data at `path` with the literal, then bind to `path`

**Current state:** The PoC implements the “initializer pass” behavior for `path + literal*`.

### 4.2 Template `dataBinding` collection type ✅ IMPLEMENTED

Standard catalog template docs (for `Row`, `Column`, `List`) describe:
- `template.dataBinding` points to a **map** in the data model, and "values in the map define the list of children".

But A2UI conceptual docs also present examples using JSON **arrays** for lists.

**Current state:** ✅ The `render_children/1` template expansion now supports both:
- **Maps**: Uses `stable_template_keys/1` for deterministic ordering (numeric keys sorted numerically, others alphabetically)
- **Lists**: Fallback support for array-indexed iteration

Scope paths use the actual key/index: `"{base}/{key}"` for maps, `"{base}/{idx}"` for lists.

---

## 5. Catalog Negotiation + Capabilities (A2UI + A2A Extension)

**Missing for conformance:**
- Client capability reporting via `a2uiClientCapabilities` in A2A message metadata (required by the A2A extension spec and renderer guide).
- Optional inline catalogs support:
  - Only allowed if the agent declares `acceptsInlineCatalogs: true`.
  - Spec guidance warns against downloading catalogs at runtime for safety/prompt-injection reasons; prefer compiled-in catalogs.
- Multi-catalog dispatch:
  - Registry of catalogs by `catalogId`.
  - Surface-bound catalog selection based on `beginRendering.catalogId`.
  - Validation of component types/properties against the active catalog schema.

---

## 6. Transport (Protocol-Agnostic, but Required End-to-End)

Per https://a2ui.org/transports/ the protocol is transport-agnostic; the docs list A2A as stable and other transports as proposed/planned.

**Current state:** Only an in-process “mock agent” is implemented.

**Missing for conformance (practical):**
- Implement at least one real transport end-to-end:
  - **A2A extension** (recommended by docs): wrap A2UI messages into A2A `DataPart` with `mimeType: "application/json+a2ui"` and include `a2uiClientCapabilities` in metadata.
  - Optional: JSONL over HTTP streaming / SSE if you want a browser-native path.

---

## 7. Spec Inconsistencies / Decisions Required

These must be resolved (and documented in code) to claim strict v0.8 conformance.

### 7.1 “Standard catalog id” string inconsistency

Different v0.8 sources disagree on the default/identifier for the standard catalog, for example:
- v0.8 spec pages and A2A extension examples use a GitHub URL to `standard_catalog_definition.json`.
- `server_to_client.json` mentions a short string identifier (`a2ui.org:standard_catalog_0_8_0`) as the default when `catalogId` is omitted.

**Decision needed:** treat multiple known IDs as aliases for the same standard catalog, or pick one canonical form and normalize.

### 7.2 Arrays vs maps in the data model

The combination of:
- template `dataBinding` described as a map of values, and
- conceptual docs describing arrays,
- plus the lack of `valueArray` in `server_to_client.json`,

forces a renderer to pick an interpretation and enforce stable iteration/scoping rules.

### 7.3 Depth/shape of `valueMap`

The wire schema describes `valueMap` as an adjacency list of key/value entries, but the exact allowed nesting depth is not consistently captured across examples vs schema strictness.

**Decision needed:** strict schema adherence (and require nested object updates via `path`) vs permissive recursive `valueMap` decoding.

---

## 8. Validation & Security (Beyond Current Limits)

The PoC currently enforces only basic safety bounds (component count, render depth, template expansion limit, max data model size, and a component type allowlist).

Missing for conformance and safety:
- Validate component properties against the active catalog schema:
  - required props present
  - enums respected (e.g., `Icon.name.literalString` allowed values)
  - `additionalProperties: false` honored (reject unknown props if claiming strict conformance)
- Validate `surfaceUpdate.components[].component` has exactly one key (one component type).
- Validate and apply `weight` only where allowed (direct child of `Row`/`Column`).
- Cycle detection in component graphs (depth limits prevent infinite recursion, but do not guarantee correctness).
- URL safety rules for media components (`Image`, `Video`, `AudioPlayer`) before adding them.

---

## 9. Testing Status (What’s Still Missing)

The repo now includes LiveView integration tests for:
- progressive rendering / beginRendering gating
- two-way binding for `TextField` and `CheckBox`
- action dispatch for `Button`
- `deleteSurface`
- template expansion unique DOM ids

Missing tests for full v0.8 conformance:
- `surfaceUpdate.weight` application + validation (only allowed under `Row`/`Column`)
- `beginRendering.styles` application (`font`, `primaryColor`)
- catalog negotiation behavior (catalogId selection, supported catalogs, inline catalogs)
- strict schema validation failures (unknown props, missing required props, invalid enums)
- template `dataBinding` map semantics + stable ordering + scope path formation
- error event emission (`{"error": {...}}`) for representative failure cases

---

## Priority Order (for strict v0.8 conformance)

### P0 — Fix schema-level mismatches ✅ DONE
1. ~~Implement `surfaceUpdate.components[].weight` end-to-end~~ ✅ (Component.weight + render_children flex-grow)
2. ~~Make `dataModelUpdate` root updates replace (not merge) when `path` is omitted or `/`~~ ✅ (Surface.apply_data_update)
3. ~~Resolve "list" representation and implement template `dataBinding` map semantics~~ ✅ (stable_template_keys handles maps)
4. ~~Remove or formalize any out-of-schema `dataModelUpdate` extensions (`valueArray`, recursive valueMap) behind a compatibility mode~~ ✅ (strict v0.8 decoding only)
5. ~~Store + apply `beginRendering.styles` per standard catalog (`font`, `primaryColor`)~~ ✅ (Surface.styles + Renderer CSS vars)

### P1 — Complete the standard catalog ✅ DONE
6. ~~Implement the remaining 10 standard catalog components~~ ✅
7. ~~Implement missing props/behaviors in existing components (e.g., `TextField.validationRegexp`)~~ ✅

### P2 — Protocol completeness
8. Catalog negotiation: client capabilities, catalog selection, inline catalogs (if allowed)
9. Real transport: A2A extension integration (or another transport) for both directions
10. Client→server `error` reporting strategy

---

## Summary (today)

| Area | Status |
|------|--------|
| Standard catalog components | **18/18 implemented** |
| Server→client message envelopes | 4/4 parsed/handled (`surfaceUpdate`, `dataModelUpdate`, `beginRendering`, `deleteSurface`) |
| Client→server envelopes | `userAction` constructed but not transported; `error` not implemented |
| Catalog negotiation | catalogId parsed only; no negotiation/selection/validation |
| Styles | stored + applied via CSS vars (`--a2ui-font`, `--a2ui-primary-color`, `--a2ui-primary-rgb`) |
| Key conformance blockers | ~~weight~~, ~~root replace~~, ~~template maps~~, ~~valueArray~~ — **All P0 resolved** |



Component todo:
  Top issues / mismatches vs the v0.8 standard catalog (and/or expected behavior)

  - DateTimeInput timezone semantics are still a design choice: `datetime-local` inputs are stored as `...Z` (treated as UTC) for stable round-tripping; this does not convert offsets/timezones.

  Guideline notes (not spec, but project rules)

  - Slider, DateTimeInput, and MultipleChoice use raw <input>s instead of <.input> (lib/a2ui/catalog/standard.ex:648, lib/a2ui/catalog/standard.ex:708, lib/a2ui/catalog/standard.ex:788). If you want, I can
    refactor those to <.input> while keeping the UX.
