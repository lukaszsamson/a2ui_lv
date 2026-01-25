# A2UI v0.8/v0.9 Conformance TODO

Concrete items still required for full protocol conformance based on the current code in `lib/a2ui/*`.

## Shared (v0.8 + v0.9)
- Catalog schema validation: add `A2UI.Catalog.Validator` to load JSON schemas
  (standard + custom), cache compiled schemas, and validate each component
  instance for required fields, enums, and `additionalProperties: false`.
- Catalog negotiation policy toggles: config for strict reject vs warn-and-fallback
  when catalogId is unsupported or inline catalogs are rejected.
- Custom catalog support: allow registering custom catalog modules and schemas,
  and let `A2UI.Catalog.Resolver` accept supported custom catalog IDs.
- Inline catalog support: accept inline catalogs only when the agent card
  advertises `acceptsInlineCatalogs: true` and policy allows, then validate
  against those inline schemas.
- Validation error propagation: decide and implement when to emit client error
  envelopes for invalid `surfaceUpdate`/`updateComponents`/`dataModelUpdate` vs
  silently ignoring, and wire those errors through event transports.

## v0.8-specific
- Component wrapper validation: enforce exactly one component type key in v0.8
  component wrappers (schema-level check).
- Compatibility aliases (optional but needed for docs parity): handle
  `Checkbox` -> `CheckBox` and material icon name aliases when in compatibility
  mode.

## v0.9-specific
- updateComponents schema validation: enforce v0.9 catalog schema rules,
  including `component` discriminator, enums, and
  `unevaluatedProperties`/`additionalProperties: false`.
- Envelope strictness: enforce exactly one top-level server->client key
  (`createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`).
- Ordering strictness: optionally reject `updateComponents` before
  `createSurface` and emit `VALIDATION_FAILED` errors in strict mode.


## Transport (A2A) conformance gaps
Note: current target is legacy A2A flavor (`X-A2A-Extensions`, `kind` fields).
- Header compliance: send `A2A-Extensions` (not `X-A2A-Extensions`) and include
  `A2A-Version` with Major.Minor for all A2A HTTP requests; consider dual-header
  fallback for older agents. (A2A v1.0 change)
- Part JSON shape: stop emitting `kind` fields in `TextPart` and `DataPart` JSON
  (use `{ "text": "..." }` and `{ "data": {..} }`), while accepting legacy
  `kind` for compatibility. (A2A v1.0 change)
- A2UI DataPart strictness: require `metadata.mimeType: application/json+a2ui`
  when unwrapping/validating A2UI DataParts (remove lenient fallback or make it
  an explicit compatibility mode).
- A2A bindings: add JSON-RPC and gRPC transport modules implementing
  `A2UI.Transport.UIStream` and `A2UI.Transport.Events`, plus binding-specific
  request/stream wiring and configuration; current library only ships HTTP+SSE.
