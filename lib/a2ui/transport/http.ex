defmodule A2UI.Transport.HTTP do
  @moduledoc """
  HTTP+SSE transport for A2UI.

  This transport enables remote agents to stream UI updates over Server-Sent Events (SSE)
  and receive client events via HTTP POST.

  ## Architecture

  ```
  Client (Phoenix LiveView)                    Server (Agent)
  ┌─────────────────────────┐                 ┌─────────────────────────┐
  │ A2UI.Phoenix.Live       │                 │ Agent Process           │
  │   ↓                     │                 │   ↓                     │
  │ SSEClient (UIStream)    │◄──── SSE ──────│ SSEServer (Plug)        │
  │   ↓                     │                 │   ↑                     │
  │ HTTPEvents (Events)     │──── POST ──────►│ Registry + PubSub       │
  └─────────────────────────┘                 └─────────────────────────┘
  ```

  ## Modules

  - `A2UI.Transport.HTTP.SSEClient` - UIStream implementation using Req
  - `A2UI.Transport.HTTP.HTTPEvents` - Events implementation using HTTP POST
  - `A2UI.Transport.HTTP.SSEServer` - Server-side SSE producer Plug
  - `A2UI.Transport.HTTP.Registry` - Session management and PubSub broadcast
  - `A2UI.Transport.HTTP.Plug` - Combined HTTP router for all endpoints

  ## Optional Dependency

  This transport requires the `req` library. Add to your `mix.exs`:

      {:req, "~> 0.5"}

  ## Usage

  ### Server-side (Agent)

  Mount the HTTP transport plug in your router:

      forward "/a2ui", A2UI.Transport.HTTP.Plug,
        pubsub: MyApp.PubSub,
        registry: A2UI.Transport.HTTP.Registry

  Add the registry to your supervision tree:

      children = [
        {Phoenix.PubSub, name: MyApp.PubSub},
        {A2UI.Transport.HTTP.Registry, pubsub: MyApp.PubSub}
      ]

  ### Client-side (Renderer)

      {:ok, stream} = A2UI.Transport.HTTP.SSEClient.start_link(
        base_url: "http://localhost:4000/a2ui",
        session_id: "abc123"
      )

      {:ok, events} = A2UI.Transport.HTTP.HTTPEvents.start_link(
        base_url: "http://localhost:4000/a2ui",
        session_id: "abc123"
      )
  """

  @doc """
  Checks if the HTTP transport is available (Req is installed).

  Returns `true` if Req is available, `false` otherwise.

  ## Example

      iex> A2UI.Transport.HTTP.available?()
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
