defmodule A2UI.A2A.DataPart do
  @moduledoc """
  A2A DataPart packaging for A2UI messages.

  This module provides functions to wrap A2UI message envelopes in A2A `DataPart`
  format, suitable for transmission over A2A protocol transports.

  ## DataPart Structure

  An A2A DataPart containing an A2UI message has:

  ```json
  {
    "data": { "userAction": { ... } },
    "metadata": {
      "mimeType": "application/json+a2ui"
    }
  }
  ```

  ## Client → Server Messages

  Client messages must include client capabilities in the A2A message metadata.
  Use `build_client_message/2` to build a complete A2A message with capabilities.

  ## Server → Client Messages

  Server messages only need the DataPart wrapper around the A2UI envelope.
  Use `wrap_envelope/1` for simple wrapping.

  ## Example

      # Wrap a userAction for client→server
      capabilities = A2UI.ClientCapabilities.default()
      event = %{"userAction" => %{"name" => "submit", ...}}
      message = A2UI.A2A.DataPart.build_client_message(event, capabilities)

      # Wrap a surfaceUpdate for server→client
      envelope = %{"surfaceUpdate" => %{"surfaceId" => "main", ...}}
      data_part = A2UI.A2A.DataPart.wrap_envelope(envelope)
  """

  alias A2UI.A2A.Protocol
  alias A2UI.ClientCapabilities

  @type a2ui_envelope :: map()
  @type data_part :: %{String.t() => term()}
  @type a2a_message :: %{String.t() => term()}

  # ============================================
  # DataPart Wrapping
  # ============================================

  @doc """
  Wraps an A2UI envelope in an A2A DataPart.

  This is the core wrapping function that adds the required `mimeType` metadata.

  ## Example

      iex> envelope = %{"surfaceUpdate" => %{"surfaceId" => "main"}}
      iex> A2UI.A2A.DataPart.wrap_envelope(envelope)
      %{
        "data" => %{"surfaceUpdate" => %{"surfaceId" => "main"}},
        "metadata" => %{"mimeType" => "application/json+a2ui"}
      }
  """
  @spec wrap_envelope(a2ui_envelope()) :: data_part()
  def wrap_envelope(envelope) when is_map(envelope) do
    %{
      "data" => envelope,
      "metadata" => %{
        "mimeType" => Protocol.mime_type()
      }
    }
  end

  @doc """
  Unwraps an A2UI envelope from an A2A DataPart.

  Returns `{:ok, envelope}` if the DataPart has the correct mimeType,
  or `{:error, reason}` if invalid.

  ## Example

      iex> data_part = %{"data" => %{"userAction" => %{}}, "metadata" => %{"mimeType" => "application/json+a2ui"}}
      iex> A2UI.A2A.DataPart.unwrap_envelope(data_part)
      {:ok, %{"userAction" => %{}}}
  """
  @spec unwrap_envelope(data_part()) :: {:ok, a2ui_envelope()} | {:error, atom()}
  def unwrap_envelope(%{"data" => data, "metadata" => %{"mimeType" => mime}}) do
    if mime == Protocol.mime_type() do
      {:ok, data}
    else
      {:error, :invalid_mime_type}
    end
  end

  def unwrap_envelope(%{"data" => data}) do
    # Lenient: accept DataPart without mimeType metadata
    {:ok, data}
  end

  def unwrap_envelope(_), do: {:error, :invalid_data_part}

  @doc """
  Checks if a DataPart contains an A2UI message based on mimeType.
  """
  @spec a2ui_data_part?(data_part()) :: boolean()
  def a2ui_data_part?(%{"metadata" => %{"mimeType" => mime}}) do
    mime == Protocol.mime_type()
  end

  def a2ui_data_part?(_), do: false

  # ============================================
  # Client Message Building
  # ============================================

  @doc """
  Builds a complete A2A message for client→server transmission.

  This wraps the A2UI envelope in a DataPart and attaches client capabilities
  to the message metadata as required by the A2UI A2A extension.

  ## Parameters

  - `envelope` - The A2UI event envelope (e.g., `%{"userAction" => ...}`)
  - `capabilities` - Client capabilities struct

  ## Example

      iex> caps = A2UI.ClientCapabilities.default()
      iex> event = %{"userAction" => %{"name" => "click", "surfaceId" => "main"}}
      iex> msg = A2UI.A2A.DataPart.build_client_message(event, caps)
      %{
        "message" => %{
          "role" => "user",
          "metadata" => %{
            "a2uiClientCapabilities" => %{"supportedCatalogIds" => [...]}
          },
          "parts" => [
            %{
              "data" => %{"userAction" => ...},
              "metadata" => %{"mimeType" => "application/json+a2ui"}
            }
          ]
        }
      }
  """
  @spec build_client_message(a2ui_envelope(), ClientCapabilities.t()) :: a2a_message()
  def build_client_message(envelope, %ClientCapabilities{} = capabilities) do
    %{
      "message" => %{
        "role" => Protocol.client_role(),
        "metadata" => %{
          Protocol.client_capabilities_key() => ClientCapabilities.to_a2a_metadata(capabilities)
        },
        "parts" => [wrap_envelope(envelope)]
      }
    }
  end

  @doc """
  Builds a complete A2A message for server→client transmission.

  Server messages don't require client capabilities, just the wrapped DataPart.

  ## Example

      iex> envelope = %{"beginRendering" => %{"surfaceId" => "main", "root" => "root"}}
      iex> A2UI.A2A.DataPart.build_server_message(envelope)
      %{
        "message" => %{
          "role" => "agent",
          "parts" => [%{"data" => ..., "metadata" => %{"mimeType" => ...}}]
        }
      }
  """
  @spec build_server_message(a2ui_envelope()) :: a2a_message()
  def build_server_message(envelope) do
    %{
      "message" => %{
        "role" => Protocol.server_role(),
        "parts" => [wrap_envelope(envelope)]
      }
    }
  end

  # ============================================
  # Message Extraction
  # ============================================

  @doc """
  Extracts A2UI envelopes from an A2A message.

  Filters message parts to those with A2UI mimeType and returns their data.

  ## Example

      iex> msg = %{"message" => %{"parts" => [%{"data" => %{"userAction" => %{}}, "metadata" => %{"mimeType" => "application/json+a2ui"}}]}}
      iex> A2UI.A2A.DataPart.extract_envelopes(msg)
      [%{"userAction" => %{}}]
  """
  @spec extract_envelopes(a2a_message()) :: [a2ui_envelope()]
  def extract_envelopes(%{"message" => %{"parts" => parts}}) when is_list(parts) do
    parts
    |> Enum.filter(&a2ui_data_part?/1)
    |> Enum.map(fn part -> part["data"] end)
  end

  def extract_envelopes(_), do: []

  @doc """
  Extracts client capabilities from an A2A message metadata.

  Returns `{:ok, capabilities_map}` if found, or `:error` if not present.
  """
  @spec extract_client_capabilities(a2a_message()) :: {:ok, map()} | :error
  def extract_client_capabilities(%{"message" => %{"metadata" => metadata}}) do
    case Map.fetch(metadata, Protocol.client_capabilities_key()) do
      {:ok, caps} when is_map(caps) -> {:ok, caps}
      _ -> :error
    end
  end

  def extract_client_capabilities(_), do: :error

  @doc """
  Parses client capabilities from A2A message metadata into a ClientCapabilities struct.

  Returns `{:ok, capabilities}` on success or `{:error, reason}` on failure.
  """
  @spec parse_client_capabilities(a2a_message()) ::
          {:ok, ClientCapabilities.t()} | {:error, atom()}
  def parse_client_capabilities(message) do
    case extract_client_capabilities(message) do
      {:ok, caps_map} ->
        capabilities =
          ClientCapabilities.new(
            supported_catalog_ids: caps_map["supportedCatalogIds"] || [],
            inline_catalogs: caps_map["inlineCatalogs"] || []
          )

        {:ok, capabilities}

      :error ->
        {:error, :missing_client_capabilities}
    end
  end
end
