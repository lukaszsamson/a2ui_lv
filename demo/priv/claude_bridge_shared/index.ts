/**
 * A2UI Claude Bridge Shared Module
 *
 * Common utilities shared between ZMQ and HTTP+SSE bridge implementations.
 */

export { A2UI_SYSTEM_PROMPT, A2UI_ACTION_PROMPT } from "./prompts";
export { extractJson, extractJsonObject } from "./json-extract";
export {
  buildA2uiMessages,
  buildDataModelUpdateMessages,
  isActionRequest,
  parseActionRequest,
} from "./a2ui-builder";
