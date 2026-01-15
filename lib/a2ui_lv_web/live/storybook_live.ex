defmodule A2uiLvWeb.StorybookLive do
  @moduledoc """
  Storybook LiveView for browsing all A2UI v0.8 standard catalog components.

  Displays examples of all 18 components with various configurations.
  """

  use A2uiLvWeb, :live_view

  alias A2uiLv.Demo.StorybookSamples

  @impl true
  def mount(_params, _session, socket) do
    socket =
      A2UI.Phoenix.Live.init(socket,
        action_callback: &handle_action/2,
        error_callback: &handle_error/2
      )

    socket = Phoenix.Component.assign(socket, :current_scope, nil)

    samples = StorybookSamples.all_samples()
    categories = samples |> Enum.map(fn {cat, _, _, _} -> cat end) |> Enum.uniq()

    # Group samples by category
    grouped =
      Enum.group_by(samples, fn {cat, _, _, _} -> cat end, fn {_, title, sid, _} ->
        {title, sid}
      end)

    socket =
      assign(socket,
        samples: samples,
        categories: categories,
        grouped_samples: grouped,
        selected_category: List.first(categories),
        selected_sample: nil,
        show_json: false,
        show_data_model: true
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"sample" => sample_id}, _uri, socket) do
    case Enum.find(socket.assigns.samples, fn {_, _, sid, _} -> sid == sample_id end) do
      {category, _title, ^sample_id, _messages} ->
        socket =
          socket
          |> assign(selected_sample: sample_id, selected_category: category)
          |> load_sample(sample_id)

        {:noreply, socket}

      nil ->
        {:noreply, push_patch(socket, to: ~p"/storybook")}
    end
  end

  def handle_params(_params, _uri, socket) do
    # Load first sample by default
    first_sample =
      case socket.assigns.samples do
        [{_, _, sid, _} | _] -> sid
        _ -> nil
      end

    if first_sample do
      {:noreply, push_patch(socket, to: ~p"/storybook?sample=#{first_sample}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_category", %{"category" => category}, socket) do
    # Find first sample in category
    first_in_category =
      case socket.assigns.grouped_samples[category] do
        [{_, sid} | _] -> sid
        _ -> nil
      end

    if first_in_category do
      {:noreply, push_patch(socket, to: ~p"/storybook?sample=#{first_in_category}")}
    else
      {:noreply, assign(socket, selected_category: category)}
    end
  end

  def handle_event("select_sample", %{"sample" => sample_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/storybook?sample=#{sample_id}")}
  end

  def handle_event("toggle_json", _, socket) do
    {:noreply, assign(socket, show_json: !socket.assigns.show_json)}
  end

  def handle_event("toggle_data_model", _, socket) do
    {:noreply, assign(socket, show_data_model: !socket.assigns.show_data_model)}
  end

  @impl true
  def handle_event("a2ui:" <> _ = event, params, socket) do
    A2UI.Phoenix.Live.handle_a2ui_event(event, params, socket)
  end

  @impl true
  def handle_info({:a2ui, _} = msg, socket) do
    A2UI.Phoenix.Live.handle_a2ui_message(msg, socket)
  end

  defp load_sample(socket, sample_id) do
    # Clear existing surfaces
    socket = Phoenix.Component.assign(socket, :a2ui_surfaces, %{})

    # Send sample messages
    StorybookSamples.send_sample(self(), sample_id)

    socket
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex min-h-[calc(100vh-8rem)]">
        <%!-- Sidebar --%>
        <aside class="w-64 shrink-0 border-r border-zinc-200 bg-zinc-50 dark:border-zinc-800 dark:bg-zinc-950">
          <div class="sticky top-0 h-[calc(100vh-8rem)] overflow-y-auto p-4">
            <h2 class="mb-4 text-lg font-semibold text-zinc-950 dark:text-zinc-50">
              A2UI Components
            </h2>

            <nav class="space-y-4">
              <%= for category <- @categories do %>
                <div>
                  <button
                    phx-click="select_category"
                    phx-value-category={category}
                    class={[
                      "mb-2 w-full text-left text-xs font-semibold uppercase tracking-wide",
                      if(@selected_category == category,
                        do: "text-indigo-600 dark:text-indigo-400",
                        else: "text-zinc-500 dark:text-zinc-400"
                      )
                    ]}
                  >
                    {category}
                  </button>

                  <ul class="space-y-1">
                    <%= for {title, sid} <- @grouped_samples[category] || [] do %>
                      <li>
                        <button
                          phx-click="select_sample"
                          phx-value-sample={sid}
                          class={[
                            "block w-full rounded-lg px-3 py-1.5 text-left text-sm transition-colors",
                            if(@selected_sample == sid,
                              do:
                                "bg-indigo-100 text-indigo-900 dark:bg-indigo-900/30 dark:text-indigo-100",
                              else:
                                "text-zinc-700 hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-zinc-800"
                            )
                          ]}
                        >
                          {title}
                        </button>
                      </li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
            </nav>
          </div>
        </aside>

        <%!-- Main Content --%>
        <main class="flex-1 p-6">
          <%= if @selected_sample do %>
            <% {_cat, title, _sid, messages} =
              Enum.find(@samples, fn {_, _, sid, _} -> sid == @selected_sample end) %>

            <div class="mb-6 flex items-center justify-between">
              <h1 class="text-2xl font-semibold text-zinc-950 dark:text-zinc-50">
                {title}
              </h1>
              <div class="flex gap-2">
                <button
                  phx-click="toggle_data_model"
                  class={[
                    "rounded-lg px-3 py-1.5 text-sm font-medium transition-colors ring-1 ring-inset",
                    if(@show_data_model,
                      do:
                        "bg-indigo-50 text-indigo-700 ring-indigo-200 hover:bg-indigo-100 dark:bg-indigo-900/30 dark:text-indigo-300 dark:ring-indigo-800",
                      else:
                        "text-zinc-600 ring-zinc-200 hover:bg-zinc-50 dark:text-zinc-400 dark:ring-zinc-700 dark:hover:bg-zinc-800"
                    )
                  ]}
                >
                  {if @show_data_model, do: "Hide Data", else: "Show Data"}
                </button>
                <button
                  phx-click="toggle_json"
                  class={[
                    "rounded-lg px-3 py-1.5 text-sm font-medium transition-colors ring-1 ring-inset",
                    if(@show_json,
                      do:
                        "bg-indigo-50 text-indigo-700 ring-indigo-200 hover:bg-indigo-100 dark:bg-indigo-900/30 dark:text-indigo-300 dark:ring-indigo-800",
                      else:
                        "text-zinc-600 ring-zinc-200 hover:bg-zinc-50 dark:text-zinc-400 dark:ring-zinc-700 dark:hover:bg-zinc-800"
                    )
                  ]}
                >
                  {if @show_json, do: "Hide JSON", else: "Show JSON"}
                </button>
              </div>
            </div>

            <div class={[
              "grid gap-6",
              if(@show_data_model, do: "grid-cols-1 xl:grid-cols-2", else: "grid-cols-1")
            ]}>
              <%!-- Component Preview --%>
              <section class="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
                <h2 class="mb-4 text-sm font-semibold text-zinc-950 dark:text-zinc-50">
                  Preview
                </h2>
                <div class="min-h-[200px]">
                  <%= for {_id, surface} <- @a2ui_surfaces do %>
                    <A2UI.Phoenix.Renderer.surface surface={surface} />
                  <% end %>

                  <%= if map_size(@a2ui_surfaces) == 0 do %>
                    <div class="flex items-center justify-center gap-3 py-16 text-sm text-zinc-600 dark:text-zinc-300">
                      <div class="size-5 animate-spin rounded-full border-2 border-zinc-300 border-t-zinc-700 dark:border-zinc-700 dark:border-t-zinc-200" />
                      Loading…
                    </div>
                  <% end %>
                </div>
              </section>

              <%!-- Data Model / Debug --%>
              <section
                :if={@show_data_model}
                class="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-950"
              >
                <h2 class="mb-4 text-sm font-semibold text-zinc-950 dark:text-zinc-50">
                  Data Model
                </h2>
                <div class="overflow-auto rounded-xl border border-zinc-200 bg-zinc-50 p-4 text-xs leading-5 text-zinc-900 dark:border-zinc-800 dark:bg-zinc-950 dark:text-zinc-50">
                  <%= if @a2ui_last_error do %>
                    <div class="mb-4">
                      <div class="mb-2 text-[11px] font-semibold uppercase tracking-wide text-rose-500 dark:text-rose-400">
                        Last Error
                      </div>
                      <pre class="whitespace-pre-wrap text-rose-600 dark:text-rose-400"><%= Jason.encode!(@a2ui_last_error, pretty: true, escape: :html_safe) %></pre>
                    </div>
                  <% end %>

                  <%= if @a2ui_last_action do %>
                    <div class="mb-4">
                      <div class="mb-2 text-[11px] font-semibold uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
                        Last Action
                      </div>
                      <pre class="whitespace-pre-wrap"><%= Jason.encode!(@a2ui_last_action, pretty: true, escape: :html_safe) %></pre>
                    </div>
                  <% end %>

                  <%= for {id, surface} <- @a2ui_surfaces do %>
                    <div>
                      <div class="mb-2 text-[11px] font-semibold uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
                        Surface: {id}
                      </div>
                      <pre class="whitespace-pre-wrap"><%= Jason.encode!(surface.data_model, pretty: true, escape: :html_safe) %></pre>
                    </div>
                  <% end %>

                  <%= if map_size(@a2ui_surfaces) == 0 do %>
                    <div class="text-zinc-500 dark:text-zinc-400">No data yet…</div>
                  <% end %>
                </div>
              </section>
            </div>

            <%!-- JSON Messages --%>
            <%= if @show_json do %>
              <section class="mt-6 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
                <h2 class="mb-4 text-sm font-semibold text-zinc-950 dark:text-zinc-50">
                  A2UI JSONL Messages
                </h2>
                <div class="space-y-2 overflow-auto rounded-xl border border-zinc-200 bg-zinc-900 p-4 text-xs leading-5 text-green-400">
                  <%= for msg <- messages do %>
                    <pre class="whitespace-pre-wrap"><%= format_json(msg) %></pre>
                  <% end %>
                </div>
              </section>
            <% end %>
          <% else %>
            <div class="flex h-64 items-center justify-center text-zinc-500 dark:text-zinc-400">
              Select a component from the sidebar
            </div>
          <% end %>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp format_json(json_string) do
    case Jason.decode(json_string) do
      {:ok, decoded} -> Jason.encode!(decoded, pretty: true, escape: :html_safe)
      {:error, _} -> json_string
    end
  end

  defp handle_action(user_action, _socket) do
    require Logger
    Logger.info("Storybook action: #{inspect(user_action)}")
  end

  defp handle_error(error, _socket) do
    require Logger
    Logger.warning("Storybook error: #{inspect(error)}")
  end
end
