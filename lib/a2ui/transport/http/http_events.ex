defmodule A2UI.Transport.HTTP.HTTPEvents do
  @moduledoc """
  HTTP POST client for sending A2UI events.

  Implements `A2UI.Transport.Events` behavior using HTTP POST requests.
  Uses the `req` library for HTTP communication.

  ## Requirements

  This module requires the `req` library. Add to your `mix.exs`:

      {:req, "~> 0.5"}

  ## Usage

      # Start the client
      {:ok, events} = A2UI.Transport.HTTP.HTTPEvents.start_link(
        base_url: "http://localhost:4000/a2ui",
        session_id: "abc123"
      )

      # Send an event
      event = %{
        "userAction" => %{
          "name" => "submit",
          "surfaceId" => "main",
          "sourceComponentId" => "submit_btn",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "context" => %{}
        }
      }

      :ok = A2UI.Transport.HTTP.HTTPEvents.send_event(events, event, [])

  ## Options

  - `:base_url` - Required. Base URL of the HTTP transport endpoint
  - `:session_id` - Required. Session ID for the events
  - `:capabilities` - Client capabilities (default: `A2UI.ClientCapabilities.default()`)
  - `:req_options` - Additional options for Req
  """

  @behaviour A2UI.Transport.Events

  use GenServer
  require Logger

  alias A2UI.A2A.DataPart
  alias A2UI.ClientCapabilities

  defstruct [
    :base_url,
    :session_id,
    :capabilities,
    :req_options
  ]

  # Check if Req is available at compile time
  @req_available Code.ensure_loaded?(Req)

  # ============================================
  # Client API
  # ============================================

  @doc """
  Starts the HTTP events client.

  ## Options

  - `:base_url` - Required. Base URL of the HTTP transport
  - `:session_id` - Required. Session ID for the events
  - `:capabilities` - Client capabilities (default: `ClientCapabilities.default()`)
  - `:req_options` - Additional Req options (default: [])
  - `:name` - Process name
  """
  if @req_available do
    def start_link(opts) do
      name = Keyword.get(opts, :name)
      gen_opts = if name, do: [name: name], else: []
      GenServer.start_link(__MODULE__, opts, gen_opts)
    end
  else
    def start_link(_opts) do
      A2UI.Transport.HTTP.missing_dependency_error()
    end
  end

  @doc """
  Sends an event envelope to the server via HTTP POST.

  ## Options

  - `:timeout` - Request timeout in milliseconds (default: 5000)
  - `:data_broadcast` - Data model broadcast payload for A2A transport
  """
  @impl A2UI.Transport.Events
  def send_event(pid, event_envelope, opts \\ []) do
    GenServer.call(pid, {:send_event, event_envelope, opts})
  end

  # ============================================
  # GenServer Callbacks
  # ============================================

  if @req_available do
    @impl true
    def init(opts) do
      base_url = Keyword.fetch!(opts, :base_url)
      session_id = Keyword.fetch!(opts, :session_id)
      capabilities = Keyword.get(opts, :capabilities, ClientCapabilities.default())
      req_options = Keyword.get(opts, :req_options, [])

      state = %__MODULE__{
        base_url: base_url,
        session_id: session_id,
        capabilities: capabilities,
        req_options: req_options
      }

      {:ok, state}
    end

    @impl true
    def handle_call({:send_event, event_envelope, opts}, _from, state) do
      result = do_send_event(state, event_envelope, opts)
      {:reply, result, state}
    end

    # ============================================
    # Private Functions
    # ============================================

    defp do_send_event(state, event_envelope, opts) do
      # Validate the envelope
      case A2UI.Transport.Events.validate_envelope(event_envelope) do
        :ok ->
          post_event(state, event_envelope, opts)

        {:error, _} = error ->
          error
      end
    end

    defp post_event(state, event_envelope, opts) do
      url = build_events_url(state)
      timeout = Keyword.get(opts, :timeout, 5_000)

      # Build A2A message with capabilities
      a2a_message = DataPart.build_client_message(event_envelope, state.capabilities)

      # Add data broadcast if present
      a2a_message =
        case Keyword.get(opts, :data_broadcast) do
          nil ->
            a2a_message

          broadcast ->
            put_in(
              a2a_message,
              ["message", "metadata", "a2uiDataBroadcast"],
              broadcast
            )
        end

      body = %{
        "sessionId" => state.session_id,
        "event" => a2a_message
      }

      req_opts =
        Keyword.merge(
          [
            json: body,
            receive_timeout: timeout
          ],
          state.req_options
        )

      case Req.post(url, req_opts) do
        {:ok, %Req.Response{status: status}} when status in 200..299 ->
          :ok

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error("HTTP events POST failed: status=#{status}, body=#{inspect(body)}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          Logger.error("HTTP events POST error: #{inspect(reason)}")
          {:error, reason}
      end
    end

    defp build_events_url(state) do
      uri =
        state.base_url
        |> URI.parse()
        |> Map.update!(:path, fn
          nil -> "/events"
          path -> String.trim_trailing(path, "/") <> "/events"
        end)

      URI.to_string(uri)
    end
  else
    @impl true
    def init(_opts) do
      {:stop, {:missing_dependency, :req}}
    end
  end
end
