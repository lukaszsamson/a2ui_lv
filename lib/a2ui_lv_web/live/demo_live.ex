defmodule A2uiLvWeb.DemoLive do
  @moduledoc """
  Demo LiveView for A2UI renderer.

  Shows a sample contact form rendered via A2UI protocol.
  """

  use A2uiLvWeb, :live_view

  alias A2uiLvWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    socket = A2UI.Live.init(socket, action_callback: &handle_action/2)

    if connected?(socket) do
      send(self(), :load_demo)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_demo, socket) do
    # Send mock A2UI messages
    A2UI.MockAgent.send_sample_form(self())
    {:noreply, socket}
  end

  @impl true
  def handle_info({:a2ui, _} = msg, socket) do
    A2UI.Live.handle_a2ui_message(msg, socket)
  end

  @impl true
  def handle_event("a2ui:" <> _ = event, params, socket) do
    A2UI.Live.handle_a2ui_event(event, params, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <header class="navbar bg-base-100 shadow-sm px-4 sm:px-6 lg:px-8">
        <div class="flex-1">
          <a href="/" class="btn btn-ghost text-xl">A2UI Demo</a>
        </div>
        <div class="flex-none">
          <a href="/" class="btn btn-sm btn-outline">Back to Home</a>
        </div>
      </header>

      <main class="container mx-auto px-4 py-8 max-w-6xl">
        <h1 class="text-3xl font-bold mb-8">A2UI LiveView Renderer</h1>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <%!-- Rendered Surface --%>
          <div>
            <h2 class="text-lg font-semibold mb-4">Rendered Surface</h2>
            <div class="bg-base-100 rounded-lg shadow p-6 border border-base-300 min-h-[400px]">
              <%= for {_id, surface} <- @a2ui_surfaces do %>
                <A2UI.Renderer.surface surface={surface} />
              <% end %>

              <%= if map_size(@a2ui_surfaces) == 0 do %>
                <div class="text-base-content/50 text-center py-8">
                  <span class="loading loading-spinner loading-md mr-2"></span>
                  Loading surface...
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Debug Panel --%>
          <div>
            <h2 class="text-lg font-semibold mb-4">Debug Info</h2>
            <div class="bg-neutral rounded-lg shadow p-4 text-sm font-mono text-neutral-content overflow-auto max-h-[600px]">
              <%= if @a2ui_last_action do %>
                <div class="mb-4">
                  <div class="text-success mb-1">Last Action:</div>
                  <pre class="text-neutral-content/80 whitespace-pre-wrap"><%= Jason.encode!(@a2ui_last_action, pretty: true) %></pre>
                </div>
              <% end %>

              <%= for {id, surface} <- @a2ui_surfaces do %>
                <div class="mb-4">
                  <div class="text-info mb-1">Data Model (<%= id %>):</div>
                  <pre class="text-neutral-content/80 whitespace-pre-wrap"><%= Jason.encode!(surface.data_model, pretty: true) %></pre>
                </div>
              <% end %>

              <%= if map_size(@a2ui_surfaces) == 0 and is_nil(@a2ui_last_action) do %>
                <div class="text-neutral-content/50">Waiting for data...</div>
              <% end %>
            </div>
          </div>
        </div>
      </main>

      <Layouts.flash_group flash={@flash} />
    </div>
    """
  end

  defp handle_action(user_action, _socket) do
    require Logger
    Logger.info("User action: #{inspect(user_action)}")
    # In a real app, send to agent here
  end
end
