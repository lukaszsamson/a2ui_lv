defmodule A2UIDemo.Demo.ClaudeHTTPClient do
  @moduledoc """
  HTTP+SSE client for communicating with the Claude A2UI HTTP bridge.

  Connects to an Express server that handles Claude API calls
  and streams back A2UI messages via SSE.

  ## Usage

      # Start the client (usually done by supervisor)
      {:ok, pid} = A2UIDemo.Demo.ClaudeHTTPClient.start_link()

      # Generate A2UI from a prompt
      {:ok, messages} = A2UIDemo.Demo.ClaudeHTTPClient.generate("show a todo list")

      # With callback for streaming
      A2UIDemo.Demo.ClaudeHTTPClient.generate("show weather",
        on_message: fn msg -> send(self(), {:a2ui_msg, msg}) end
      )
  """

  use GenServer
  require Logger

  @default_endpoint "http://127.0.0.1:3001"
  # 5 minutes - Claude can take a while
  @recv_timeout 300_000

  # Client API

  @doc """
  Start the Claude HTTP client GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate A2UI messages from a user prompt.

  ## Options

  - `:endpoint` - HTTP endpoint (default: #{@default_endpoint})
  - `:surface_id` - Surface ID for generated UI (default: "llm-surface")
  - `:on_message` - Callback function called for each A2UI message
  - `:timeout` - Request timeout in ms (default: #{@recv_timeout})
  """
  @spec generate(String.t(), keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def generate(prompt, opts \\ []) do
    timeout = opts[:timeout] || @recv_timeout
    GenServer.call(__MODULE__, {:generate, prompt, opts}, timeout + 5_000)
  end

  @doc """
  Generate A2UI response for a user action (follow-up request).

  This sends the action context along with the current data model back to Claude
  so it can generate an updated UI based on user interactions.

  ## Parameters

  - `original_prompt` - The original prompt that created the UI
  - `user_action` - The userAction map from the A2UI event
  - `data_model` - Current data model state
  - `opts` - Options (same as generate/2)
  """
  @spec generate_with_action(String.t(), map(), map(), keyword()) ::
          {:ok, [String.t()]} | {:error, term()}
  def generate_with_action(original_prompt, user_action, data_model, opts \\ []) do
    action = user_action["userAction"] || user_action
    action_name = action["name"] || "unknown"
    action_context = action["context"] || %{}

    # Format as action request (special format the bridge understands)
    prompt =
      "__ACTION__\n" <>
        "OriginalJSON: #{Jason.encode!(original_prompt)}\n" <>
        "Action: #{action_name}\n" <>
        "Context: #{Jason.encode!(action_context)}\n" <>
        "DataModel: #{Jason.encode!(data_model)}"

    generate(prompt, opts)
  end

  @doc """
  Check if the Claude HTTP bridge is available.
  """
  @spec available?() :: boolean()
  def available? do
    case GenServer.call(__MODULE__, :ping, 5_000) do
      :pong -> true
      _ -> false
    end
  catch
    :exit, _ -> false
  end

  # Server callbacks

  @impl true
  def init(opts) do
    endpoint = opts[:endpoint] || @default_endpoint
    Logger.info("ClaudeHTTPClient initialized with endpoint #{endpoint}")
    {:ok, %{endpoint: endpoint}}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    # Try health check endpoint
    url = state.endpoint <> "/health"

    result =
      case Req.get(url, receive_timeout: 5_000) do
        {:ok, %{status: 200}} -> :pong
        _ -> :error
      end

    {:reply, result, state}
  end

  def handle_call({:generate, prompt, opts}, _from, state) do
    timeout = opts[:timeout] || @recv_timeout
    on_message = opts[:on_message]
    surface_id = opts[:surface_id] || "llm-surface"

    result = do_generate(state.endpoint, prompt, surface_id, on_message, timeout)
    {:reply, result, state}
  end

  # Private functions

  defp do_generate(endpoint, prompt, surface_id, on_message, timeout) do
    # Step 1: Create session
    create_url = endpoint <> "/sessions"

    create_body = %{
      "prompt" => prompt,
      "surfaceId" => surface_id
    }

    case Req.post(create_url, json: create_body, receive_timeout: 10_000) do
      {:ok, %{status: 201, body: %{"sessionId" => session_id}}} ->
        Logger.info("ClaudeHTTPClient created session #{session_id}")

        # Step 2: Stream SSE
        stream_url = endpoint <> "/stream/" <> session_id
        stream_messages(stream_url, on_message, timeout)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to create session: status=#{status}, body=#{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("Failed to create session: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp stream_messages(url, on_message, timeout) do
    parent = self()
    messages = []

    # Process dictionary to maintain buffer state across chunks
    Process.put(:sse_buffer, "")

    # Use a streaming request to collect SSE messages
    req_opts = [
      headers: [{"accept", "text/event-stream"}],
      receive_timeout: timeout,
      into: fn {:data, chunk}, {req, resp} ->
        # Get current buffer from process dictionary
        buffer = Process.get(:sse_buffer, "")

        # Parse SSE events from chunk
        {events, new_buffer} = parse_sse_chunk(chunk, buffer)
        Process.put(:sse_buffer, new_buffer)

        # Process each event
        # Per A2UI spec: SSE data: contains ONLY valid A2UI envelopes.
        # Stream completion/errors are signaled via HTTP connection close,
        # NOT via JSON payloads like {"streamDone": ...} or {"error": ...}.
        for event <- events do
          case parse_sse_data(event) do
            {:ok, data} when data != "" ->
              # Per spec, all data: payloads should be valid A2UI envelopes.
              # Just forward them to the consumer without filtering.
              case Jason.decode(data) do
                {:ok, _parsed} ->
                  # Valid JSON A2UI envelope
                  if on_message, do: on_message.(data)
                  send(parent, {:stream_message, data})

                {:error, _} ->
                  # Non-JSON data, skip (could be malformed)
                  :ok
              end

            _ ->
              :ok
          end
        end

        {:cont, {req, resp}}
      end
    ]

    # Start streaming in a task
    task =
      Task.async(fn ->
        case Req.get(url, req_opts) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
      end)

    # Collect messages
    collect_messages(task, messages, timeout)
  end

  defp collect_messages(%Task{ref: ref} = task, messages, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout

    receive do
      {:stream_message, data} ->
        collect_messages(task, [data | messages], remaining_timeout(deadline))

      {:stream_done, _} ->
        Task.shutdown(task, :brutal_kill)
        {:ok, Enum.reverse(messages)}

      {:stream_error, error} ->
        Task.shutdown(task, :brutal_kill)
        {:error, error}

      {^ref, :ok} ->
        # Task completed successfully - flush the DOWN message
        receive do
          {:DOWN, ^ref, :process, _, _} -> :ok
        after
          0 -> :ok
        end

        {:ok, Enum.reverse(messages)}

      {^ref, {:error, reason}} ->
        # Task completed with error - flush the DOWN message
        receive do
          {:DOWN, ^ref, :process, _, _} -> :ok
        after
          0 -> :ok
        end

        {:error, reason}

      {:DOWN, ^ref, :process, _, reason} ->
        {:error, {:task_crashed, reason}}
    after
      remaining_timeout(deadline) ->
        Task.shutdown(task, :brutal_kill)
        {:error, :timeout}
    end
  end

  defp remaining_timeout(deadline) do
    max(0, deadline - System.monotonic_time(:millisecond))
  end

  defp parse_sse_chunk(chunk, buffer) do
    combined = buffer <> chunk

    # Split on double newlines (SSE event boundary)
    parts = String.split(combined, ~r/\r?\n\r?\n/)

    case parts do
      [incomplete] ->
        {[], incomplete}

      parts ->
        {complete, [maybe_incomplete]} = Enum.split(parts, -1)
        {complete, maybe_incomplete}
    end
  end

  defp parse_sse_data(event_text) do
    lines = String.split(event_text, ~r/\r?\n/)

    data =
      lines
      |> Enum.filter(&String.starts_with?(&1, "data:"))
      |> Enum.map(fn line ->
        line
        |> String.trim_leading("data:")
        |> String.trim_leading(" ")
      end)
      |> Enum.join("\n")

    {:ok, data}
  end
end
