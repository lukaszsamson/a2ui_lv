/**
 * Claude Agent wrapper for A2UI generation
 *
 * Uses Claude Agent SDK to generate A2UI JSON from prompts.
 */

import { query } from "@anthropic-ai/claude-agent-sdk";

// Import shared utilities
import {
  A2UI_SYSTEM_PROMPT,
  A2UI_ACTION_PROMPT,
  A2UI_SYSTEM_PROMPT_V09,
  A2UI_ACTION_PROMPT_V09,
  extractJson,
  buildA2uiMessages,
  buildA2uiMessagesV09,
  isActionRequest,
  parseActionRequest,
} from "../../claude_bridge_shared/index.js";

// Get A2UI version from environment
export function getA2uiVersion(): "v0.8" | "v0.9" {
  return process.env.A2UI_VERSION === "v0.9" ? "v0.9" : "v0.8";
}

export interface GenerationResult {
  messages: string[];
  dataModel?: Record<string, any>;
  error?: string;
}

export interface GenerationOptions {
  surfaceId: string;
  onMessage?: (msg: string) => void;
}

/**
 * Generate A2UI messages from a prompt
 */
export async function generateA2UI(
  prompt: string,
  options: GenerationOptions
): Promise<GenerationResult> {
  const { surfaceId, onMessage } = options;
  const version = getA2uiVersion();

  console.log(`[Claude] Generating A2UI (${version}) for: "${prompt.substring(0, 100)}..."`);

  // Select prompts based on version
  const systemPrompt = version === "v0.9" ? A2UI_SYSTEM_PROMPT_V09 : A2UI_SYSTEM_PROMPT;
  const actionPrompt = version === "v0.9" ? A2UI_ACTION_PROMPT_V09 : A2UI_ACTION_PROMPT;

  let fullPrompt: string;
  let dataModel: Record<string, any> | undefined;

  if (isActionRequest(prompt)) {
    // This is a follow-up action request
    const parsed = parseActionRequest(prompt);
    console.log(`[Claude] Action request - action: ${parsed.actionName}`);

    fullPrompt = `${actionPrompt}

# CURRENT SITUATION

Original user request: "${parsed.originalPrompt}"

User clicked button with action: "${parsed.actionName}"

Action context (data sent with the button click):
${JSON.stringify(parsed.actionContext, null, 2)}

Current data model (form values, user inputs):
${JSON.stringify(parsed.dataModel, null, 2)}

# YOUR TASK

Process this action and generate an updated UI showing the results. For example:
- If this is a form submission, process the data and show results
- If this is an analysis request, perform the analysis and display findings
- Show appropriate success/error states

Generate the A2UI ${version} JSON response now. Output ONLY valid JSON.`;

    dataModel = parsed.dataModel;
  } else {
    // Regular initial request
    fullPrompt = `${systemPrompt}\n\nUser request: ${prompt}`;
  }

  let resultText = "";

  try {
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

    const jsonStr = extractJson(resultText);
    console.log(`[Claude] Extracted JSON length: ${jsonStr.length}`);

    let parsed: any;
    try {
      parsed = JSON.parse(jsonStr);
    } catch (e) {
      console.error(`[Claude] JSON parse error: ${e}`);
      console.error(`[Claude] Failed JSON (first 1000): ${jsonStr.substring(0, 1000)}`);
      return { messages: [], error: `JSON parse error: ${e}` };
    }

    // Store data model for future actions
    if (parsed.dataModel) {
      dataModel = parsed.dataModel;
    }

    // Use version-appropriate message builder
    const messages = version === "v0.9"
      ? buildA2uiMessagesV09(parsed, surfaceId)
      : buildA2uiMessages(parsed, surfaceId);

    // Call onMessage for each message if provided
    if (onMessage) {
      for (const msg of messages) {
        onMessage(msg);
      }
    }

    return { messages, dataModel };
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.error(`[Claude] Generation error: ${errorMsg}`);
    return { messages: [], error: errorMsg };
  }
}

/**
 * Build an action prompt from user action data
 */
export function buildActionPrompt(
  originalPrompt: string,
  actionName: string,
  actionContext: Record<string, any>,
  dataModel: Record<string, any>
): string {
  return (
    "__ACTION__\n" +
    `OriginalJSON: ${JSON.stringify(originalPrompt)}\n` +
    `Action: ${actionName}\n` +
    `Context: ${JSON.stringify(actionContext)}\n` +
    `DataModel: ${JSON.stringify(dataModel)}`
  );
}
