/**
 * A2A Protocol utilities for A2UI
 *
 * Handles A2A message format parsing, building, and validation.
 */

// A2UI extension URI
export const A2UI_EXTENSION_URI = "https://a2ui.org/a2a-extension/a2ui/v0.8";

// A2UI MIME type for DataParts
export const A2UI_MIME_TYPE = "application/json+a2ui";

// A2A message roles
export const CLIENT_ROLE = "user";
export const AGENT_ROLE = "agent";

// Metadata keys
export const CLIENT_CAPABILITIES_KEY = "a2uiClientCapabilities";
export const DATA_BROADCAST_KEY = "a2uiDataBroadcast";

/**
 * A2A DataPart structure
 */
export interface DataPart {
  data: Record<string, any>;
  metadata?: {
    mimeType?: string;
    [key: string]: any;
  };
}

/**
 * A2A Message structure
 */
export interface A2AMessage {
  role: "user" | "agent";
  metadata?: {
    [CLIENT_CAPABILITIES_KEY]?: ClientCapabilities;
    [DATA_BROADCAST_KEY]?: Record<string, any>;
    [key: string]: any;
  };
  parts: Array<DataPart | TextPart>;
}

/**
 * A2A Text Part
 */
export interface TextPart {
  text: string;
}

/**
 * A2A Task Message wrapper
 */
export interface A2ATaskMessage {
  message: A2AMessage;
}

/**
 * Client capabilities from A2UI extension
 */
export interface ClientCapabilities {
  supportedCatalogIds?: string[];
  inlineCatalogs?: any[];
}

/**
 * Wraps an A2UI envelope in a DataPart
 */
export function wrapEnvelope(envelope: Record<string, any>): DataPart {
  return {
    data: envelope,
    metadata: {
      mimeType: A2UI_MIME_TYPE,
    },
  };
}

/**
 * Unwraps an A2UI envelope from a DataPart
 */
export function unwrapEnvelope(
  part: DataPart
): { ok: true; data: Record<string, any> } | { ok: false; error: string } {
  if (!part.data) {
    return { ok: false, error: "Missing data in DataPart" };
  }

  // Check MIME type if present (be lenient if not)
  if (part.metadata?.mimeType && part.metadata.mimeType !== A2UI_MIME_TYPE) {
    return { ok: false, error: `Invalid mimeType: ${part.metadata.mimeType}` };
  }

  return { ok: true, data: part.data };
}

/**
 * Checks if a part is an A2UI DataPart based on mimeType
 */
export function isA2UIDataPart(part: DataPart | TextPart): part is DataPart {
  return (
    "data" in part &&
    (!("metadata" in part) ||
      !part.metadata?.mimeType ||
      part.metadata.mimeType === A2UI_MIME_TYPE)
  );
}

/**
 * Checks if a part is a text part
 */
export function isTextPart(part: DataPart | TextPart): part is TextPart {
  return "text" in part;
}

/**
 * Builds an A2A message for server→client transmission
 */
export function buildServerMessage(envelope: Record<string, any>): A2ATaskMessage {
  return {
    message: {
      role: AGENT_ROLE,
      parts: [wrapEnvelope(envelope)],
    },
  };
}

/**
 * Extracts A2UI envelopes from an A2A message
 */
export function extractEnvelopes(message: A2ATaskMessage): Record<string, any>[] {
  const parts = message.message?.parts || [];
  const envelopes: Record<string, any>[] = [];

  for (const part of parts) {
    if (isA2UIDataPart(part)) {
      const result = unwrapEnvelope(part);
      if (result.ok) {
        envelopes.push(result.data);
      }
    }
  }

  return envelopes;
}

/**
 * Extracts text content from an A2A message
 */
export function extractTextContent(message: A2ATaskMessage): string | null {
  const parts = message.message?.parts || [];

  for (const part of parts) {
    if (isTextPart(part)) {
      return part.text;
    }
  }

  return null;
}

/**
 * Extracts client capabilities from A2A message metadata
 */
export function extractClientCapabilities(
  message: A2ATaskMessage
): ClientCapabilities | null {
  return message.message?.metadata?.[CLIENT_CAPABILITIES_KEY] || null;
}

/**
 * Extracts userAction from A2A message parts
 */
export function extractUserAction(
  message: A2ATaskMessage
): Record<string, any> | null {
  const envelopes = extractEnvelopes(message);

  for (const envelope of envelopes) {
    if (envelope.userAction) {
      return envelope.userAction;
    }
    if (envelope.action) {
      return envelope.action;
    }
  }

  return null;
}

/**
 * Checks if X-A2A-Extensions header indicates A2UI support
 */
export function supportsA2UI(extensionsHeader: string | undefined): boolean {
  if (!extensionsHeader) return false;
  return extensionsHeader.includes(A2UI_EXTENSION_URI);
}

/**
 * Validates an incoming A2A task message
 */
export function validateTaskMessage(
  body: any
): { ok: true; message: A2ATaskMessage } | { ok: false; error: string } {
  if (!body || typeof body !== "object") {
    return { ok: false, error: "Body must be an object" };
  }

  if (!body.message || typeof body.message !== "object") {
    return { ok: false, error: "Missing message field" };
  }

  if (!body.message.role) {
    return { ok: false, error: "Missing message.role" };
  }

  if (!Array.isArray(body.message.parts)) {
    return { ok: false, error: "message.parts must be an array" };
  }

  return { ok: true, message: body as A2ATaskMessage };
}
