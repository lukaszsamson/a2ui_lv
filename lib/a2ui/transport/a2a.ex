defmodule A2UI.Transport.A2A do
  @moduledoc """
  A2A (Agent-to-Agent) transport for A2UI.

  This transport enables communication with any A2A-compliant agent that supports
  the A2UI extension. It uses the full A2A protocol format for all messages.

  ## Architecture

  ```
  Client (Phoenix LiveView)                    A2A Agent
  ┌─────────────────────────────┐             ┌─────────────────────────────┐
  │ A2UI.Phoenix.Live           │             │ A2A-compliant Agent         │
  │   ↓                         │             │   ↓                         │
  │ A2A.Client (UIStream+Events)│◄─── A2A ───│ /.well-known/agent.json     │
  │   │                         │             │   ↓                         │
  │   ├── X-A2A-Extensions hdr  │             │ POST /a2a/tasks             │
  │   ├── a2uiClientCapabilities│             │ GET  /a2a/tasks/:id (SSE)   │
  │   └── All msgs as DataParts │             │ POST /a2a/tasks/:id         │
  └─────────────────────────────┘             └─────────────────────────────┘
  ```

  ## Key Differences from HTTP+SSE Transport

  | Aspect | HTTP+SSE | A2A |
  |--------|----------|-----|
  | Session creation | `POST /sessions {prompt}` | `POST /a2a/tasks {A2A message}` |
  | Stream format | Raw JSON envelopes | A2A messages with DataParts |
  | Events | Wrapped only at send time | Full A2A message format |
  | Headers | None special | `X-A2A-Extensions` on all requests |
  | Capabilities | Session-local | Every message metadata |
  | Agent discovery | N/A | `/.well-known/agent.json` |

  ## Modules

  - `A2UI.Transport.A2A.Client` - Combined UIStream + Events implementation
  - `A2UI.Transport.A2A.AgentCard` - Agent card parsing and validation

  ## Optional Dependency

  This transport requires the `req` library. Add to your `mix.exs`:

      {:req, "~> 0.5"}

  ## Usage

  ### Connecting to an A2A Agent

      # Start the A2A client
      {:ok, client} = A2UI.Transport.A2A.Client.start_link(
        base_url: "http://localhost:3002",
        capabilities: A2UI.ClientCapabilities.default()
      )

      # Check if the agent supports A2UI
      {:ok, card} = A2UI.Transport.A2A.Client.fetch_agent_card(client)
      if A2UI.Transport.A2A.AgentCard.supports_a2ui?(card) do
        # Create a task with initial message
        {:ok, task_id} = A2UI.Transport.A2A.Client.create_task(client, initial_message, [])

        # Open stream to receive responses
        :ok = A2UI.Transport.A2A.Client.open(client, "main", self(), task_id: task_id)
      end

      # Send events using A2A format
      event = %{"userAction" => %{"name" => "submit", ...}}
      :ok = A2UI.Transport.A2A.Client.send_event(client, event, task_id: task_id)
  """

  @doc """
  Checks if the A2A transport is available (Req is installed).

  Returns `true` if Req is available, `false` otherwise.

  ## Example

      iex> A2UI.Transport.A2A.available?()
      true
  """
  @spec available?() :: boolean()
  def available? do
    Code.ensure_loaded?(Req)
  end

  @doc """
  Returns an error tuple with instructions for installing Req.

  This is used by client modules when Req is not available.
  """
  @spec missing_dependency_error() :: {:error, {:missing_dependency, :req, String.t()}}
  def missing_dependency_error do
    {:error, {:missing_dependency, :req, "Add {:req, \"~> 0.5\"} to your mix.exs dependencies"}}
  end
end
