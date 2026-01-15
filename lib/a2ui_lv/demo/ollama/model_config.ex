defmodule A2uiLv.Demo.Ollama.ModelConfig do
  @moduledoc """
  Model-specific configurations for Ollama LLM integration.

  Different models have varying capabilities:
  - Some support JSON schema forcing via `format` parameter
  - Some work better with streaming
  - Some need different prompt styles

  Use `get/1` to retrieve config for a model, or `list/0` to see all available configs.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          display_name: String.t(),
          supports_schema: boolean(),
          supports_streaming: boolean(),
          prompt_style: :concise | :detailed | :minimal,
          description: String.t()
        }

  defstruct [
    :name,
    :display_name,
    supports_schema: false,
    supports_streaming: true,
    prompt_style: :concise,
    description: ""
  ]

  @doc """
  Get configuration for a specific model.
  Returns default config if model not found.
  """
  @spec get(String.t()) :: t()
  def get(model_name) do
    Map.get(configs(), model_name, default_config(model_name))
  end

  @doc """
  List all configured models.
  """
  @spec list() :: [t()]
  def list do
    Map.values(configs())
  end

  @doc """
  List model names only.
  """
  @spec model_names() :: [String.t()]
  def model_names do
    Map.keys(configs())
  end

  defp default_config(model_name) do
    %__MODULE__{
      name: model_name,
      display_name: model_name,
      supports_schema: false,
      supports_streaming: true,
      prompt_style: :concise,
      description: "Unknown model"
    }
  end

  defp configs do
    %{
      "gpt-oss:latest" => %__MODULE__{
        name: "gpt-oss:latest",
        display_name: "GPT-OSS 20B",
        supports_schema: false,
        supports_streaming: true,
        prompt_style: :concise,
        description: "Large reasoning model, no schema support"
      },
      "gemma3:4b" => %__MODULE__{
        name: "gemma3:4b",
        display_name: "Gemma 3 4B",
        supports_schema: true,
        supports_streaming: true,
        prompt_style: :detailed,
        description: "Fast, supports JSON schema"
      },
      "gemma3:12b" => %__MODULE__{
        name: "gemma3:12b",
        display_name: "Gemma 3 12B",
        supports_schema: true,
        supports_streaming: true,
        prompt_style: :detailed,
        description: "Larger Gemma, better quality"
      },
      "qwen3:latest" => %__MODULE__{
        name: "qwen3:latest",
        display_name: "Qwen 3",
        supports_schema: true,
        supports_streaming: true,
        prompt_style: :detailed,
        description: "Qwen 3 with schema support"
      },
      "qwen3-vl:8b" => %__MODULE__{
        name: "qwen3-vl:8b",
        display_name: "Qwen 3 VL 8B",
        supports_schema: true,
        supports_streaming: true,
        prompt_style: :detailed,
        description: "Vision-language model"
      },
      "ministral-3:8b" => %__MODULE__{
        name: "ministral-3:8b",
        display_name: "Ministral 3 8B",
        supports_schema: true,
        supports_streaming: true,
        prompt_style: :concise,
        description: "Mistral's smaller model"
      },
      "deepseek-r1:7b" => %__MODULE__{
        name: "deepseek-r1:7b",
        display_name: "DeepSeek R1 7B",
        supports_schema: false,
        supports_streaming: true,
        prompt_style: :minimal,
        description: "Reasoning model, outputs thinking"
      },
      "deepseek-r1:14b" => %__MODULE__{
        name: "deepseek-r1:14b",
        display_name: "DeepSeek R1 14B",
        supports_schema: false,
        supports_streaming: true,
        prompt_style: :minimal,
        description: "Larger reasoning model"
      },
      "llama3.2:3b-text-q5_K_M" => %__MODULE__{
        name: "llama3.2:3b-text-q5_K_M",
        display_name: "Llama 3.2 3B",
        supports_schema: true,
        supports_streaming: true,
        prompt_style: :detailed,
        description: "Small Llama model"
      }
    }
  end
end
