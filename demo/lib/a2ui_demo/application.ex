defmodule A2UIDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      A2UIDemoWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:a2ui_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: A2UIDemo.PubSub},
      # A2UI Catalog Registry - must start before web endpoints
      # Registers all known v0.8 standard catalog ID aliases
      {A2UI.Catalog.Registry,
       catalogs:
         A2UI.V0_8.standard_catalog_ids()
         |> Map.new(fn id -> {id, A2UI.Phoenix.Catalog.Standard} end)},
      # HTTP+SSE Transport Registry for external agents
      {A2UI.Transport.HTTP.Registry, pubsub: A2UIDemo.PubSub},
      # Claude Agent SDK bridge client (ZMQ DEALER)
      A2UIDemo.Demo.ClaudeClient,
      # Claude Agent SDK HTTP bridge client (alternative to ZMQ)
      A2UIDemo.Demo.ClaudeHTTPClient,
      # Claude Agent SDK A2A bridge client (full A2A protocol)
      A2UIDemo.Demo.A2AClient,
      # Start to serve requests, typically the last entry
      A2UIDemoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: A2UIDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    A2UIDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
