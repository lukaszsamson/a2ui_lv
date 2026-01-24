/**
 * A2UI Claude Bridge - HTTP+SSE Transport
 *
 * Express server that receives prompts via HTTP POST and streams
 * A2UI messages back via Server-Sent Events (SSE).
 *
 * Uses Claude Code's existing authentication (run `claude` first to login).
 *
 * Endpoints:
 * - POST /sessions - Create session, receive sessionId
 * - GET /stream/:sessionId - SSE stream of A2UI messages
 * - POST /events - Receive client actions
 */

import express, { Request, Response } from "express";
import { query } from "@anthropic-ai/claude-agent-sdk";
import { randomUUID } from "crypto";

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

const PORT = parseInt(process.env.PORT || "3001", 10);
const HOST = process.env.HOST || "0.0.0.0";

function getA2uiVersion(): "v0.8" | "v0.9" {
  return process.env.A2UI_VERSION === "v0.9" ? "v0.9" : "v0.8";
}

// Session storage
interface Session {
  id: string;
  prompt: string;
  surfaceId: string;
  status: "pending" | "generating" | "done" | "error";
  messages: string[];
  error?: string;
  // For handling actions
  originalPrompt?: string;
  dataModel?: Record<string, any>;
  // SSE response to write to
  sseResponse?: Response;
}

const sessions = new Map<string, Session>();

// Create Express app
const app = express();
app.use(express.json());

// CORS headers for cross-origin requests
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.header("Access-Control-Allow-Headers", "Content-Type, X-A2A-Extensions");
  if (req.method === "OPTIONS") {
    return res.sendStatus(200);
  }
  next();
});

/**
 * POST /sessions - Create a new session and start generation
 *
 * Request body:
 * {
 *   "prompt": "show a hello world button",
 *   "surfaceId": "llm-surface"  // optional, default: "llm-surface"
 * }
 *
 * Response:
 * { "sessionId": "abc-123" }
 */
app.post("/sessions", async (req: Request, res: Response) => {
  const { prompt, surfaceId = "llm-surface" } = req.body;

  if (!prompt || typeof prompt !== "string") {
    return res.status(400).json({ error: "Missing or invalid prompt" });
  }

  const sessionId = randomUUID();
  const session: Session = {
    id: sessionId,
    prompt,
    surfaceId,
    status: "pending",
    messages: [],
  };

  sessions.set(sessionId, session);

  console.log(`[HTTP] Created session ${sessionId} for prompt: "${prompt.substring(0, 80)}..."`);

  // Start generation asynchronously
  generateForSession(session).catch((err) => {
    console.error(`[HTTP] Generation error for ${sessionId}:`, err);
    session.status = "error";
    session.error = err.message;
  });

  res.status(201).json({ sessionId });
});

/**
 * GET /stream/:sessionId - SSE stream of A2UI messages
 *
 * Streams A2UI messages as SSE events:
 * data: {"surfaceUpdate":{...}}
 *
 * data: {"dataModelUpdate":{...}}
 *
 * data: {"beginRendering":{...}}
 */
app.get("/stream/:sessionId", async (req: Request, res: Response) => {
  const { sessionId } = req.params;
  const session = sessions.get(sessionId);

  if (!session) {
    return res.status(404).json({ error: "Session not found" });
  }

  // Set SSE headers
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");
  res.flushHeaders();

  // Store SSE response for async writing
  session.sseResponse = res;

  // Send any already-generated messages
  for (const msg of session.messages) {
    res.write(`data: ${msg}\n\n`);
  }

  // If already done or error, close immediately
  // Per A2UI spec: SSE data: must contain ONLY valid A2UI envelopes.
  // Signal completion/error by closing the connection, NOT by sending JSON.
  if (session.status === "done" || session.status === "error") {
    // Optionally send SSE comment (ignored by A2UI parser) for debugging
    res.write(`: stream-${session.status}\n\n`);
    res.end();
    return;
  }

  // Handle client disconnect
  req.on("close", () => {
    console.log(`[HTTP] SSE client disconnected from session ${sessionId}`);
    session.sseResponse = undefined;
  });

  // Keep connection alive until generation completes
  // The generateForSession function will write to res and end it
});

/**
 * POST /events - Receive client events (actions)
 *
 * Request body:
 * {
 *   "sessionId": "abc-123",
 *   "event": { "userAction": { "name": "submit", ... } }
 * }
 *
 * For action handling, this creates a new session that generates
 * an updated UI based on the action.
 */
app.post("/events", async (req: Request, res: Response) => {
  const { sessionId, event } = req.body;

  if (!sessionId || !event) {
    return res.status(400).json({ error: "Missing sessionId or event" });
  }

  const session = sessions.get(sessionId);
  if (!session) {
    return res.status(404).json({ error: "Session not found" });
  }

  console.log(`[HTTP] Received event for session ${sessionId}:`, JSON.stringify(event).substring(0, 200));

  // Extract action from event (may be wrapped in A2A message format)
  const userAction = extractUserAction(event);
  if (!userAction) {
    return res.status(400).json({ error: "Invalid event format" });
  }

  // Create a new session for the action response
  const newSessionId = randomUUID();
  const actionName = userAction.name || "unknown";
  const actionContext = userAction.context || {};

  // Build action prompt
  const actionPrompt =
    "__ACTION__\n" +
    `OriginalJSON: ${JSON.stringify(session.originalPrompt || session.prompt)}\n` +
    `Action: ${actionName}\n` +
    `Context: ${JSON.stringify(actionContext)}\n` +
    `DataModel: ${JSON.stringify(session.dataModel || {})}`;

  const newSession: Session = {
    id: newSessionId,
    prompt: actionPrompt,
    surfaceId: session.surfaceId,
    status: "pending",
    messages: [],
    originalPrompt: session.originalPrompt || session.prompt,
    dataModel: session.dataModel,
  };

  sessions.set(newSessionId, newSession);

  console.log(`[HTTP] Created action session ${newSessionId} for action: ${actionName}`);

  // Start generation asynchronously
  generateForSession(newSession).catch((err) => {
    console.error(`[HTTP] Action generation error for ${newSessionId}:`, err);
    newSession.status = "error";
    newSession.error = err.message;
  });

  // Return the new session ID for the client to connect to
  res.json({ ok: true, sessionId: newSessionId });
});

/**
 * POST /message - Push a message to a session (for testing)
 */
app.post("/message", async (req: Request, res: Response) => {
  const { sessionId, message } = req.body;

  if (!sessionId || !message) {
    return res.status(400).json({ error: "Missing sessionId or message" });
  }

  const session = sessions.get(sessionId);
  if (!session) {
    return res.status(404).json({ error: "Session not found" });
  }

  const msgStr = typeof message === "string" ? message : JSON.stringify(message);
  session.messages.push(msgStr);

  if (session.sseResponse) {
    session.sseResponse.write(`data: ${msgStr}\n\n`);
  }

  res.json({ ok: true });
});

/**
 * POST /done - Signal session completion
 */
app.post("/done", async (req: Request, res: Response) => {
  const { sessionId, meta = {} } = req.body;

  if (!sessionId) {
    return res.status(400).json({ error: "Missing sessionId" });
  }

  const session = sessions.get(sessionId);
  if (!session) {
    return res.status(404).json({ error: "Session not found" });
  }

  session.status = "done";

  if (session.sseResponse) {
    // Per A2UI spec: SSE data: must contain ONLY valid A2UI envelopes.
    // Signal completion by closing the connection, NOT by sending JSON.
    session.sseResponse.write(`: stream-done\n\n`);
    session.sseResponse.end();
    session.sseResponse = undefined;
  }

  res.json({ ok: true });
});

/**
 * GET /health - Health check
 */
app.get("/health", (req: Request, res: Response) => {
  res.json({ status: "ok", sessions: sessions.size });
});

// ============================================
// Generation Logic
// ============================================

/**
 * Generate A2UI response using Claude Agent SDK.
 */
async function generateForSession(session: Session): Promise<void> {
  session.status = "generating";
  const { prompt, surfaceId } = session;
  const version = getA2uiVersion();

  console.log(
    `[Claude] Generating A2UI (${version}) for session ${session.id}: "${prompt.substring(0, 100)}..."`
  );

  let fullPrompt: string;
  const systemPrompt = version === "v0.9" ? A2UI_SYSTEM_PROMPT_V09 : A2UI_SYSTEM_PROMPT;
  const actionPrompt = version === "v0.9" ? A2UI_ACTION_PROMPT_V09 : A2UI_ACTION_PROMPT;

  if (isActionRequest(prompt)) {
    // This is a follow-up action request
    const { originalPrompt, actionName, actionContext, dataModel } =
      parseActionRequest(prompt);

    console.log(`[Claude] Action request - action: ${actionName}`);

    fullPrompt = `${actionPrompt}

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
    fullPrompt = `${systemPrompt}\n\nUser request: ${prompt}`;

    // Store original prompt for future actions
    session.originalPrompt = prompt;
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
      throw e;
    }

    // Store data model for future actions
    if (parsed.dataModel) {
      session.dataModel = parsed.dataModel;
    }

    const messages =
      version === "v0.9"
        ? buildA2uiMessagesV09(parsed, surfaceId)
        : buildA2uiMessages(parsed, surfaceId);

    // Send messages
    for (const msg of messages) {
      session.messages.push(msg);
      if (session.sseResponse) {
        session.sseResponse.write(`data: ${msg}\n\n`);
      }
      console.log(`[HTTP] Sent message: ${msg.substring(0, 100)}...`);
    }

    session.status = "done";

    // End SSE stream
    // Per A2UI spec: SSE data: must contain ONLY valid A2UI envelopes.
    // Signal completion by closing the connection, NOT by sending JSON.
    if (session.sseResponse) {
      session.sseResponse.write(`: stream-done\n\n`);
      session.sseResponse.end();
      session.sseResponse = undefined;
    }

    console.log(`[HTTP] Completed session ${session.id}`);
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.error(`[HTTP] Error for session ${session.id}: ${errorMsg}`);

    session.status = "error";
    session.error = errorMsg;

    // Per A2UI spec: SSE data: must contain ONLY valid A2UI envelopes.
    // Signal errors by closing the connection, NOT by sending JSON.
    if (session.sseResponse) {
      session.sseResponse.write(`: stream-error: ${errorMsg}\n\n`);
      session.sseResponse.end();
      session.sseResponse = undefined;
    }
  }
}

/**
 * Extract userAction from event (handles A2A wrapping).
 */
function extractUserAction(event: any): any {
  // Direct userAction
  if (event.userAction) {
    return event.userAction;
  }

  // v0.9 action key
  if (event.action) {
    return event.action;
  }

  // A2A message wrapper
  if (event.message?.parts) {
    for (const part of event.message.parts) {
      if (part.data?.userAction) {
        return part.data.userAction;
      }
      if (part.data?.action) {
        return part.data.action;
      }
    }
  }

  return null;
}

// ============================================
// Server Start
// ============================================

app.listen(PORT, HOST, () => {
  const version = getA2uiVersion();
  console.log(`[HTTP] A2UI Claude Bridge (HTTP+SSE) listening on http://${HOST}:${PORT}`);
  console.log(`[HTTP] Protocol version: ${version}`);
  console.log("[HTTP] Endpoints:");
  console.log("  POST /sessions - Create session, receive sessionId");
  console.log("  GET /stream/:sessionId - SSE stream of A2UI messages");
  console.log("  POST /events - Receive client actions");
  console.log("  POST /message - Push message to session (testing)");
  console.log("  POST /done - Signal session completion");
  console.log("  GET /health - Health check");
  console.log("[HTTP] Using Claude Code authentication (run 'claude' first to login)");
});
