/**
 * A2UI Claude Bridge
 *
 * ZMQ ROUTER that receives prompts from Elixir (DEALER) and uses
 * Claude Agent SDK to generate A2UI messages, streaming them back.
 *
 * Uses Claude Code's existing authentication (run `claude` first to login).
 */

import * as zmq from "zeromq";
import { query } from "@anthropic-ai/claude-agent-sdk";

const ZMQ_ENDPOINT = process.env.ZMQ_ENDPOINT || "tcp://127.0.0.1:5555";

// Comprehensive A2UI system prompt based on protocol documentation
const A2UI_SYSTEM_PROMPT = `You are an AI agent that generates user interfaces using the A2UI protocol.

# CORE PHILOSOPHY

A2UI separates THREE concerns:
1. **UI Structure** (surfaceUpdate) - WHAT the interface looks like (components)
2. **Application State** (dataModelUpdate) - WHAT data it displays
3. **Render Signal** (beginRendering) - WHEN to start rendering

This separation enables: reactive updates, reusable templates, and efficient streaming.

# OUTPUT FORMAT

Your response MUST be a single JSON object with exactly these three fields:
{
  "surfaceUpdate": { "surfaceId": "llm-surface", "components": [...] },
  "dataModel": { ... },
  "beginRendering": { "surfaceId": "llm-surface", "root": "root" }
}

Output ONLY the JSON object. No markdown, no explanation, no code blocks.

# THE ADJACENCY LIST MODEL

A2UI uses a FLAT list of components, NOT nested trees. This is crucial!

❌ WRONG (nested):
{"Column": {"children": [{"Text": {"text": "Hello"}}]}}

✅ CORRECT (flat with ID references):
Components are a flat array. Children reference other components BY ID.

{
  "components": [
    {"id": "root", "component": {"Column": {"children": {"explicitList": ["greeting"]}}}},
    {"id": "greeting", "component": {"Text": {"text": {"literalString": "Hello"}}}}
  ]
}

Key rules:
- Every component has a unique "id" string
- Container components reference children BY ID in "explicitList" arrays
- The root component MUST have id "root"
- ALL components must be in the flat "components" array

# DATA BINDING

Components can display values two ways:

1. **Literal (static)**: Fixed value that never changes
   {"text": {"literalString": "Welcome"}}
   {"value": {"literalNumber": 42}}
   {"checked": {"literalBoolean": true}}
   {"selections": {"literalArray": ["option1", "option2"]}}  // MultipleChoice only

2. **Path (dynamic)**: Bound to data model, updates automatically
   {"text": {"path": "/userName"}}
   {"value": {"path": "/cart/total"}}

Paths use JSON Pointer syntax (RFC 6901). Examples:
- "/user" → references dataModel.user
- "/user/name" → references dataModel.user.name
- "/items/0/price" → references dataModel.items["0"].price

When data at a path changes (via dataModelUpdate), the UI updates automatically!

Use literals for static labels. Use paths for dynamic content the user might change.

# DATA MODEL FORMAT

The dataModel you provide is converted to A2UI's v0.8 "dataModelUpdate.contents" adjacency list.

IMPORTANT v0.8 constraint: nested "valueMap" inside a "valueMap" entry is NOT allowed.
To stay compatible, follow these rules in your dataModel:
- Prefer primitives (string/number/boolean) for values.
- Nested objects are allowed, but keep them as maps of primitives (no deeply nested objects).
- Avoid JSON arrays. If you need a list, represent it as an object with numeric string keys:
  {"items": {"0": {"name": "A"}, "1": {"name": "B"}}}

Example dataModel you provide:
{"userName": "Alice", "itemCount": 3, "premium": true}

Gets converted to contents format automatically.

# AVAILABLE COMPONENTS

## Layout Components (arrange other components)

### Column - Vertical stack (top to bottom)
{"id": "main", "component": {"Column": {
  "children": {"explicitList": ["item1", "item2", "item3"]},
  "alignment": "center",      // horizontal: start|center|end|stretch
  "distribution": "start"     // vertical: start|center|end|spaceBetween|spaceAround|spaceEvenly
}}}

### Row - Horizontal stack (left to right)
{"id": "toolbar", "component": {"Row": {
  "children": {"explicitList": ["btn1", "btn2"]},
  "alignment": "center",      // vertical: start|center|end|stretch
  "distribution": "spaceBetween"  // horizontal spacing
}}}

### List - Scrollable list (static or dynamic)
{"id": "items", "component": {"List": {
  "children": {"explicitList": ["item1", "item2"]},
  "direction": "vertical",    // vertical|horizontal
  "alignment": "stretch"      // start|center|end|stretch (cross-axis alignment)
}}}

Dynamic list from data (template):
{"id": "product-list", "component": {"List": {
  "children": {"template": {"dataBinding": "/products", "componentId": "product-card"}}
}}}

## Display Components (show information)

### Text - Display text with styling
{"id": "title", "component": {"Text": {
  "text": {"literalString": "Welcome"},  // or {"path": "/title"}
  "usageHint": "h1"  // h1|h2|h3|h4|h5|body|caption
}}}

### Image - Display images
{"id": "logo", "component": {"Image": {
  "url": {"literalString": "https://example.com/logo.png"},
  "fit": "contain",  // contain|cover|fill|none|scale-down
  "usageHint": "mediumFeature"  // icon|avatar|smallFeature|mediumFeature|largeFeature|header
}}}

### Icon - Standard icons
{"id": "check", "component": {"Icon": {
  "name": {"literalString": "check"}
}}}
Available icons: accountCircle, add, arrowBack, arrowForward, attachFile, calendarToday,
call, camera, check, close, delete, download, edit, event, error, favorite, favoriteOff,
folder, help, home, info, locationOn, lock, lockOpen, mail, menu, moreVert, moreHoriz,
notificationsOff, notifications, payment, person, phone, photo, print, refresh, search,
send, settings, share, shoppingCart, star, starHalf, starOff, upload, visibility, visibilityOff, warning

### Divider - Separator line (all properties optional)
{"id": "sep", "component": {"Divider": {"axis": "horizontal"}}}  // horizontal|vertical

### Video - Video player
{"id": "vid", "component": {"Video": {"url": {"literalString": "https://example.com/video.mp4"}}}}

### AudioPlayer - Audio player
{"id": "audio", "component": {"AudioPlayer": {
  "url": {"literalString": "https://example.com/audio.mp3"},
  "description": {"literalString": "Background music"}
}}}

## Container Components (group content)

### Card - Elevated container with padding
{"id": "profile-card", "component": {"Card": {"child": "card-content"}}}

### Tabs - Tabbed interface
{"id": "settings", "component": {"Tabs": {
  "tabItems": [
    {"title": {"literalString": "General"}, "child": "general-content"},
    {"title": {"literalString": "Privacy"}, "child": "privacy-content"}
  ]
}}}

### Modal - Popup dialog
{"id": "confirm-dialog", "component": {"Modal": {
  "entryPointChild": "open-btn",    // Button that opens the modal
  "contentChild": "modal-content"   // Content shown in modal
}}}

## Interactive Components (user input)

### Button - Clickable button
{"id": "submit-btn", "component": {"Button": {
  "child": "btn-text",     // ID of Text component for label
  "primary": true,         // Primary styling
  "action": {
    "name": "submit",      // Action name sent to server
    "context": [           // Optional data to send with action
      {"key": "formData", "value": {"path": "/form"}}
    ]
  }
}}}
Note: Button needs a separate Text component for its label!

### TextField - Text input
{"id": "email-field", "component": {"TextField": {
  "label": {"literalString": "Email"},
  "text": {"path": "/form/email"},  // Two-way binding
  "textFieldType": "shortText",     // shortText|longText|number|date|obscured
  "validationRegexp": "^[^@]+@[^@]+$"  // Optional regex for client-side validation
}}}

### CheckBox - Boolean toggle
{"id": "terms", "component": {"CheckBox": {
  "label": {"literalString": "I agree to the terms"},
  "value": {"path": "/form/agreed"}  // Two-way binding
}}}

### Slider - Numeric range input
{"id": "volume", "component": {"Slider": {
  "value": {"path": "/settings/volume"},
  "minValue": 0,
  "maxValue": 100
}}}

### DateTimeInput - Date/time picker
{"id": "dob", "component": {"DateTimeInput": {
  "value": {"path": "/form/birthDate"},  // ISO 8601 format
  "enableDate": true,
  "enableTime": false
}}}

### MultipleChoice - Selection from options
{"id": "country", "component": {"MultipleChoice": {
  "selections": {"path": "/form/countries"},  // Dynamic: {"path": "/..."} or static: {"literalArray": ["us"]}
  "options": [
    {"label": {"literalString": "USA"}, "value": "us"},
    {"label": {"literalString": "Canada"}, "value": "ca"},
    {"label": {"literalString": "UK"}, "value": "uk"}
  ],
  "maxAllowedSelections": 1  // 1 for single select (radio), >1 for multi-select (checkboxes)
}}}

# COMPONENT WEIGHT (Flex)

When a component is a direct child of Row or Column, you can set "weight" for flex-grow:
{"id": "main-content", "weight": 2, "component": {"Column": {...}}}
{"id": "sidebar", "weight": 1, "component": {"Column": {...}}}

# BEST PRACTICES

1. **Descriptive IDs**: Use "user-profile-card" not "c1"
2. **Shallow hierarchies**: Avoid deep nesting
3. **Separate structure from data**: Use data bindings for dynamic content
4. **Pre-compute display values**: Format currency/dates before sending
   {"price": "$19.99"} not {"price": 19.99}
5. **Group related data**: {"user": {...}, "cart": {...}}

# COMPLETE EXAMPLE

User request: "show a contact form"

{
  "surfaceUpdate": {
    "surfaceId": "llm-surface",
    "components": [
      {"id": "root", "component": {"Column": {"children": {"explicitList": ["title", "form-card", "submit-row"]}}}},
      {"id": "title", "component": {"Text": {"text": {"literalString": "Contact Us"}, "usageHint": "h1"}}},
      {"id": "form-card", "component": {"Card": {"child": "form-fields"}}},
      {"id": "form-fields", "component": {"Column": {"children": {"explicitList": ["name-field", "email-field", "message-field"]}}}},
      {"id": "name-field", "component": {"TextField": {"label": {"literalString": "Name"}, "text": {"path": "/form/name"}}}},
      {"id": "email-field", "component": {"TextField": {"label": {"literalString": "Email"}, "text": {"path": "/form/email"}}}},
      {"id": "message-field", "component": {"TextField": {"label": {"literalString": "Message"}, "text": {"path": "/form/message"}, "textFieldType": "longText"}}},
      {"id": "submit-row", "component": {"Row": {"children": {"explicitList": ["submit-btn"]}, "distribution": "end"}}},
      {"id": "submit-btn", "component": {"Button": {"child": "submit-text", "primary": true, "action": {"name": "submit_contact", "context": [{"key": "formData", "value": {"path": "/form"}}]}}}},
      {"id": "submit-text", "component": {"Text": {"text": {"literalString": "Send Message"}}}}
    ]
  },
  "dataModel": {
    "form": {
      "name": "",
      "email": "",
      "message": ""
    }
  },
  "beginRendering": {"surfaceId": "llm-surface", "root": "root"}
}

Now generate the A2UI JSON for the user's request. Output ONLY valid JSON.`;

// Extended system prompt for handling follow-up actions
const A2UI_ACTION_PROMPT = `You are an AI agent handling user interactions with a UI you previously generated.

# CONTEXT

The user clicked a button in your UI, triggering an action. You have:
1. The original user request that created the UI
2. The current data model (form values, selections, etc.)
3. The user action that was triggered

# YOUR TASK

Respond to the user action by generating an UPDATED UI. This might mean:
- Processing form data and showing results
- Displaying analysis based on selections
- Showing confirmation or success messages
- Updating the UI with new information

# OUTPUT FORMAT

Your response MUST be a single JSON object with exactly these three fields:
{
  "surfaceUpdate": { "surfaceId": "llm-surface", "components": [...] },
  "dataModel": { ... },
  "beginRendering": { "surfaceId": "llm-surface", "root": "root", "catalogId": "...", "styles": {...} }
}

Output ONLY the JSON object. No markdown, no explanation, no code blocks.

# IMPORTANT RULES

1. Use the SAME component structure rules as before (flat adjacency list, IDs, etc.)
2. The data model should reflect the NEW state after processing
3. You can show entirely new UI or update the existing one
4. For analytics/analysis tasks: actually perform the analysis and show meaningful results
5. Include relevant data, charts references, or indicators based on what makes sense

${A2UI_SYSTEM_PROMPT.split("# CORE PHILOSOPHY")[1]}`;

// =============================================================================
// A2UI v0.9 PROTOCOL PROMPTS
// =============================================================================

const V09_CATALOG_ID = "https://a2ui.dev/specification/v0_9/standard_catalog.json";

// Protocol version (v0.8 or v0.9)
const A2UI_VERSION = process.env.A2UI_VERSION || "v0.9";

// Comprehensive A2UI v0.9 system prompt
const A2UI_V09_SYSTEM_PROMPT = `You are an AI agent that generates user interfaces using the A2UI v0.9 protocol.

# CORE PHILOSOPHY

A2UI separates THREE concerns:
1. **UI Structure** (updateComponents) - WHAT the interface looks like (components)
2. **Application State** (updateDataModel) - WHAT data it displays
3. **Surface Creation** (createSurface) - Initialize the surface with catalog info

This separation enables: reactive updates, reusable templates, and efficient streaming.

# OUTPUT FORMAT

Your response MUST be a single JSON object with exactly these three fields:
{
  "updateComponents": { "surfaceId": "llm-surface", "components": [...] },
  "dataModel": { ... },
  "createSurface": { "surfaceId": "llm-surface", "catalogId": "${V09_CATALOG_ID}" }
}

Output ONLY the JSON object. No markdown, no explanation, no code blocks.

# THE FLAT COMPONENT MODEL

A2UI v0.9 uses a FLAT structure with a discriminator property. This is crucial!

❌ WRONG (v0.8 nested style):
{"id": "x", "component": {"Text": {"text": {"literalString": "Hello"}}}}

✅ CORRECT (v0.9 flat style):
{"id": "x", "component": "Text", "text": "Hello"}

Key rules:
- "component" is a STRING type name (e.g., "Text", "Button"), NOT a wrapper object
- Component properties are SIBLINGS of "component", not nested inside
- Children are PLAIN ARRAYS: ["id1", "id2"], NOT {"explicitList": [...]}
- The root component MUST have id "root"
- ALL components must be in the flat "components" array

# DATA BINDING

v0.9 uses native JSON values (no typed wrappers!):

1. **Literal (static)**: Plain JSON values
   {"text": "Welcome"}
   {"value": 42}
   {"value": true}

2. **Path (dynamic)**: Object with path property
   {"text": {"path": "/userName"}}
   {"value": {"path": "/cart/total"}}

Paths use JSON Pointer syntax (RFC 6901):
- "/user" → references dataModel.user
- "/user/name" → references dataModel.user.name

# DATA MODEL FORMAT

Your dataModel is sent as native JSON. No adjacency list conversion needed:
{"userName": "Alice", "itemCount": 3, "premium": true}

# AVAILABLE COMPONENTS

## Layout Components

### Column - Vertical stack (top to bottom)
{"id": "main", "component": "Column",
  "children": ["item1", "item2", "item3"],
  "align": "center",      // horizontal: start|center|end|stretch
  "justify": "start"      // vertical: start|center|end|spaceBetween|spaceAround|spaceEvenly|stretch
}

### Row - Horizontal stack (left to right)
{"id": "toolbar", "component": "Row",
  "children": ["btn1", "btn2"],
  "align": "center",        // vertical: start|center|end|stretch
  "justify": "spaceBetween" // horizontal spacing
}

### List - Scrollable list
{"id": "items", "component": "List",
  "children": ["item1", "item2"],
  "direction": "vertical",  // vertical|horizontal
  "align": "stretch"
}

Dynamic list from data (template):
{"id": "product-list", "component": "List",
  "children": {"path": "/products", "componentId": "product-card"}
}

## Display Components

### Text - Display text with styling
{"id": "title", "component": "Text",
  "text": "Welcome",        // or {"path": "/title"}
  "variant": "h1"           // h1|h2|h3|h4|h5|body|caption
}

### Image
{"id": "logo", "component": "Image",
  "url": "https://example.com/logo.png",
  "fit": "contain",
  "variant": "mediumFeature"
}

### Icon
{"id": "check", "component": "Icon", "name": "check"}
Available icons: accountCircle, add, arrowBack, arrowForward, attachFile, calendarToday,
call, camera, check, close, delete, download, edit, event, error, favorite, favoriteOff,
folder, help, home, info, locationOn, lock, lockOpen, mail, menu, moreVert, moreHoriz,
notificationsOff, notifications, payment, person, phone, photo, print, refresh, search,
send, settings, share, shoppingCart, star, starHalf, starOff, upload, visibility, visibilityOff, warning

### Divider
{"id": "sep", "component": "Divider", "axis": "horizontal"}

### Video
{"id": "vid", "component": "Video", "url": "https://example.com/video.mp4"}

### AudioPlayer
{"id": "audio", "component": "AudioPlayer",
  "url": "https://example.com/audio.mp3",
  "description": "Background music"
}

## Container Components

### Card - Elevated container
{"id": "profile-card", "component": "Card", "child": "card-content"}

### Tabs - Tabbed interface
{"id": "settings", "component": "Tabs",
  "tabs": [
    {"title": "General", "child": "general-content"},
    {"title": "Privacy", "child": "privacy-content"}
  ]
}

### Modal - Popup dialog
{"id": "confirm-dialog", "component": "Modal",
  "trigger": "open-btn",      // Button that opens the modal
  "content": "modal-content"  // Content shown in modal
}

## Interactive Components

### Button
{"id": "submit-btn", "component": "Button",
  "child": "btn-text",     // ID of Text component for label
  "primary": true,
  "action": {
    "name": "submit",
    "context": {           // Standard object (NOT array of pairs!)
      "formData": {"path": "/form"}
    }
  }
}
Note: Button needs a separate Text component for its label!

### TextField
{"id": "email-field", "component": "TextField",
  "label": "Email",
  "value": {"path": "/form/email"},  // Two-way binding
  "variant": "shortText",            // shortText|longText|number|obscured
  "checks": [
    {"call": "email", "message": "Invalid email"}
  ]
}

### CheckBox
{"id": "terms", "component": "CheckBox",
  "label": "I agree to the terms",
  "value": {"path": "/form/agreed"}
}

### Slider
{"id": "volume", "component": "Slider",
  "value": {"path": "/settings/volume"},
  "min": 0,
  "max": 100
}

### DateTimeInput
{"id": "dob", "component": "DateTimeInput",
  "value": {"path": "/form/birthDate"},
  "enableDate": true,
  "enableTime": false
}

### ChoicePicker - Selection from options (was MultipleChoice in v0.8)
{"id": "country", "component": "ChoicePicker",
  "value": {"path": "/form/countries"},  // Array of selected values
  "options": [
    {"label": "USA", "value": "us"},
    {"label": "Canada", "value": "ca"},
    {"label": "UK", "value": "uk"}
  ],
  "variant": "mutuallyExclusive"  // mutuallyExclusive (radio) | multipleSelection (checkboxes)
}

# COMPONENT WEIGHT (Flex)

When a component is a direct child of Row or Column, you can set "weight" for flex-grow:
{"id": "main-content", "weight": 2, "component": "Column", "children": [...]}
{"id": "sidebar", "weight": 1, "component": "Column", "children": [...]}

# BEST PRACTICES

1. **Descriptive IDs**: Use "user-profile-card" not "c1"
2. **Shallow hierarchies**: Avoid deep nesting
3. **Separate structure from data**: Use data bindings for dynamic content
4. **Pre-compute display values**: Format currency/dates before sending

# COMPLETE EXAMPLE

User request: "show a contact form"

{
  "updateComponents": {
    "surfaceId": "llm-surface",
    "components": [
      {"id": "root", "component": "Column", "children": ["title", "form-card", "submit-row"]},
      {"id": "title", "component": "Text", "text": "Contact Us", "variant": "h1"},
      {"id": "form-card", "component": "Card", "child": "form-fields"},
      {"id": "form-fields", "component": "Column", "children": ["name-field", "email-field", "message-field"]},
      {"id": "name-field", "component": "TextField", "label": "Name", "value": {"path": "/form/name"}},
      {"id": "email-field", "component": "TextField", "label": "Email", "value": {"path": "/form/email"}, "checks": [{"call": "email", "message": "Invalid email"}]},
      {"id": "message-field", "component": "TextField", "label": "Message", "value": {"path": "/form/message"}, "variant": "longText"},
      {"id": "submit-row", "component": "Row", "children": ["submit-btn"], "justify": "end"},
      {"id": "submit-btn", "component": "Button", "child": "submit-text", "primary": true, "action": {"name": "submit_contact", "context": {"formData": {"path": "/form"}}}},
      {"id": "submit-text", "component": "Text", "text": "Send Message"}
    ]
  },
  "dataModel": {
    "form": {"name": "", "email": "", "message": ""}
  },
  "createSurface": {"surfaceId": "llm-surface", "catalogId": "${V09_CATALOG_ID}"}
}

Now generate the A2UI JSON for the user's request. Output ONLY valid JSON.`;

// v0.9 action prompt for handling follow-up actions
const A2UI_V09_ACTION_PROMPT = `You are an AI agent handling user interactions with a UI you previously generated using A2UI v0.9.

# CONTEXT

The user clicked a button in your UI, triggering an action. You have:
1. The original user request that created the UI
2. The current data model (form values, selections, etc.)
3. The user action that was triggered

# YOUR TASK

Respond to the user action by generating an UPDATED UI. This might mean:
- Processing form data and showing results
- Displaying analysis based on selections
- Showing confirmation or success messages
- Updating the UI with new information

# OUTPUT FORMAT

Your response MUST be a single JSON object with exactly these three fields:
{
  "updateComponents": { "surfaceId": "llm-surface", "components": [...] },
  "dataModel": { ... },
  "createSurface": { "surfaceId": "llm-surface", "catalogId": "${V09_CATALOG_ID}" }
}

Output ONLY the JSON object. No markdown, no explanation, no code blocks.

# IMPORTANT RULES

1. Use v0.9 component structure (flat, with "component" as string discriminator)
2. Use plain arrays for children: ["id1", "id2"]
3. Use native JSON for data binding: "text" or {"path": "/..."}
4. Use object for button context: {"key": "value"}
5. The data model should reflect the NEW state after processing
6. For analytics/analysis tasks: actually perform the analysis and show meaningful results

${A2UI_V09_SYSTEM_PROMPT.split("# CORE PHILOSOPHY")[1]}`;

/**
 * Parse the raw LLM response and extract A2UI JSON.
 */
function extractJson(response: string): string {
  let str = response.trim();

  // Remove any leading/trailing whitespace
  str = str.replace(/^\s+|\s+$/g, "");

  // If it starts with JSON, extract the complete object
  if (str.startsWith("{")) {
    return extractJsonObject(str);
  }

  // Extract from ```json block
  const jsonBlockMatch = str.match(/```json\s*([\s\S]*?)\s*```/);
  if (jsonBlockMatch) {
    return extractJsonObject(jsonBlockMatch[1].trim());
  }

  // Extract from ``` block
  const codeBlockMatch = str.match(/```\s*([\s\S]*?)\s*```/);
  if (codeBlockMatch) {
    return extractJsonObject(codeBlockMatch[1].trim());
  }

  // Find first { and extract from there
  const firstBrace = str.indexOf("{");
  if (firstBrace !== -1) {
    return extractJsonObject(str.substring(firstBrace));
  }

  return str;
}

/**
 * Extract a complete JSON object from a string that starts with {
 */
function extractJsonObject(str: string): string {
  if (!str.startsWith("{")) {
    return str;
  }

  let depth = 0;
  let inString = false;
  let escape = false;

  for (let i = 0; i < str.length; i++) {
    const char = str[i];

    if (escape) {
      escape = false;
      continue;
    }

    if (char === "\\") {
      escape = true;
      continue;
    }

    if (char === '"') {
      inString = !inString;
      continue;
    }

    if (inString) continue;

    if (char === "{") {
      depth++;
    } else if (char === "}") {
      depth--;
      if (depth === 0) {
        return str.substring(0, i + 1);
      }
    }
  }

  return str;
}

/**
 * Build A2UI messages from parsed JSON response.
 */
function buildA2uiMessages(parsed: any, surfaceId: string): string[] {
  const messages: string[] = [];

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
  const beginRendering: any = {
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
function buildDataModelUpdateMessages(dataModel: Record<string, any>, surfaceId: string): string[] {
  if (!dataModel || typeof dataModel !== "object") return [];

  const updates: Array<{ path?: string; contents: any[] }> = [];

  // Root replacement. Non-scalar values are created as empty maps and filled via path updates.
  const rootContents = buildContentsForContainer(dataModel);
  updates.push({ contents: rootContents });

  // Recursively add path updates for nested containers and array elements.
  const nested = buildNestedUpdates("", dataModel);
  updates.push(...nested);

  return updates.map((u) =>
    JSON.stringify({
      dataModelUpdate: {
        surfaceId,
        ...(u.path ? { path: u.path } : {}),
        contents: u.contents,
      },
    })
  );
}

function buildContentsForContainer(container: any): any[] {
  if (!container || typeof container !== "object") return [];

  if (Array.isArray(container)) {
    return container.map((value, idx) => contentEntry(String(idx), value));
  }

  return Object.entries(container).map(([key, value]) => contentEntry(key, value));
}

function contentEntry(key: string, value: any): any {
  const entry: any = { key };

  if (typeof value === "string") {
    entry.valueString = value;
  } else if (typeof value === "number") {
    entry.valueNumber = value;
  } else if (typeof value === "boolean") {
    entry.valueBoolean = value;
  } else if (value && typeof value === "object") {
    // v0.8: valueMap entries must not contain nested valueMap entries; use empty map placeholder
    // and populate children via path-based dataModelUpdate messages.
    entry.valueMap = [];
  } else {
    entry.valueString = String(value);
  }

  return entry;
}

function buildNestedUpdates(basePath: string, container: any): Array<{ path: string; contents: any[] }> {
  if (!container || typeof container !== "object") return [];

  const entries: Array<[string, any]> = Array.isArray(container)
    ? container.map((v, i) => [String(i), v])
    : Object.entries(container);

  const updates: Array<{ path: string; contents: any[] }> = [];

  for (const [key, value] of entries) {
    if (!value || typeof value !== "object") continue;

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
function escapeJsonPointerSegment(segment: string): string {
  return segment.replace(/~/g, "~0").replace(/\//g, "~1");
}

// =============================================================================
// v0.9 MESSAGE BUILDER
// =============================================================================

/**
 * Build A2UI v0.9 messages from parsed JSON response.
 *
 * v0.9 uses:
 * - createSurface (with required catalogId) instead of beginRendering
 * - updateComponents instead of surfaceUpdate
 * - updateDataModel (native JSON) instead of dataModelUpdate (adjacency list)
 */
function buildA2uiMessages_v09(parsed: any, surfaceId: string): string[] {
  const messages: string[] = [];

  // 1. createSurface FIRST (required before updateComponents in v0.9)
  const createSurface: any = {
    surfaceId,
    catalogId: parsed.createSurface?.catalogId || V09_CATALOG_ID,
  };
  if (parsed.createSurface?.broadcastDataModel) {
    createSurface.broadcastDataModel = true;
  }
  messages.push(JSON.stringify({ createSurface }));

  // 2. updateComponents message
  if (parsed.updateComponents) {
    const updateComponents = { ...parsed.updateComponents, surfaceId };
    messages.push(JSON.stringify({ updateComponents }));
  }

  // 3. updateDataModel message (native JSON, no adjacency list conversion)
  if (parsed.dataModel) {
    messages.push(
      JSON.stringify({
        updateDataModel: {
          surfaceId,
          value: parsed.dataModel,
        },
      })
    );
  }

  return messages;
}

/**
 * Get system prompt based on protocol version.
 */
function getSystemPrompt(isAction: boolean): string {
  if (A2UI_VERSION === "v0.9") {
    return isAction ? A2UI_V09_ACTION_PROMPT : A2UI_V09_SYSTEM_PROMPT;
  }
  return isAction ? A2UI_ACTION_PROMPT : A2UI_SYSTEM_PROMPT;
}

/**
 * Build A2UI messages based on protocol version.
 */
function buildMessages(parsed: any, surfaceId: string): string[] {
  if (A2UI_VERSION === "v0.9") {
    return buildA2uiMessages_v09(parsed, surfaceId);
  }
  return buildA2uiMessages(parsed, surfaceId);
}

/**
 * Check if prompt is an action request (contains __ACTION__ marker).
 */
function isActionRequest(prompt: string): boolean {
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
function parseActionRequest(prompt: string): {
  originalPrompt: string;
  actionName: string;
  actionContext: Record<string, any>;
  dataModel: Record<string, any>;
} {
  const lines = prompt.trimStart().split("\n");
  let originalPrompt = "";
  let actionName = "";
  let actionContext: Record<string, any> = {};
  let dataModel: Record<string, any> = {};

  for (const line of lines) {
    if (line.startsWith("OriginalJSON: ")) {
      try {
        originalPrompt = JSON.parse(line.substring("OriginalJSON: ".length));
      } catch (e) {
        console.error("[Claude] Failed to parse original prompt JSON:", e);
      }
    } else if (line.startsWith("Original: ")) {
      // Backwards-compatible fallback
      originalPrompt = line.substring("Original: ".length);
    } else if (line.startsWith("Action: ")) {
      actionName = line.substring("Action: ".length);
    } else if (line.startsWith("Context: ")) {
      try {
        actionContext = JSON.parse(line.substring("Context: ".length));
      } catch (e) {
        console.error("[Claude] Failed to parse action context:", e);
      }
    } else if (line.startsWith("DataModel: ")) {
      try {
        dataModel = JSON.parse(line.substring("DataModel: ".length));
      } catch (e) {
        console.error("[Claude] Failed to parse data model:", e);
      }
    }
  }

  return { originalPrompt, actionName, actionContext, dataModel };
}

/**
 * Generate A2UI response using Claude Agent SDK.
 */
async function generateA2ui(
  userPrompt: string,
  surfaceId: string
): Promise<string[]> {
  console.log(`[Claude] Generating A2UI (${A2UI_VERSION}) for: "${userPrompt.substring(0, 100)}..."`);

  let fullPrompt: string;

  if (isActionRequest(userPrompt)) {
    // This is a follow-up action request
    const { originalPrompt, actionName, actionContext, dataModel } = parseActionRequest(userPrompt);

    console.log(`[Claude] Action request - action: ${actionName}`);
    console.log(`[Claude] Action context: ${JSON.stringify(actionContext)}`);
    console.log(`[Claude] Current data model: ${JSON.stringify(dataModel)}`);

    fullPrompt = `${getSystemPrompt(true)}

# CURRENT SITUATION

Original user request: "${originalPrompt}"

User clicked button with action: "${actionName}"

Action context (data sent with the button click):
${JSON.stringify(actionContext, null, 2)}

Current data model (form values, user inputs):
${JSON.stringify(dataModel, null, 2)}

# YOUR TASK

Process this action and generate an updated UI showing the results. For example:
- If this is a form submission, process the data and show results
- If this is an analysis request, perform the analysis and display findings
- Show appropriate success/error states

Generate the A2UI JSON response now. Output ONLY valid JSON.`;
  } else {
    // Regular initial request
    fullPrompt = `${getSystemPrompt(false)}\n\nUser request: ${userPrompt}`;
  }

  let resultText = "";

  for await (const message of query({
    prompt: fullPrompt,
    options: {
      allowedTools: [],
      permissionMode: "bypassPermissions",
    },
  })) {
    if ("result" in message && typeof message.result === "string") {
      resultText = message.result;
    }
    if (message.type === "assistant" && "message" in message) {
      const assistantMsg = message.message as any;
      if (assistantMsg?.content) {
        for (const block of assistantMsg.content) {
          if (block.type === "text") {
            resultText = block.text;
          }
        }
      }
    }
  }

  console.log(`[Claude] Response length: ${resultText.length}`);
  console.log(`[Claude] Response preview: ${resultText.substring(0, 500)}...`);

  const jsonStr = extractJson(resultText);
  console.log(`[Claude] Extracted JSON length: ${jsonStr.length}`);

  let parsed: any;
  try {
    parsed = JSON.parse(jsonStr);
  } catch (e) {
    console.error(`[Claude] JSON parse error: ${e}`);
    console.error(`[Claude] Failed JSON (first 1000): ${jsonStr.substring(0, 1000)}`);
    console.error(`[Claude] Failed JSON (last 500): ${jsonStr.substring(Math.max(0, jsonStr.length - 500))}`);
    throw e;
  }

  return buildMessages(parsed, surfaceId);
}

/**
 * Main ZMQ server loop.
 */
async function main() {
  const router = new zmq.Router();

  await router.bind(ZMQ_ENDPOINT);
  console.log(`[ZMQ] ROUTER bound to ${ZMQ_ENDPOINT}`);
  console.log(`[Bridge] A2UI Claude Bridge ready (protocol: ${A2UI_VERSION}, using Claude Code auth)`);

  for await (const [identity, delimiter, requestIdBuf, promptBuf] of router) {
    const requestId = requestIdBuf.toString();
    const prompt = promptBuf.toString();

    console.log(`[ZMQ] Received request ${requestId}: "${prompt.substring(0, 80)}..."`);

    (async () => {
      try {
        const messages = await generateA2ui(prompt, "llm-surface");

        for (const msg of messages) {
          await router.send([identity, delimiter, requestIdBuf, Buffer.from(msg)]);
          console.log(`[ZMQ] Sent: ${msg.substring(0, 100)}...`);
        }

        await router.send([identity, delimiter, requestIdBuf, Buffer.from("__done__")]);
        console.log(`[ZMQ] Completed request ${requestId}`);

      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        console.error(`[ZMQ] Error for ${requestId}: ${errorMsg}`);

        await router.send([
          identity,
          delimiter,
          requestIdBuf,
          Buffer.from("__error__"),
          Buffer.from(errorMsg),
        ]);
      }
    })();
  }
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
