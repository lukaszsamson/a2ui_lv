defmodule A2uiLv.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      A2uiLvWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:a2ui_lv, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: A2uiLv.PubSub},
      # A2UI Catalog Registry - must start before web endpoints
      {A2UI.Catalog.Registry,
       catalogs: %{
         A2UI.V0_8.standard_catalog_id() => A2UI.Phoenix.Catalog.Standard
       }},
      # Claude Agent SDK bridge client (ZMQ DEALER)
      A2uiLv.Demo.ClaudeClient,
      # Start to serve requests, typically the last entry
      A2uiLvWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: A2uiLv.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    A2uiLvWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
