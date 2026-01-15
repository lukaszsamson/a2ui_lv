defmodule A2UI.OllamaClient do
  @moduledoc """
  HTTP client for Ollama API with model-specific configuration.

  Supports:
  - Multiple models with different capabilities
  - Optional JSON schema forcing (for models that support it)
  - Streaming and non-streaming modes
  - Model-specific prompt styles

  ## Usage

      # Simple generation
      {:ok, messages} = A2UI.OllamaClient.generate("show a todo list")

      # With specific model
      {:ok, messages} = A2UI.OllamaClient.generate("show weather", model: "gemma3:12b")

      # With streaming callback
      A2UI.OllamaClient.generate("show profile",
        stream: true,
        on_chunk: fn chunk -> send(self(), {:chunk, chunk}) end
      )
  """

  require Logger

  alias A2UI.Ollama.{ModelConfig, PromptBuilder}

  @default_base_url "http://localhost:11434"
  @default_model "gpt-oss:latest"
  @timeout 120_000

  @doc """
  Generate A2UI messages from a user prompt using Ollama.

  ## Options

  - `:model` - Ollama model to use (default: "#{@default_model}")
  - `:base_url` - Ollama API base URL (default: "#{@default_base_url}")
  - `:surface_id` - Surface ID for generated UI (default: "llm-surface")
  - `:stream` - Enable streaming mode (default: false)
  - `:force_schema` - Force JSON schema even if model doesn't support it (default: nil, uses model config)
  - `:on_chunk` - Callback function for streaming chunks (required if stream: true)
  """
  @spec generate(String.t(), keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def generate(user_prompt, opts \\ []) do
    model_name = opts[:model] || @default_model
    base_url = opts[:base_url] || @default_base_url
    surface_id = opts[:surface_id] || "llm-surface"
    stream = opts[:stream] || false
    on_chunk = opts[:on_chunk]

    config = ModelConfig.get(model_name)

    # Determine if we should use schema
    use_schema =
      case opts[:force_schema] do
        nil -> config.supports_schema
        val -> val
      end

    system_prompt = PromptBuilder.build(config, surface_id)

    Logger.info(
      "Generating A2UI with #{model_name} (schema: #{use_schema}, stream: #{stream})"
    )

    if stream do
      generate_streaming(user_prompt, system_prompt, model_name, base_url, surface_id, use_schema, on_chunk)
    else
      generate_sync(user_prompt, system_prompt, model_name, base_url, surface_id, use_schema)
    end
  end

  # Synchronous generation
  defp generate_sync(user_prompt, system_prompt, model, base_url, surface_id, use_schema) do
    request_body =
      build_request_body(user_prompt, system_prompt, model, use_schema, false)

    case Req.post("#{base_url}/api/generate",
           json: request_body,
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: body}} ->
        parse_response(body, surface_id)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Ollama API error: #{status} - #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("Ollama request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Streaming generation
  defp generate_streaming(user_prompt, system_prompt, model, base_url, surface_id, use_schema, on_chunk) do
    unless is_function(on_chunk, 1) do
      raise ArgumentError, "on_chunk callback required for streaming mode"
    end

    request_body =
      build_request_body(user_prompt, system_prompt, model, use_schema, true)

    pid = self()

    # Ollama streaming returns newline-delimited JSON (NDJSON). Req may deliver
    # arbitrary chunks, so we buffer and split on newlines before decoding.
    stream_handler = fn
      {:data, data}, acc ->
      acc =
        case acc do
          %{buffer: _buf, response: _resp, done: _done} ->
            acc

          %{buffer: _buf, response: _resp} ->
            Map.put(acc, :done, false)

          %{response: resp} ->
            %{buffer: "", response: resp, done: false}

          _ ->
            %{buffer: "", response: "", done: false}
        end

      chunk = IO.iodata_to_binary(data)
      buffer = acc.buffer <> chunk
      lines = String.split(buffer, "\n", trim: false)

      {complete_lines, rest} =
        case lines do
          [] -> {[], ""}
          _ -> {Enum.drop(lines, -1), List.last(lines) || ""}
        end

      reduce_result =
        Enum.reduce_while(complete_lines, %{acc | buffer: rest}, fn line, acc2 ->
          line = String.trim(line)

          if line == "" do
            {:cont, acc2}
          else
            case Jason.decode(line) do
              {:ok, %{"response" => resp_chunk} = msg} when is_binary(resp_chunk) ->
                new_response = acc2.response <> resp_chunk
                on_chunk.(resp_chunk)

                if msg["done"] == true do
                  send(pid, {:stream_complete, new_response})
                  {:halt, %{acc2 | response: new_response, done: true}}
                else
                  {:cont, %{acc2 | response: new_response}}
                end

              {:ok, %{"done" => true}} ->
                send(pid, {:stream_complete, acc2.response})
                {:halt, %{acc2 | done: true}}

              _ ->
                {:cont, acc2}
            end
          end
        end)

      if reduce_result.done do
        {:halt, reduce_result}
      else
        {:cont, reduce_result}
      end

      {:done, _}, acc ->
        acc =
          case acc do
            %{buffer: _buf, response: _resp, done: _done} -> acc
            %{buffer: _buf, response: _resp} -> Map.put(acc, :done, false)
            %{response: resp} -> %{buffer: "", response: resp, done: false}
            _ -> %{buffer: "", response: "", done: false}
          end

        # Best-effort: process any trailing buffered line (stream may not end with "\n").
        tail = String.trim(acc.buffer || "")

        acc =
          if tail != "" do
            case Jason.decode(tail) do
              {:ok, %{"response" => resp_chunk}} when is_binary(resp_chunk) ->
                on_chunk.(resp_chunk)
                %{acc | response: acc.response <> resp_chunk}

              _ ->
                acc
            end
          else
            acc
          end

        send(pid, {:stream_complete, acc.response})
        {:halt, %{acc | done: true}}

      _other, acc ->
        {:cont, acc}
    end

    Task.start(fn ->
      case Req.post("#{base_url}/api/generate",
             json: request_body,
             receive_timeout: @timeout,
             into: stream_handler,
             decode_body: false
           ) do
        {:ok, _} -> :ok
        {:error, reason} -> send(pid, {:stream_error, reason})
      end
    end)

    # Wait for stream to complete
    receive do
      {:stream_complete, response} ->
        parse_response(%{"response" => response}, surface_id)

      {:stream_error, reason} ->
        {:error, reason}
    after
      @timeout ->
        {:error, :timeout}
    end
  end

  defp build_request_body(user_prompt, system_prompt, model, use_schema, stream) do
    body = %{
      "model" => model,
      "prompt" => "#{system_prompt}\n\nUser request: #{user_prompt}",
      "stream" => stream
    }

    if use_schema do
      Map.put(body, "format", PromptBuilder.a2ui_schema())
    else
      body
    end
  end

  defp parse_response(%{"response" => response_str}, surface_id) do
    Logger.debug("Raw response: #{String.slice(response_str, 0, 500)}")

    json_str = extract_json(response_str)

    case Jason.decode(json_str) do
      {:ok, parsed} ->
        messages = build_a2ui_messages(parsed, surface_id)
        {:ok, messages}

      {:error, reason} ->
        Logger.error("Failed to parse JSON: #{inspect(reason)}")
        {:error, {:json_parse_error, reason}}
    end
  end

  defp parse_response(body, _surface_id) do
    Logger.error("Unexpected response format: #{inspect(body)}")
    {:error, :unexpected_response_format}
  end

  # Extract JSON object from response that may contain surrounding text
  defp extract_json(str) do
    str = String.trim(str)

    cond do
      String.starts_with?(str, "{") ->
        str

      String.contains?(str, "```json") ->
        case Regex.run(~r/```json\s*(.*?)\s*```/s, str) do
          [_, json] -> String.trim(json)
          _ -> find_json_object(str)
        end

      String.contains?(str, "```") ->
        case Regex.run(~r/```\s*(.*?)\s*```/s, str) do
          [_, json] -> String.trim(json)
          _ -> find_json_object(str)
        end

      true ->
        find_json_object(str)
    end
  end

  defp find_json_object(str) do
    case Regex.run(~r/\{.*\}/s, str) do
      [json] -> json
      _ -> str
    end
  end

  defp build_a2ui_messages(parsed, surface_id) do
    messages = []

    # 1. surfaceUpdate message
    messages =
      if surface_update = parsed["surfaceUpdate"] do
        surface_update = Map.put(surface_update, "surfaceId", surface_id)
        json = Jason.encode!(%{"surfaceUpdate" => surface_update})
        [json | messages]
      else
        messages
      end

    # 2. dataModelUpdate message
    messages =
      if data_model = parsed["dataModel"] do
        contents = convert_data_model_to_contents(data_model)

        json =
          Jason.encode!(%{
            "dataModelUpdate" => %{
              "surfaceId" => surface_id,
              "contents" => contents
            }
          })

        [json | messages]
      else
        messages
      end

    # 3. beginRendering message
    messages =
      if begin_rendering = parsed["beginRendering"] do
        begin_rendering =
          begin_rendering
          |> Map.put("surfaceId", surface_id)
          |> Map.put_new("root", "root")

        json = Jason.encode!(%{"beginRendering" => begin_rendering})
        [json | messages]
      else
        json = Jason.encode!(%{"beginRendering" => %{"surfaceId" => surface_id, "root" => "root"}})
        [json | messages]
      end

    Enum.reverse(messages)
  end

  defp convert_data_model_to_contents(data_model) when is_map(data_model) do
    Enum.map(data_model, fn {key, value} ->
      content = %{"key" => to_string(key)}

      cond do
        is_binary(value) -> Map.put(content, "valueString", value)
        is_number(value) -> Map.put(content, "valueNumber", value)
        is_boolean(value) -> Map.put(content, "valueBoolean", value)
        is_map(value) -> Map.put(content, "valueMap", convert_data_model_to_contents(value))
        true -> Map.put(content, "valueString", inspect(value))
      end
    end)
  end

  defp convert_data_model_to_contents(_), do: []

  @doc """
  Check if Ollama is available and optionally verify a specific model exists.
  """
  @spec check_availability(keyword()) :: :ok | {:error, term()}
  def check_availability(opts \\ []) do
    model = opts[:model]
    base_url = opts[:base_url] || @default_base_url

    case Req.get("#{base_url}/api/tags", receive_timeout: 5_000) do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        if model do
          model_names = Enum.map(models, & &1["name"])
          base_name = String.replace(model, ":latest", "")

          if model in model_names or base_name in model_names do
            :ok
          else
            {:error, {:model_not_found, model, model_names}}
          end
        else
          :ok
        end

      {:ok, %{status: status}} ->
        {:error, {:api_error, status}}

      {:error, reason} ->
        {:error, {:connection_failed, reason}}
    end
  end

  @doc """
  List available models from Ollama that we have configurations for.
  """
  @spec list_available_models(keyword()) :: {:ok, [ModelConfig.t()]} | {:error, term()}
  def list_available_models(opts \\ []) do
    base_url = opts[:base_url] || @default_base_url

    case Req.get("#{base_url}/api/tags", receive_timeout: 5_000) do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        available_names = Enum.map(models, & &1["name"])

        configs =
          ModelConfig.list()
          |> Enum.filter(fn config ->
            config.name in available_names or
              String.replace(config.name, ":latest", "") in available_names
          end)

        {:ok, configs}

      {:ok, %{status: status}} ->
        {:error, {:api_error, status}}

      {:error, reason} ->
        {:error, {:connection_failed, reason}}
    end
  end
end
