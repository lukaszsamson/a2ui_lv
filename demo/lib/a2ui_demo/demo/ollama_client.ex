defmodule A2UIDemo.Demo.OllamaClient do
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

  alias A2UI.Binding
  alias A2UIDemo.Demo.Ollama.{ModelConfig, PromptBuilder}

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
    protocol_version = opts[:protocol_version] || :v0_8

    config = ModelConfig.get(model_name)

    # Determine if we should use schema
    force_schema = opts[:force_schema]

    use_schema =
      case force_schema do
        nil -> config.supports_schema
        val -> val
      end

    temperature_zero = force_schema == true

    system_prompt = PromptBuilder.build(config, surface_id, protocol_version)

    Logger.info("Generating A2UI with #{model_name} (schema: #{use_schema}, stream: #{stream})")

    if stream do
      generate_streaming(
        user_prompt,
        system_prompt,
        model_name,
        base_url,
        surface_id,
        use_schema,
        protocol_version,
        temperature_zero,
        on_chunk
      )
    else
      generate_sync(
        user_prompt,
        system_prompt,
        model_name,
        base_url,
        surface_id,
        use_schema,
        protocol_version,
        temperature_zero
      )
    end
  end

  @doc """
  Generate A2UI response for a user action (follow-up request).

  This sends the action context along with the current data model back to the LLM
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
    model_name = opts[:model] || @default_model
    base_url = opts[:base_url] || @default_base_url
    surface_id = opts[:surface_id] || "llm-surface"
    stream = opts[:stream] || false
    on_chunk = opts[:on_chunk]
    protocol_version = opts[:protocol_version] || :v0_8

    config = ModelConfig.get(model_name)

    # Determine if we should use schema
    force_schema = opts[:force_schema]

    use_schema =
      case force_schema do
        nil -> config.supports_schema
        val -> val
      end

    temperature_zero = force_schema == true

    # Extract action info
    action =
      user_action["action"] ||
        user_action["userAction"] ||
        user_action

    action_name = action["name"] || "unknown"
    action_context = action["context"] || %{}

    action_info = %{
      original_prompt: original_prompt,
      action_name: action_name,
      action_context: action_context,
      data_model: data_model
    }

    system_prompt =
      PromptBuilder.build_action_prompt(config, surface_id, action_info, protocol_version)

    Logger.info(
      "Generating A2UI action response with #{model_name} (action: #{action_name}, schema: #{use_schema})"
    )

    # Use a minimal user prompt since context is in system prompt
    user_prompt = "Process the action '#{action_name}' and generate the updated UI."

    if stream do
      generate_streaming(
        user_prompt,
        system_prompt,
        model_name,
        base_url,
        surface_id,
        use_schema,
        protocol_version,
        temperature_zero,
        on_chunk
      )
    else
      generate_sync(
        user_prompt,
        system_prompt,
        model_name,
        base_url,
        surface_id,
        use_schema,
        protocol_version,
        temperature_zero
      )
    end
  end

  # Synchronous generation
  defp generate_sync(
         user_prompt,
         system_prompt,
         model,
         base_url,
         surface_id,
         use_schema,
         protocol_version,
         temperature_zero
       ) do
    request_body =
      build_request_body(
        user_prompt,
        system_prompt,
        model,
        use_schema,
        protocol_version,
        temperature_zero,
        false
      )

    case Req.post("#{base_url}/api/generate",
           json: request_body,
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: body}} ->
        parse_response(body, surface_id, protocol_version)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Ollama API error: #{status} - #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("Ollama request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Streaming generation
  defp generate_streaming(
         user_prompt,
         system_prompt,
         model,
         base_url,
         surface_id,
         use_schema,
         protocol_version,
         temperature_zero,
         on_chunk
       ) do
    on_chunk =
      if is_function(on_chunk, 1) do
        on_chunk
      else
        fn _chunk -> :ok end
      end

    request_body =
      build_request_body(
        user_prompt,
        system_prompt,
        model,
        use_schema,
        protocol_version,
        temperature_zero,
        true
      )

    pid = self()

    Process.put(:ollama_stream_buffer, "")
    Process.put(:ollama_stream_response, "")

    # Ollama streaming returns newline-delimited JSON (NDJSON). Req may deliver
    # arbitrary chunks, so we buffer and split on newlines before decoding.
    stream_handler = fn
      {:data, data}, {req, resp} ->
        chunk = IO.iodata_to_binary(data)
        buffer = Process.get(:ollama_stream_buffer, "") <> chunk
        lines = String.split(buffer, "\n", trim: false)

        {complete_lines, rest} =
          case lines do
            [] -> {[], ""}
            _ -> {Enum.drop(lines, -1), List.last(lines) || ""}
          end

        Process.put(:ollama_stream_buffer, rest)

        done? =
          Enum.reduce_while(complete_lines, false, fn line, _acc ->
            line = String.trim(line)

            if line == "" do
              {:cont, false}
            else
              case Jason.decode(line) do
                {:ok, %{"response" => resp_chunk} = msg} when is_binary(resp_chunk) ->
                  response = Process.get(:ollama_stream_response, "") <> resp_chunk
                  Process.put(:ollama_stream_response, response)
                  on_chunk.(resp_chunk)

                  if msg["done"] == true do
                    send(pid, {:stream_complete, response})
                    {:halt, true}
                  else
                    {:cont, false}
                  end

                {:ok, %{"done" => true}} ->
                  response = Process.get(:ollama_stream_response, "")
                  send(pid, {:stream_complete, response})
                  {:halt, true}

                _ ->
                  {:cont, false}
              end
            end
          end)

        if done? do
          {:halt, {req, resp}}
        else
          {:cont, {req, resp}}
        end

      {:done, _}, {req, resp} ->
        # Best-effort: process any trailing buffered line (stream may not end with "\n").
        tail = String.trim(Process.get(:ollama_stream_buffer, ""))
        response = Process.get(:ollama_stream_response, "")

        response =
          if tail != "" do
            case Jason.decode(tail) do
              {:ok, %{"response" => resp_chunk}} when is_binary(resp_chunk) ->
                on_chunk.(resp_chunk)
                response <> resp_chunk

              _ ->
                response
            end
          else
            response
          end

        Process.put(:ollama_stream_response, response)
        send(pid, {:stream_complete, response})
        {:halt, {req, resp}}

      _other, {req, resp} ->
        {:cont, {req, resp}}
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
        parse_response(%{"response" => response}, surface_id, protocol_version)

      {:stream_error, reason} ->
        {:error, reason}
    after
      @timeout ->
        {:error, :timeout}
    end
  end

  defp build_request_body(
         user_prompt,
         system_prompt,
         model,
         use_schema,
         protocol_version,
         temperature_zero,
         stream
       ) do
    body = %{
      "model" => model,
      "prompt" => user_prompt,
      "system" => system_prompt,
      "stream" => stream
    }

    body =
      if temperature_zero do
        Map.put(body, "options", %{"temperature" => 0})
      else
        body
      end

    if use_schema do
      Map.put(body, "format", PromptBuilder.a2ui_schema(protocol_version))
    else
      body
    end
  end

  defp parse_response(%{"response" => response_str}, surface_id, protocol_version) do
    Logger.debug("Raw response: #{String.slice(response_str, 0, 500)}")

    json_str = extract_json(response_str)

    case Jason.decode(json_str) do
      {:ok, parsed} ->
        messages = build_a2ui_messages(parsed, surface_id, protocol_version)
        {:ok, messages}

      {:error, reason} ->
        Logger.error("Failed to parse JSON: #{inspect(reason)}")
        {:error, {:json_parse_error, reason}}
    end
  end

  defp parse_response(body, _surface_id, _protocol_version) do
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

  defp build_a2ui_messages(parsed, surface_id, :v0_9) do
    build_a2ui_messages_v09(parsed, surface_id)
  end

  defp build_a2ui_messages(parsed, surface_id, _version) do
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

    # 2. dataModelUpdate message(s) - strict v0.8 encoding (no nested valueMap).
    messages =
      if data_model = parsed["dataModel"] do
        build_data_model_update_messages(data_model, surface_id) ++ messages
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
        json =
          Jason.encode!(%{"beginRendering" => %{"surfaceId" => surface_id, "root" => "root"}})

        [json | messages]
      end

    Enum.reverse(messages)
  end

  defp build_a2ui_messages_v09(parsed, surface_id) do
    catalog_id =
      get_in(parsed, ["createSurface", "catalogId"]) ||
        "https://a2ui.dev/specification/v0_9/standard_catalog.json"

    create_surface = %{
      "createSurface" => %{
        "surfaceId" => surface_id,
        "catalogId" => catalog_id
      }
    }

    update_components =
      case parsed["updateComponents"] do
        nil -> nil
        update -> %{"updateComponents" => Map.put(update, "surfaceId", surface_id)}
      end

    update_data_model =
      case parsed["dataModel"] do
        nil ->
          nil

        data_model ->
          %{
            "updateDataModel" => %{
              "surfaceId" => surface_id,
              "path" => "/",
              "value" => data_model
            }
          }
      end

    [
      Jason.encode!(create_surface),
      update_components && Jason.encode!(update_components),
      update_data_model && Jason.encode!(update_data_model)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp build_data_model_update_messages(data_model, surface_id) when is_map(data_model) do
    updates =
      [%{path: nil, contents: contents_for_container(data_model)}] ++
        nested_container_updates("", data_model)

    Enum.map(updates, fn %{path: path, contents: contents} ->
      payload =
        %{
          "surfaceId" => surface_id,
          "contents" => contents
        }
        |> maybe_put_path(path)

      Jason.encode!(%{"dataModelUpdate" => payload})
    end)
  end

  defp build_data_model_update_messages(_data_model, _surface_id), do: []

  defp maybe_put_path(payload, nil), do: payload
  defp maybe_put_path(payload, ""), do: payload
  defp maybe_put_path(payload, path) when is_binary(path), do: Map.put(payload, "path", path)

  defp contents_for_container(container) when is_map(container) do
    Enum.map(container, fn {key, value} -> content_entry(to_string(key), value) end)
  end

  defp contents_for_container(container) when is_list(container) do
    container
    |> Enum.with_index()
    |> Enum.map(fn {value, idx} -> content_entry(Integer.to_string(idx), value) end)
  end

  defp contents_for_container(_), do: []

  defp content_entry(key, value) when is_binary(key) do
    base = %{"key" => key}

    cond do
      is_binary(value) ->
        Map.put(base, "valueString", value)

      is_number(value) ->
        Map.put(base, "valueNumber", value)

      is_boolean(value) ->
        Map.put(base, "valueBoolean", value)

      is_map(value) or is_list(value) ->
        # v0.8: valueMap cannot contain nested valueMap entries. We create an empty
        # map placeholder and populate children via path-based updates.
        Map.put(base, "valueMap", [])

      true ->
        Map.put(base, "valueString", inspect(value))
    end
  end

  defp nested_container_updates(base_path, container) when is_map(container) do
    container
    |> Enum.flat_map(fn {key, value} ->
      nested_updates_for_entry(base_path, to_string(key), value)
    end)
  end

  defp nested_container_updates(base_path, container) when is_list(container) do
    container
    |> Enum.with_index()
    |> Enum.flat_map(fn {value, idx} ->
      nested_updates_for_entry(base_path, Integer.to_string(idx), value)
    end)
  end

  defp nested_container_updates(_base_path, _), do: []

  defp nested_updates_for_entry(base_path, key, value)
       when is_binary(key) and (is_map(value) or is_list(value)) do
    path = Binding.append_pointer_segment(base_path, key)
    contents = contents_for_container(value)

    updates =
      if contents == [] do
        []
      else
        [%{path: path, contents: contents}]
      end

    updates ++ nested_container_updates(path, value)
  end

  defp nested_updates_for_entry(_base_path, _key, _value), do: []

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
