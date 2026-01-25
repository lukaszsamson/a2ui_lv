/**
 * A2UI Claude Bridge - A2A Transport
 *
 * Express server that implements A2A protocol endpoints for A2UI.
 *
 * Uses Claude Code's existing authentication (run `claude` first to login).
 *
 * Endpoints:
 * - GET  /.well-known/agent.json  → Agent card with A2UI extension
 * - POST /a2a/tasks               → Create task (A2A message format)
 * - GET  /a2a/tasks/:taskId       → SSE stream (A2A message wrapper)
 * - POST /a2a/tasks/:taskId       → Send action (A2A message format)
 */

import express, { Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

import {
  A2UI_EXTENSION_URI,
  buildServerMessage,
  extractTextContent,
  extractUserAction,
  extractClientCapabilities,
  validateTaskMessage,
  supportsA2UI,
} from "./a2a.js";

import { generateA2UI, buildActionPrompt, getA2uiVersion } from "./agent.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const PORT = parseInt(process.env.PORT || "3002", 10);
const HOST = process.env.HOST || "0.0.0.0";

// Load agent card
const agentCardPath = join(process.cwd(), "agent.json");
let agentCard: any;
try {
  agentCard = JSON.parse(readFileSync(agentCardPath, "utf-8"));
  // Update URL based on runtime config
  agentCard.url = `http://${HOST === "0.0.0.0" ? "localhost" : HOST}:${PORT}`;
} catch (e) {
  console.error("Failed to load agent.json:", e);
  process.exit(1);
}

// Event entry for replay support
interface EventEntry {
  id: number;
  data: string;  // The wrapped A2A message JSON
}

// Task storage
interface Task {
  id: string;
  prompt: string;
  surfaceId: string;
  status: "pending" | "generating" | "done" | "error";
  messages: string[];
  eventHistory: EventEntry[];  // For SSE replay support
  eventCounter: number;        // Counter for event IDs
  error?: string;
  // For handling actions
  originalPrompt?: string;
  dataModel?: Record<string, any>;
  // SSE response to write to
  sseResponse?: Response;
}

const tasks = new Map<string, Task>();

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
 * GET /.well-known/agent.json - Agent card
 */
app.get("/.well-known/agent.json", (req: Request, res: Response) => {
  res.json(agentCard);
});

/**
 * POST /a2a/tasks - Create a new task
 *
 * Request body (A2A message format):
 * {
 *   "message": {
 *     "role": "user",
 *     "metadata": {
 *       "a2uiClientCapabilities": { "supportedCatalogIds": [...] }
 *     },
 *     "parts": [
 *       { "text": "Show me a hello world button" }
 *     ]
 *   }
 * }
 *
 * Response:
 * { "taskId": "abc-123" }
 */
app.post("/a2a/tasks", async (req: Request, res: Response) => {
  // Check X-A2A-Extensions header
  const extensionsHeader = req.headers["x-a2a-extensions"] as string | undefined;
  if (!supportsA2UI(extensionsHeader)) {
    console.log("[A2A] Warning: Request missing A2UI extension in X-A2A-Extensions header");
    // Continue anyway for testing
  }

  // Validate A2A message
  const validation = validateTaskMessage(req.body);
  if (!validation.ok) {
    return res.status(400).json({ error: validation.error });
  }

  const message = validation.message;

  // Extract text content (the prompt)
  const prompt = extractTextContent(message);
  if (!prompt) {
    return res.status(400).json({ error: "Missing text content in message parts" });
  }

  // Extract client capabilities
  const capabilities = extractClientCapabilities(message);
  console.log(`[A2A] Client capabilities:`, capabilities);

  // Default surface ID
  const surfaceId = "llm-surface";

  const taskId = uuidv4();
  const task: Task = {
    id: taskId,
    prompt,
    surfaceId,
    status: "pending",
    messages: [],
    eventHistory: [],
    eventCounter: 0,
    originalPrompt: prompt,
  };

  tasks.set(taskId, task);

  console.log(`[A2A] Created task ${taskId} for prompt: "${prompt.substring(0, 80)}..."`);

  // Start generation asynchronously
  generateForTask(task).catch((err) => {
    console.error(`[A2A] Generation error for ${taskId}:`, err);
    task.status = "error";
    task.error = err.message;
  });

  res.status(201).json({ taskId });
});

/**
 * GET /a2a/tasks/:taskId - SSE stream of A2A messages
 *
 * Streams A2A messages wrapping A2UI envelopes:
 * data: {"message":{"role":"agent","parts":[{"data":{"surfaceUpdate":{...}},"metadata":{"mimeType":"application/json+a2ui"}}]}}
 */
app.get("/a2a/tasks/:taskId", async (req: Request, res: Response) => {
  const taskId = req.params.taskId as string;
  const task = tasks.get(taskId);

  if (!task) {
    return res.status(404).json({ error: "Task not found" });
  }

  // Check for Last-Event-ID header for replay support
  const lastEventIdHeader = req.headers["last-event-id"];
  const lastEventId = lastEventIdHeader ? parseInt(lastEventIdHeader as string, 10) : 0;

  // Set SSE headers
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");
  res.flushHeaders();

  // Send retry hint for reconnection
  res.write(`retry: 3000\n\n`);

  // Store SSE response for async writing
  task.sseResponse = res;

  // Replay events since Last-Event-ID (or send all events if no header)
  const eventsToReplay = task.eventHistory.filter(e => e.id > lastEventId);
  // Sort by ID ascending for chronological order
  eventsToReplay.sort((a, b) => a.id - b.id);

  if (eventsToReplay.length > 0) {
    console.log(`[A2A] Replaying ${eventsToReplay.length} events for task ${taskId} (after event ${lastEventId})`);
    for (const event of eventsToReplay) {
      res.write(`id: ${event.id}\ndata: ${event.data}\n\n`);
    }
  }

  // If already done or error, close immediately
  if (task.status === "done" || task.status === "error") {
    res.write(`: stream-${task.status}\n\n`);
    res.end();
    return;
  }

  // Handle client disconnect
  req.on("close", () => {
    console.log(`[A2A] SSE client disconnected from task ${taskId}`);
    task.sseResponse = undefined;
  });
});

/**
 * POST /a2a/tasks/:taskId - Send action to task
 *
 * Request body (A2A message format):
 * {
 *   "message": {
 *     "role": "user",
 *     "metadata": { "a2uiClientCapabilities": {...} },
 *     "parts": [
 *       { "data": { "userAction": {...} }, "metadata": { "mimeType": "application/json+a2ui" } }
 *     ]
 *   }
 * }
 */
app.post("/a2a/tasks/:taskId", async (req: Request, res: Response) => {
  const taskId = req.params.taskId as string;
  const task = tasks.get(taskId);

  if (!task) {
    return res.status(404).json({ error: "Task not found" });
  }

  // Validate A2A message
  const validation = validateTaskMessage(req.body);
  if (!validation.ok) {
    return res.status(400).json({ error: validation.error });
  }

  const message = validation.message;

  // Extract userAction from message parts
  const userAction = extractUserAction(message);
  if (!userAction) {
    return res.status(400).json({ error: "No userAction found in message parts" });
  }

  console.log(`[A2A] Received action for task ${taskId}:`, JSON.stringify(userAction).substring(0, 200));

  // Create a new task for the action response
  const newTaskId = uuidv4();
  const actionName = userAction.name || "unknown";
  const actionContext = userAction.context || {};

  // Build action prompt
  const actionPrompt = buildActionPrompt(
    task.originalPrompt || task.prompt,
    actionName,
    actionContext,
    task.dataModel || {}
  );

  const newTask: Task = {
    id: newTaskId,
    prompt: actionPrompt,
    surfaceId: task.surfaceId,
    status: "pending",
    messages: [],
    eventHistory: [],
    eventCounter: 0,
    originalPrompt: task.originalPrompt || task.prompt,
    dataModel: task.dataModel,
  };

  tasks.set(newTaskId, newTask);

  console.log(`[A2A] Created action task ${newTaskId} for action: ${actionName}`);

  // Start generation asynchronously
  generateForTask(newTask).catch((err) => {
    console.error(`[A2A] Action generation error for ${newTaskId}:`, err);
    newTask.status = "error";
    newTask.error = err.message;
  });

  // Return the new task ID for the client to connect to
  res.json({ ok: true, taskId: newTaskId });
});

/**
 * GET /health - Health check
 */
app.get("/health", (req: Request, res: Response) => {
  res.json({ status: "ok", tasks: tasks.size, protocol: "A2A" });
});

// ============================================
// Generation Logic
// ============================================

/**
 * Generate A2UI response for a task
 */
async function generateForTask(task: Task): Promise<void> {
  task.status = "generating";
  const { prompt, surfaceId } = task;

  console.log(`[Claude] Generating A2UI for task ${task.id}: "${prompt.substring(0, 100)}..."`);

  const result = await generateA2UI(prompt, {
    surfaceId,
    onMessage: (msg) => {
      // Increment event counter
      task.eventCounter++;
      const eventId = task.eventCounter;

      // Store message
      task.messages.push(msg);

      // Wrap in A2A format and store in history
      const a2aMsg = wrapA2UIMessage(msg);
      const a2aMsgJson = JSON.stringify(a2aMsg);
      task.eventHistory.push({ id: eventId, data: a2aMsgJson });

      // Keep only last 100 events in history
      if (task.eventHistory.length > 100) {
        task.eventHistory.shift();
      }

      // Send to SSE if connected (with event ID)
      if (task.sseResponse) {
        task.sseResponse.write(`id: ${eventId}\ndata: ${a2aMsgJson}\n\n`);
      }

      console.log(`[A2A] Sent message (id=${eventId}): ${msg.substring(0, 100)}...`);
    },
  });

  if (result.error) {
    task.status = "error";
    task.error = result.error;

    if (task.sseResponse) {
      task.sseResponse.write(`: stream-error: ${result.error}\n\n`);
      task.sseResponse.end();
      task.sseResponse = undefined;
    }
    return;
  }

  // Store data model for future actions
  if (result.dataModel) {
    task.dataModel = result.dataModel;
  }

  task.status = "done";

  // End SSE stream
  if (task.sseResponse) {
    task.sseResponse.write(`: stream-done\n\n`);
    task.sseResponse.end();
    task.sseResponse = undefined;
  }

  console.log(`[A2A] Completed task ${task.id}`);
}

/**
 * Wrap an A2UI JSON message in A2A message format
 */
function wrapA2UIMessage(jsonMsg: string): object {
  try {
    const envelope = JSON.parse(jsonMsg);
    return buildServerMessage(envelope);
  } catch (e) {
    // If not valid JSON, return as-is wrapped in text
    return {
      message: {
        role: "agent",
        parts: [{ text: jsonMsg }],
      },
    };
  }
}

// ============================================
// Server Start
// ============================================

app.listen(PORT, HOST, () => {
  const version = getA2uiVersion();
  console.log(`[A2A] A2UI Claude Bridge (A2A) listening on http://${HOST}:${PORT}`);
  console.log(`[A2A] Protocol version: ${version}`);
  console.log("[A2A] Endpoints:");
  console.log("  GET  /.well-known/agent.json  → Agent card");
  console.log("  POST /a2a/tasks               → Create task");
  console.log("  GET  /a2a/tasks/:taskId       → SSE stream");
  console.log("  POST /a2a/tasks/:taskId       → Send action");
  console.log("  GET  /health                  → Health check");
  console.log("[A2A] Using Claude Code authentication (run 'claude' first to login)");
});
