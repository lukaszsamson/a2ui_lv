defmodule A2uiLvWeb.DemoLive do
  @moduledoc """
  Demo LiveView for A2UI renderer.

  Shows a sample contact form rendered via A2UI protocol.
  """

  use A2uiLvWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket = A2UI.Live.init(socket, action_callback: &handle_action/2)
    socket = Phoenix.Component.assign(socket, :current_scope, nil)

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
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight text-zinc-950 dark:text-zinc-50 sm:text-3xl">
            A2UI LiveView Renderer Demo
          </h1>
          <p class="mt-2 max-w-2xl text-sm leading-6 text-zinc-700 dark:text-zinc-200">
            This page ingests a small A2UI v0.8 message sequence and renders it as LiveView components.
            Use the form to validate two-way binding and button actions.
          </p>
        </div>

        <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <%!-- Rendered Surface --%>
          <section class="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
            <h2 class="text-sm font-semibold text-zinc-950 dark:text-zinc-50">Rendered Surface</h2>
            <div class="mt-4 min-h-[420px]">
              <%= for {_id, surface} <- @a2ui_surfaces do %>
                <A2UI.Renderer.surface surface={surface} />
              <% end %>

              <%= if map_size(@a2ui_surfaces) == 0 do %>
                <div class="flex items-center justify-center gap-3 py-16 text-sm text-zinc-600 dark:text-zinc-300">
                  <div class="size-5 animate-spin rounded-full border-2 border-zinc-300 border-t-zinc-700 dark:border-zinc-700 dark:border-t-zinc-200" />
                  Loading surface…
                </div>
              <% end %>
            </div>
          </section>

          <%!-- Debug Panel --%>
          <section class="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
            <h2 class="text-sm font-semibold text-zinc-950 dark:text-zinc-50">Debug</h2>
            <div class="mt-4 space-y-4 overflow-auto rounded-xl border border-zinc-200 bg-zinc-50 p-4 text-xs leading-5 text-zinc-900 dark:border-zinc-800 dark:bg-zinc-950 dark:text-zinc-50">
              <%= if @a2ui_last_action do %>
                <div>
                  <div class="mb-2 text-[11px] font-semibold uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
                    Last Action
                  </div>
                  <pre class="whitespace-pre-wrap"><%= Jason.encode!(@a2ui_last_action, pretty: true) %></pre>
                </div>
              <% end %>

              <%= for {id, surface} <- @a2ui_surfaces do %>
                <div>
                  <div class="mb-2 text-[11px] font-semibold uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
                    Data Model ({id})
                  </div>
                  <pre class="whitespace-pre-wrap"><%= Jason.encode!(surface.data_model, pretty: true) %></pre>
                </div>
              <% end %>

              <%= if map_size(@a2ui_surfaces) == 0 and is_nil(@a2ui_last_action) do %>
                <div class="text-zinc-500 dark:text-zinc-400">Waiting for data…</div>
              <% end %>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp handle_action(user_action, _socket) do
    require Logger
    Logger.info("User action: #{inspect(user_action)}")
    # In a real app, send to agent here
  end
end
