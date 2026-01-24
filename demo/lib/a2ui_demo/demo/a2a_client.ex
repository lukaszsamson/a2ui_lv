defmodule A2UIDemo.Demo.A2AClient do
  @moduledoc """
  A2A transport client for communicating with the Claude A2A bridge.

  Connects to an A2A-compliant agent that generates A2UI interfaces
  using the full A2A protocol format.

  ## Usage

      # Start the client (usually done by supervisor)
      {:ok, pid} = A2UIDemo.Demo.A2AClient.start_link()

      # Generate A2UI from a prompt
      {:ok, messages} = A2UIDemo.Demo.A2AClient.generate("show a todo list")

      # With callback for streaming
      A2UIDemo.Demo.A2AClient.generate("show weather",
        on_message: fn msg -> send(self(), {:a2ui_msg, msg}) end
      )
  """

  use GenServer
  require Logger

  alias A2UI.A2A.Protocol
  alias A2UI.A2A.DataPart
  alias A2UI.ClientCapabilities
  alias A2UI.Transport.A2A.AgentCard

  @default_endpoint "http://127.0.0.1:3002"
  # 5 minutes - Claude can take a while
  @recv_timeout 300_000

  # Client API

  @doc """
  Start the A2A client GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate A2UI messages from a user prompt.

  ## Options

  - `:endpoint` - A2A endpoint (default: #{@default_endpoint})
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
  Check if the A2A bridge is available and supports A2UI.
  """
  @spec available?() :: boolean()
  def available? do
    case GenServer.call(__MODULE__, :check_available, 3_000) do
      :available -> true
      _ -> false
    end
  catch
    :exit, _ -> false
  end

  # Server callbacks

  @impl true
  def init(opts) do
    endpoint = opts[:endpoint] || @default_endpoint
    capabilities = opts[:capabilities] || ClientCapabilities.default()

    Logger.info("A2AClient initialized with endpoint #{endpoint}")

    {:ok,
     %{
       endpoint: endpoint,
       capabilities: capabilities,
       agent_card: nil
     }}
  end

  @impl true
  def handle_call(:check_available, _from, state) do
    # Fetch agent card with short timeout and no retries for quick availability check
    case fetch_agent_card(state.endpoint, timeout: 2_000, retry: false) do
      {:ok, card} ->
        if AgentCard.supports_a2ui?(card) do
          {:reply, :available, %{state | agent_card: card}}
        else
          {:reply, :no_a2ui_support, state}
        end

      {:error, _reason} ->
        {:reply, :error, state}
    end
  end

  def handle_call({:generate, prompt, opts}, _from, state) do
    timeout = opts[:timeout] || @recv_timeout
    on_message = opts[:on_message]
    surface_id = opts[:surface_id] || "llm-surface"

    result = do_generate(state, prompt, surface_id, on_message, timeout)
    {:reply, result, state}
  end

  # Private functions

  defp fetch_agent_card(endpoint, opts \\ []) do
    url = endpoint <> "/.well-known/agent.json"
    headers = a2a_headers()

    # Use short timeout and no retries for availability checks
    timeout = Keyword.get(opts, :timeout, 10_000)
    retry = Keyword.get(opts, :retry, :transient)

    case Req.get(url, headers: headers, receive_timeout: timeout, retry: retry) do
      {:ok, %{status: 200, body: body}} ->
        AgentCard.parse(body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to fetch agent card: status=#{status}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("Failed to fetch agent card: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_generate(state, prompt, _surface_id, on_message, timeout) do
    # Step 1: Create task
    create_url = state.endpoint <> "/a2a/tasks"
    headers = a2a_headers()

    # Build A2A message with text content
    create_body = build_initial_message(state.capabilities, prompt)

    case Req.post(create_url, headers: headers, json: create_body, receive_timeout: 30_000) do
      {:ok, %{status: status, body: %{"taskId" => task_id}}} when status in [200, 201] ->
        Logger.info("A2AClient created task #{task_id}")

        # Step 2: Stream SSE
        stream_url = state.endpoint <> "/a2a/tasks/" <> task_id
        stream_messages(stream_url, headers, on_message, timeout)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to create task: status=#{status}, body=#{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("Failed to create task: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp stream_messages(url, headers, on_message, timeout) do
    parent = self()
    messages = []

    # Process dictionary to maintain buffer state across chunks
    Process.put(:sse_buffer, "")

    # Use a streaming request to collect SSE messages
    req_opts = [
      headers: headers ++ [{"accept", "text/event-stream"}],
      receive_timeout: timeout,
      into: fn {:data, chunk}, {req, resp} ->
        # Get current buffer from process dictionary
        buffer = Process.get(:sse_buffer, "")

        # Parse SSE events from chunk
        {events, new_buffer} = parse_sse_chunk(chunk, buffer)
        Process.put(:sse_buffer, new_buffer)

        # Process each event
        for event <- events do
          case parse_sse_data(event) do
            {:ok, data} when data != "" ->
              # Parse A2A message and extract A2UI envelopes
              process_a2a_message(data, on_message, parent)

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

  defp process_a2a_message(data, on_message, parent) do
    case Jason.decode(data) do
      {:ok, %{"message" => _} = a2a_msg} ->
        # Extract A2UI envelopes from DataParts
        envelopes = DataPart.extract_envelopes(a2a_msg)

        for envelope <- envelopes do
          json = Jason.encode!(envelope)

          if on_message, do: on_message.(json)
          send(parent, {:stream_message, json})
        end

      {:ok, envelope} when is_map(envelope) ->
        # Not wrapped in A2A message, handle directly (backward compat)
        if on_message, do: on_message.(data)
        send(parent, {:stream_message, data})

      {:error, _} ->
        # Not valid JSON, skip
        :ok
    end
  end

  defp collect_messages(task, messages, timeout) do
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

      {^task, :ok} ->
        {:ok, Enum.reverse(messages)}

      {^task, {:error, reason}} ->
        {:error, reason}

      {:DOWN, _, :process, _, reason} ->
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

  defp a2a_headers do
    extension_uri = Protocol.extension_uri(:v0_8)

    [
      {"x-a2a-extensions", extension_uri},
      {"content-type", "application/json"}
    ]
  end

  defp build_initial_message(capabilities, content) do
    %{
      "message" => %{
        "role" => Protocol.client_role(),
        "metadata" => %{
          Protocol.client_capabilities_key() => ClientCapabilities.to_a2a_metadata(capabilities)
        },
        "parts" => [
          %{"text" => content}
        ]
      }
    }
  end
end
