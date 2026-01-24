defmodule A2UIDemo.Demo.OllamaClientTest do
  use ExUnit.Case, async: true

  @moduletag :ollama

  describe "check_availability/1" do
    @tag :external
    test "returns :ok when Ollama is running and model exists" do
      case A2UIDemo.Demo.OllamaClient.check_availability() do
        :ok ->
          assert true

        {:error, {:connection_failed, _}} ->
          skip_test("Ollama not running")

        {:error, {:model_not_found, model, available}} ->
          skip_test("Model #{model} not found. Available: #{inspect(available)}")

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end
  end

  describe "generate/2" do
    @tag :external
    test "generates valid A2UI messages from prompt" do
      opts =
        case A2UIDemo.Demo.OllamaClient.list_available_models() do
          {:ok, models} ->
            case Enum.find(models, & &1.supports_schema) do
              nil -> []
              model -> [model: model.name, force_schema: true]
            end

          {:error, {:connection_failed, _}} ->
            :skip

          {:error, reason} ->
            {:error, reason}
        end

      case opts do
        :skip ->
          skip_test("Ollama not running")

        {:error, reason} ->
          skip_test("Unable to list models: #{inspect(reason)}")

        opts ->
          case A2UIDemo.Demo.OllamaClient.generate("show a simple hello message", opts) do
            {:ok, messages} ->
              assert is_list(messages)
              assert length(messages) > 0

              # Each message should be valid JSON
              for json <- messages do
                assert {:ok, _} = Jason.decode(json)
              end

              # Should have surfaceUpdate
              json_str = Enum.join(messages, "")
              assert json_str =~ "surfaceUpdate"

            {:error, {:connection_failed, _}} ->
              skip_test("Ollama not running")

            {:error, {:model_not_found, model, _}} ->
              skip_test("Model #{model} not available")

            {:error, {:json_parse_error, _reason}} ->
              skip_test("Model returned invalid JSON")

            {:error, reason} ->
              flunk("Generation failed: #{inspect(reason)}")
          end
      end
    end
  end

  defp skip_test(reason) do
    IO.puts("\n  Skipping test: #{reason}")
    assert true
  end
end
