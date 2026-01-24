defmodule A2UIDemo.Demo.ClaudeClient do
  @moduledoc """
  ZeroMQ DEALER client for communicating with the Claude A2UI bridge.

  Connects to a ZMQ ROUTER (TypeScript process) that handles Claude API calls
  and streams back A2UI messages.

  ## Usage

      # Start the client (usually done by supervisor)
      {:ok, pid} = A2UI.ClaudeClient.start_link()

      # Generate A2UI from a prompt
      {:ok, messages} = A2UI.ClaudeClient.generate("show a todo list")

      # With callback for streaming
      A2UI.ClaudeClient.generate("show weather",
        on_message: fn msg -> send(self(), {:a2ui_msg, msg}) end
      )
  """

  use GenServer
  require Logger

  @default_endpoint "tcp://127.0.0.1:5555"
  # 5 minutes - Claude can take a while
  @recv_timeout 300_000
  # Check for messages every 100ms
  @poll_interval 100

  # Client API

  @doc """
  Start the Claude client GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate A2UI messages from a user prompt.

  ## Options

  - `:endpoint` - ZMQ endpoint (default: #{@default_endpoint})
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

    # Format as action request (special format the bridge understands).
    # Use JSON-encoded fields to keep each value on a single line.
    prompt =
      "__ACTION__\n" <>
        "OriginalJSON: #{Jason.encode!(original_prompt)}\n" <>
        "Action: #{action_name}\n" <>
        "Context: #{Jason.encode!(action_context)}\n" <>
        "DataModel: #{Jason.encode!(data_model)}"

    generate(prompt, opts)
  end

  @doc """
  Check if the Claude bridge is available.
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

    case init_zmq(endpoint) do
      {:ok, context, socket} ->
        Logger.info("ClaudeClient connected to #{endpoint}")
        {:ok, %{context: context, socket: socket, endpoint: endpoint, request_counter: 0}}

      {:error, reason} ->
        Logger.error("ClaudeClient failed to connect: #{inspect(reason)}")
        # Start anyway, will retry on first request
        {:ok, %{context: nil, socket: nil, endpoint: endpoint, request_counter: 0}}
    end
  end

  @impl true
  def handle_call(:ping, _from, %{socket: nil} = state) do
    {:reply, :error, state}
  end

  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  def handle_call({:generate, prompt, opts}, _from, state) do
    state = maybe_reconnect(state)

    case state.socket do
      nil ->
        {:reply, {:error, :not_connected}, state}

      socket ->
        timeout = opts[:timeout] || @recv_timeout
        on_message = opts[:on_message]

        # Generate unique request ID
        request_id = "req_#{state.request_counter}"
        state = %{state | request_counter: state.request_counter + 1}

        Logger.info(
          "ClaudeClient sending request #{request_id}: #{String.slice(prompt, 0, 50)}..."
        )

        # Send request: [empty_frame, request_id, prompt]
        case :erlzmq.send_multipart(socket, ["", request_id, prompt]) do
          :ok ->
            Logger.info("ClaudeClient request #{request_id} sent, waiting for response...")
            result = receive_messages(socket, request_id, on_message, [], timeout)

            Logger.info(
              "ClaudeClient request #{request_id} completed: #{inspect(result, limit: 100)}"
            )

            {:reply, result, state}

          {:error, reason} ->
            Logger.error("Failed to send request: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def terminate(_reason, %{socket: socket, context: context}) do
    if socket, do: :erlzmq.close(socket)
    if context, do: :erlzmq.term(context)
    :ok
  end

  # Private functions

  defp init_zmq(endpoint) do
    with {:ok, context} <- :erlzmq.context(),
         {:ok, socket} <- :erlzmq.socket(context, :dealer),
         # Set receive timeout so recv doesn't block forever
         :ok <- :erlzmq.setsockopt(socket, :rcvtimeo, @poll_interval),
         :ok <- :erlzmq.connect(socket, String.to_charlist(endpoint)) do
      {:ok, context, socket}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_reconnect(%{socket: nil, endpoint: endpoint} = state) do
    case init_zmq(endpoint) do
      {:ok, context, socket} ->
        Logger.info("ClaudeClient reconnected to #{endpoint}")
        %{state | context: context, socket: socket}

      {:error, _reason} ->
        state
    end
  end

  defp maybe_reconnect(state), do: state

  defp receive_messages(socket, request_id, on_message, acc, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout

    receive_loop(socket, request_id, on_message, acc, deadline)
  end

  defp receive_loop(socket, request_id, on_message, acc, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      Logger.warning("ClaudeClient timeout waiting for response")
      {:error, :timeout}
    else
      # recv_multipart will timeout after @poll_interval ms (set via rcvtimeo)
      case :erlzmq.recv_multipart(socket) do
        {:ok, parts} ->
          Logger.debug("Received parts: #{inspect(parts, limit: 50)}")
          handle_response(parts, socket, request_id, on_message, acc, deadline)

        {:error, :eagain} ->
          # rcvtimeo expired, no message yet - continue waiting
          receive_loop(socket, request_id, on_message, acc, deadline)

        {:error, :etimedout} ->
          # Alternative timeout error code
          receive_loop(socket, request_id, on_message, acc, deadline)

        {:error, reason} ->
          Logger.error("recv_multipart failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp handle_response(parts, socket, request_id, on_message, acc, deadline) do
    # Detailed logging to debug message format
    parts_info = Enum.map(parts, fn p -> "#{inspect(p)} (#{byte_size(p)} bytes)" end)

    Logger.info(
      "handle_response parts=[#{Enum.join(parts_info, ", ")}], expected_id=#{request_id}"
    )

    # More flexible pattern matching - don't rely on pin operator
    case parts do
      [empty, recv_id, msg] when empty == <<>> or empty == "" ->
        recv_id_str = to_string(recv_id)
        msg_str = to_string(msg)

        Logger.debug(
          "Received 3-part message: recv_id=#{recv_id_str}, msg=#{String.slice(msg_str, 0, 50)}"
        )

        cond do
          recv_id_str != request_id ->
            Logger.warning(
              "Message for different request: #{recv_id_str} (expected #{request_id})"
            )

            receive_loop(socket, request_id, on_message, acc, deadline)

          msg_str == "__done__" ->
            Logger.info(
              "ClaudeClient received __done__ for #{request_id}, collected #{length(acc)} messages"
            )

            {:ok, Enum.reverse(acc)}

          true ->
            Logger.info("ClaudeClient received A2UI message for #{request_id}")
            if on_message, do: on_message.(msg)
            receive_loop(socket, request_id, on_message, [msg | acc], deadline)
        end

      [empty, recv_id, err_marker, error_msg]
      when (empty == <<>> or empty == "") and err_marker == "__error__" ->
        recv_id_str = to_string(recv_id)

        if recv_id_str == request_id do
          Logger.error("ClaudeClient received error for #{request_id}: #{error_msg}")
          {:error, {:bridge_error, to_string(error_msg)}}
        else
          Logger.warning("Error for different request: #{recv_id_str}")
          receive_loop(socket, request_id, on_message, acc, deadline)
        end

      other ->
        Logger.warning(
          "Unexpected message format (#{length(other)} parts): #{inspect(other, limit: 200)}"
        )

        receive_loop(socket, request_id, on_message, acc, deadline)
    end
  end
end
