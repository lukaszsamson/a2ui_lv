"use strict";
/**
 * A2UI Message Builder
 *
 * Functions to build A2UI protocol messages from parsed JSON responses.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildA2uiMessages = buildA2uiMessages;
exports.buildDataModelUpdateMessages = buildDataModelUpdateMessages;
exports.isActionRequest = isActionRequest;
exports.parseActionRequest = parseActionRequest;
/**
 * Build A2UI messages from parsed JSON response.
 */
function buildA2uiMessages(parsed, surfaceId) {
    const messages = [];
    // 1. surfaceUpdate message
    if (parsed.surfaceUpdate) {
        const surfaceUpdate = { ...parsed.surfaceUpdate, surfaceId };
        messages.push(JSON.stringify({ surfaceUpdate }));
    }
    // 2. dataModelUpdate message
    if (parsed.dataModel) {
        messages.push(...buildDataModelUpdateMessages(parsed.dataModel, surfaceId));
    }
    // 3. beginRendering message
    const beginRendering = {
        surfaceId,
        root: parsed.beginRendering?.root || "root",
    };
    if (typeof parsed.beginRendering?.catalogId === "string") {
        beginRendering.catalogId = parsed.beginRendering.catalogId;
    }
    if (parsed.beginRendering?.styles && typeof parsed.beginRendering.styles === "object") {
        beginRendering.styles = parsed.beginRendering.styles;
    }
    messages.push(JSON.stringify({ beginRendering }));
    return messages;
}
/**
 * Convert data model to A2UI contents format (adjacency list).
 */
function buildDataModelUpdateMessages(dataModel, surfaceId) {
    if (!dataModel || typeof dataModel !== "object")
        return [];
    const updates = [];
    // Root replacement. Non-scalar values are created as empty maps and filled via path updates.
    const rootContents = buildContentsForContainer(dataModel);
    updates.push({ contents: rootContents });
    // Recursively add path updates for nested containers and array elements.
    const nested = buildNestedUpdates("", dataModel);
    updates.push(...nested);
    return updates.map((u) => JSON.stringify({
        dataModelUpdate: {
            surfaceId,
            ...(u.path ? { path: u.path } : {}),
            contents: u.contents,
        },
    }));
}
function buildContentsForContainer(container) {
    if (!container || typeof container !== "object")
        return [];
    if (Array.isArray(container)) {
        return container.map((value, idx) => contentEntry(String(idx), value));
    }
    return Object.entries(container).map(([key, value]) => contentEntry(key, value));
}
function contentEntry(key, value) {
    const entry = { key };
    if (typeof value === "string") {
        entry.valueString = value;
    }
    else if (typeof value === "number") {
        entry.valueNumber = value;
    }
    else if (typeof value === "boolean") {
        entry.valueBoolean = value;
    }
    else if (value && typeof value === "object") {
        // v0.8: valueMap entries must not contain nested valueMap entries; use empty map placeholder
        // and populate children via path-based dataModelUpdate messages.
        entry.valueMap = [];
    }
    else {
        entry.valueString = String(value);
    }
    return entry;
}
function buildNestedUpdates(basePath, container) {
    if (!container || typeof container !== "object")
        return [];
    const entries = Array.isArray(container)
        ? container.map((v, i) => [String(i), v])
        : Object.entries(container);
    const updates = [];
    for (const [key, value] of entries) {
        if (!value || typeof value !== "object")
            continue;
        const path = `${basePath}/${escapeJsonPointerSegment(key)}`;
        const contents = buildContentsForContainer(value);
        // Skip empty container updates; the parent placeholder already creates the empty map.
        if (contents.length > 0) {
            updates.push({ path, contents });
        }
        updates.push(...buildNestedUpdates(path, value));
    }
    return updates;
}
// RFC 6901 JSON Pointer segment escaping
function escapeJsonPointerSegment(segment) {
    return segment.replace(/~/g, "~0").replace(/\//g, "~1");
}
/**
 * Check if prompt is an action request (contains __ACTION__ marker).
 */
function isActionRequest(prompt) {
    return prompt.trimStart().startsWith("__ACTION__");
}
/**
 * Parse action request format:
 * __ACTION__
 * Original: <original prompt>
 * Action: <action name>
 * Context: <JSON context>
 * DataModel: <JSON data model>
 */
function parseActionRequest(prompt) {
    const lines = prompt.trimStart().split("\n");
    let originalPrompt = "";
    let actionName = "";
    let actionContext = {};
    let dataModel = {};
    for (const line of lines) {
        if (line.startsWith("OriginalJSON: ")) {
            try {
                originalPrompt = JSON.parse(line.substring("OriginalJSON: ".length));
            }
            catch (e) {
                console.error("[Claude] Failed to parse original prompt JSON:", e);
            }
        }
        else if (line.startsWith("Original: ")) {
            // Backwards-compatible fallback
            originalPrompt = line.substring("Original: ".length);
        }
        else if (line.startsWith("Action: ")) {
            actionName = line.substring("Action: ".length);
        }
        else if (line.startsWith("Context: ")) {
            try {
                actionContext = JSON.parse(line.substring("Context: ".length));
            }
            catch (e) {
                console.error("[Claude] Failed to parse action context:", e);
            }
        }
        else if (line.startsWith("DataModel: ")) {
            try {
                dataModel = JSON.parse(line.substring("DataModel: ".length));
            }
            catch (e) {
                console.error("[Claude] Failed to parse data model:", e);
            }
        }
    }
    return { originalPrompt, actionName, actionContext, dataModel };
}
