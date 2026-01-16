# A2UI v0.8 Spec Conformance TODO

Tracks what is still missing, stubbed, or non-conformant for **A2UI protocol v0.8** based on the local docs and schemas shipped in this repo.

**Primary sources (v0.8):**
- Protocol spec: `docs/A2UI/specification/v0_8/docs/a2ui_protocol.md`
- A2A extension: `docs/A2UI/specification/v0_8/docs/a2ui_extension_specification.md`
- Renderer guide: `docs/A2UI/docs/guides/renderer-development.md`
- References: `docs/A2UI/docs/reference/messages.md`, `docs/A2UI/docs/reference/components.md`
- Wire schemas: `docs/A2UI/specification/v0_8/json/server_to_client.json`, `docs/A2UI/specification/v0_8/json/client_to_server.json`
- Standard catalog: `docs/A2UI/specification/v0_8/json/standard_catalog_definition.json`

---

## Implementation snapshot (today)

**Renderer library:**
- Session/state machine: `A2UI.Session`, `A2UI.Surface` (`lib/a2ui/session.ex`, `lib/a2ui/surface.ex`)
- JSONL parsing: `A2UI.Parser` (`lib/a2ui/parser.ex`)
- Binding: `A2UI.Binding` (`lib/a2ui/binding.ex`)
- Phoenix adapter: `A2UI.Phoenix.Live`, `A2UI.Phoenix.Renderer` (`lib/a2ui/phoenix/*`)
- Standard Phoenix catalog: `A2UI.Phoenix.Catalog.Standard` (all 18 v0.8 components) (`lib/a2ui/phoenix/catalog/standard.ex`)
- Catalog registry: `A2UI.Catalog.Registry` (`lib/a2ui/catalog/registry.ex`)
- Transport abstraction: `A2UI.Transport.UIStream`, `A2UI.Transport.Events` + in-process `A2UI.Transport.Local` (`lib/a2ui/transport/*`)

**What’s already covered well:**
- ✅ 4/4 server→client envelopes: `surfaceUpdate`, `dataModelUpdate`, `beginRendering`, `deleteSurface`
- ✅ progressive render gating: UI renders only after `beginRendering`
- ✅ v0.8 `weight` application for Row/Column descendants
- ✅ `beginRendering.styles` stored + applied as CSS vars (standard catalog `font`, `primaryColor`)
- ✅ template expansion supports map collections (v0.8 canonical array encoding: numeric-key maps), with scoped JSON Pointer strings for bound values/events

---

## P0 — Spec violations / incorrect behavior

### ~~P0.1 BoundValue "path + literal*" initialization shorthand is not spec-compliant~~ ✅ FIXED

Spec requirement (v0.8 protocol section "Path and Literal Value (Initialization Shorthand)"):
- Client MUST update the data model at `path` with the `literal*` value, then bind to that path.

**Resolution:**
- `A2UI.Initializers` now **always overwrites** the data model at the specified path with the literal value, per spec.
- Root pointers (`""` and `"/"`) are now supported.
- Pointers containing numeric segments (e.g., `/items/0/name`) are still skipped as a safety measure to avoid creating maps with string-numeric keys where arrays were intended. Array structures should be initialized via explicit `dataModelUpdate` messages.

### ~~P0.2 Server→client "single-key envelope" is not enforced~~ ✅ ACCEPTABLE

The "exactly ONE" requirement is only in the schema's prose description - the JSON schema itself doesn't use `oneOf` or `minProperties`/`maxProperties` to enforce it.

**Current behavior (acceptable):**
- `A2UI.Parser` matches known keys and processes the first recognized one
- Additional top-level keys are ignored (not rejected)

This follows Postel's law: "be conservative in what you send, be liberal in what you accept." Real-world LLM agents are unlikely to generate multi-key envelopes, and being lenient about extra keys improves interoperability.

### ~~P0.3 A2A `inlineCatalogs` metadata shape is wrong~~ ✅ FIXED

Spec requirement (v0.8 protocol + A2A extension):
- `metadata.a2uiClientCapabilities.inlineCatalogs` is an **array** of catalog definition documents.

**Resolution:**
- `A2UI.ClientCapabilities` now stores `inline_catalogs` as a list of catalog definition documents.
- Each catalog document has `catalogId`, `components`, and optionally `styles`.
- `to_a2a_metadata/1` correctly emits `inlineCatalogs` as an array.
- Added `get_inline_catalog/2` to look up inline catalogs by ID.

---

## P1 — Missing end-to-end protocol behaviors (required by docs for a “renderer”)

### ~~P1.1 Client→server event sending (userAction + error)~~ ✅ IMPLEMENTED

Docs require the client to send **single-event envelopes** back to the server:
- `{"userAction": ...}` on action
- `{"error": ...}` on client errors

**Resolution:**
- `A2UI.Phoenix.Live.init/2` now accepts `:event_transport` option (PID of a process implementing `A2UI.Transport.Events`).
- When configured, both `userAction` and `error` events are sent via the transport per spec Section 5.
- Callbacks are still invoked for local handling in addition to transport.
- Usage example:
  ```elixir
  {:ok, transport} = A2UI.Transport.Local.start_link(event_handler: &handle_event/1)
  socket = A2UI.Phoenix.Live.init(socket, event_transport: transport)
  ```

### ~~P1.2 A2A extension packaging (mimeType + client capabilities)~~ ✅ PROVISIONS READY

A2A extension spec requirements:
- A2UI messages are A2A `DataPart` with `metadata.mimeType = "application/json+a2ui"`.
- Every client→server A2A message must include `metadata.a2uiClientCapabilities`.

**Implementation (plumbing only - no A2A transport yet):**

Modules added to make implementing A2A transport straightforward:

- `A2UI.A2A.Protocol` - Protocol constants:
  - `mime_type/0` → `"application/json+a2ui"`
  - `extension_uri/0`, `extension_uri(:v0_8 | :v0_9)` → A2A extension URIs
  - `client_capabilities_key/0` → `"a2uiClientCapabilities"`
  - `client_role/0` → `"user"`, `server_role/0` → `"agent"`

- `A2UI.A2A.DataPart` - Message packaging:
  - `wrap_envelope/1` → Wraps A2UI envelope in DataPart with mimeType
  - `unwrap_envelope/1` → Extracts A2UI envelope from DataPart
  - `build_client_message/2` → Builds full A2A message with capabilities
  - `build_server_message/1` → Builds server→client A2A message
  - `extract_envelopes/1` → Extracts A2UI envelopes from A2A message
  - `parse_client_capabilities/1` → Parses capabilities from A2A metadata

- `A2UI.Session` updates:
  - Now defaults to `ClientCapabilities.default()` (not nil)
  - `client_capabilities/1` → Returns session's capabilities
  - `supports_catalog?/2` → Checks catalog support

- Version entrypoints:
  - `A2UI.V0_8.extension_uri/0` → v0.8 A2A extension URI
  - `A2UI.V0_9.Adapter.extension_uri/0` → v0.9 A2A extension URI

**Remaining work:**
- Implement actual A2A transport (HTTP client, SSE/WebSocket)

### P1.3 Streaming UI transport

Docs describe:
- one-way JSONL stream (often SSE/WebSocket/etc.) for UI updates
- separate channel for events (often A2A)

Current behavior:
- No concrete SSE/WebSocket transport implementation exists (only in-process transport).

---

## P2 — Catalog negotiation and strict validation

### P2.1 Catalog negotiation and compatibility checks are incomplete

Docs specify:
- Client advertises `supportedCatalogIds` (and optionally `inlineCatalogs`)
- Server chooses a catalog and sends it in `beginRendering.catalogId`
- Client must default to the standard catalog if omitted

Current behavior:
- Catalog dispatch exists (`A2UI.Catalog.Registry` + `A2UI.Phoenix.Renderer`), but there is no compatibility validation:
  - no check that `beginRendering.catalogId` is supported by client capabilities
  - no policy for unknown catalogId (warn vs error vs fallback)
  - no inline catalog ingestion (likely intentionally disabled for safety; requires explicit policy)

### ~~P2.2 Standard catalog ID mismatch across v0.8 sources~~ ✅ RESOLVED

**Resolution:**

The implementation now supports all known v0.8 standard catalog ID aliases for maximum compatibility:

- `"https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json"` (from protocol spec)
- `"a2ui.org:standard_catalog_0_8_0"` (from server_to_client.json schema)

**Implementation:**
- `A2UI.V0_8.standard_catalog_ids/0` returns all known aliases
- `A2UI.V0_8.standard_catalog_id?/1` checks if an ID is a known alias
- `A2UI.Catalog.Registry.register_v0_8_standard/1` registers a module for all aliases
- `A2UI.ClientCapabilities.new/1` defaults to all aliases in `supportedCatalogIds`
- Application startup registers the standard catalog module for all aliases

**TODO (v0.9):** When v0.9 support is added, create `A2UI.V0_9.standard_catalog_ids/0` for the v0.9 catalog ID:
`"https://a2ui.dev/specification/v0_9/standard_catalog.json"`

### P2.3 Catalog-schema property validation is not implemented

Strict conformance implies validating incoming component instances against the active catalog schema:
- required properties present
- enums respected (e.g., distribution/alignment, `Icon.name`)
- `additionalProperties: false` honored (reject unknown props)
- component wrapper must have exactly one type key (v0.8)

Current behavior:
- only component type allowlist + global safety limits (count/depth/data size)
- property-level validation is not enforced at parse/apply time

---

## P3 — Data model & template semantics (spec ambiguity)

### ~~P3.1 Arrays in templates vs v0.8 wire schema limitations~~ ✅ RESOLVED

**Resolution:**

The v0.8 wire schema intentionally does NOT include a `valueList`/`valueArray` type. Arrays are encoded using the **canonical numeric-key map representation**:

```json
{"dataModelUpdate": {
  "surfaceId": "main",
  "path": "/items/0",
  "contents": [{"key": "name", "valueString": "first"}]
}}
{"dataModelUpdate": {
  "surfaceId": "main",
  "path": "/items/1",
  "contents": [{"key": "name", "valueString": "second"}]
}}
```

This produces a data model structure:
```json
{"items": {"0": {"name": "first"}, "1": {"name": "second"}}}
```

**Implementation:**
- The renderer (`lib/a2ui/phoenix/catalog/standard.ex`) now only iterates maps in template expansion.
- `stable_template_keys()` detects numeric-key maps and sorts them numerically (0, 1, 2, ...) rather than lexicographically.
- The non-spec-compliant list fallback has been removed from `render_children`.
- `A2UI.Binding.get_at_pointer/2` works correctly with numeric string keys for paths like `/items/0/name`.
- The wire decoder (`lib/a2ui/surface.ex`) correctly builds maps (not lists) for all `dataModelUpdate` messages.

---

## P4 — Security and robustness improvements (not strictly required by schema, but required by docs/production)

- cycle detection in component graph (depth limit mitigates but doesn’t guarantee correctness)
- URL allowlist / scheme validation for media components (`Image`, `Video`, `AudioPlayer`)
- decide when to emit `{"error": ...}` vs silently ignore invalid `dataModelUpdate` entries
- “strict mode” toggle: reject vs warn+render for unknown props/enums/invalid children references

---

## Documentation mismatches to be aware of

Some docs in `docs/A2UI/docs/*` appear out-of-sync with the authoritative v0.8 standard catalog:
- `docs/A2UI/docs/reference/components.md` uses “Material icon” names like `check_circle`, but v0.8 catalog `Icon.name` enum uses `check`, `error`, etc.
- `docs/A2UI/docs/reference/components.md` shows a `Checkbox` component name, but the v0.8 catalog uses `CheckBox`.

Decision needed:
- strict mode: follow `docs/A2UI/specification/v0_8/json/standard_catalog_definition.json` only
- compatibility mode: accept common aliases (e.g., `Checkbox` → `CheckBox`, material icon aliases)

---

## Non-spec project guidelines (optional cleanup)

Not required for spec conformance, but useful for Phoenix consistency:
- Use `<.input>` for all form inputs (Slider / DateTimeInput / MultipleChoice currently use raw `<input>`s).
