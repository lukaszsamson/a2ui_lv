defmodule A2UIDemo.Demo.A2AClient do
  @moduledoc """
  A2A transport client for communicating with the Claude A2A bridge.

  Connects to an A2A-compliant agent that generates A2UI interfaces
  using the full A2A protocol format. Uses the a2a_ex library for
  HTTP transport and SSE handling.

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
    action =
      user_action["action"] ||
        user_action["userAction"] ||
        user_action

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
    # Fetch agent card with short timeout for quick availability check
    config_opts = a2a_config_opts(timeout: 2_000)

    case A2A.Client.discover(state.endpoint, config_opts) do
      {:ok, a2a_card} ->
        card = AgentCard.from_a2a_ex(a2a_card)

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
    _surface_id = opts[:surface_id] || "llm-surface"

    result = do_generate(state, prompt, on_message, timeout)
    {:reply, result, state}
  end

  # Private functions

  defp do_generate(state, prompt, on_message, timeout) do
    # Build A2A message with text content
    message = build_a2a_message(state.capabilities, prompt)
    config_opts = a2a_config_opts(timeout: timeout)

    # Use stream_message to get streaming response
    case A2A.Client.stream_message(state.endpoint, [message: message], config_opts) do
      {:ok, stream} ->
        Logger.info("A2AClient streaming started")
        collect_stream_messages(stream, on_message, timeout)

      {:error, %A2A.Error{} = error} ->
        Logger.error("Failed to start streaming: #{inspect(error)}")
        {:error, error}

      {:error, reason} ->
        Logger.error("Failed to start streaming: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp collect_stream_messages(stream, on_message, timeout) do
    parent = self()

    # Start async task to process stream
    task =
      Task.async(fn ->
        try do
          Enum.reduce(stream, [], fn item, acc ->
            case process_stream_item(item, on_message, parent) do
              {:ok, new_messages} -> acc ++ new_messages
              :skip -> acc
            end
          end)
        rescue
          e ->
            Logger.error("Stream processing error: #{inspect(e)}")
            {:error, e}
        end
      end)

    # Wait for task with timeout
    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:error, reason}} ->
        {:error, reason}

      {:ok, collected} when is_list(collected) ->
        {:ok, collected}

      nil ->
        {:error, :timeout}

      {:exit, reason} ->
        {:error, {:task_crashed, reason}}
    end
  end

  defp process_stream_item(%A2A.Types.StreamResponse{message: msg}, on_message, _parent)
       when not is_nil(msg) do
    # Convert message to map and extract A2UI envelopes
    message_map = A2A.Types.Message.to_map(msg)
    envelopes = DataPart.extract_envelopes(%{"message" => message_map})

    messages =
      for envelope <- envelopes do
        json = Jason.encode!(envelope)
        if on_message, do: on_message.(json)
        json
      end

    {:ok, messages}
  end

  defp process_stream_item(%A2A.Types.StreamResponse{status_update: update}, on_message, _parent)
       when not is_nil(update) do
    # Status updates may contain messages too
    if update.status && update.status.message do
      message_map = A2A.Types.Message.to_map(update.status.message)
      envelopes = DataPart.extract_envelopes(%{"message" => message_map})

      messages =
        for envelope <- envelopes do
          json = Jason.encode!(envelope)
          if on_message, do: on_message.(json)
          json
        end

      {:ok, messages}
    else
      :skip
    end
  end

  defp process_stream_item(%A2A.Types.StreamResponse{task: task}, on_message, _parent)
       when not is_nil(task) do
    # Task updates - check for messages in history
    if task.history do
      messages =
        for msg <- task.history do
          message_map = A2A.Types.Message.to_map(msg)
          envelopes = DataPart.extract_envelopes(%{"message" => message_map})

          for envelope <- envelopes do
            json = Jason.encode!(envelope)
            if on_message, do: on_message.(json)
            json
          end
        end
        |> List.flatten()

      {:ok, messages}
    else
      :skip
    end
  end

  defp process_stream_item(%A2A.Types.StreamError{error: error}, _on_message, _parent) do
    Logger.warning("Stream error received: #{inspect(error)}")
    :skip
  end

  defp process_stream_item(_item, _on_message, _parent), do: :skip

  defp a2a_config_opts(opts) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    extension_uri = Protocol.extension_uri(:v0_8)

    [
      agent_card_path: "/.well-known/agent.json",
      legacy_extensions_header: true,
      extensions: [extension_uri],
      rest_base_path: "/a2a",
      version: :v0_3,
      req_options: [receive_timeout: timeout]
    ]
  end

  defp build_a2a_message(capabilities, content) do
    %A2A.Types.Message{
      role: :user,
      metadata: %{
        Protocol.client_capabilities_key() =>
          ClientCapabilities.to_a2a_metadata(capabilities)
      },
      parts: [
        %A2A.Types.TextPart{
          kind: "text",
          text: content
        }
      ]
    }
  end
end
