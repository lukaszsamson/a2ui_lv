defmodule A2UIDemoWeb.DemoLive do
  @moduledoc """
  Demo LiveView showcasing all A2UI v0.8 communication scenarios.

  Demonstrates:
  - surfaceUpdate: Component definitions
  - dataModelUpdate: Data model updates (root and path-based)
  - beginRendering: Initial render signal
  - deleteSurface: Surface removal
  - userAction: User interactions with context resolution
  - error: Client-side error reporting
  - Multiple surfaces: Independent UI regions
  - Progressive rendering: Streaming component updates
  - Template lists: Dynamic list rendering with data binding
  """

  use A2UIDemoWeb, :live_view

  @scenarios [
    {"basic", "Basic Form", "Initial render with surfaceUpdate, dataModelUpdate, beginRendering"},
    {"dynamic", "Dynamic Updates", "UI changes in response to userAction"},
    {"multi_surface", "Multiple Surfaces", "Independent UI regions with separate data models"},
    {"delete_surface", "Delete Surface", "Removing surfaces from the UI"},
    {"streaming", "Progressive Streaming", "Components added incrementally"},
    {"template_list", "Template Lists", "Dynamic list rendering with add/remove"},
    {"data_binding", "Data Binding", "Literal, path, and path+literal binding modes"},
    {"error_handling", "Error Handling", "Client-side error reporting"},
    {"llm_agent", "LLM Agent", "User prompt → Ollama LLM → A2UI JSON → Rendered UI"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      A2UI.Phoenix.Live.init(socket,
        action_callback: &handle_action/2,
        error_callback: &handle_error/2
      )

    # Get available models from Ollama
    available_models =
      case A2UIDemo.Demo.OllamaClient.list_available_models() do
        {:ok, models} -> models
        {:error, _} -> []
      end

    # Check Claude bridge availability (both ZMQ and HTTP)
    claude_zmq_available = A2UIDemo.Demo.ClaudeClient.available?()
    claude_http_available = A2UIDemo.Demo.ClaudeHTTPClient.available?()

    socket =
      Phoenix.Component.assign(socket,
        current_scope: nil,
        scenarios: @scenarios,
        active_scenario: nil,
        action_log: [],
        error_log: [],
        # LLM Agent state
        llm_prompt: "",
        llm_original_prompt: nil,
        llm_loading: false,
        llm_error: nil,
        llm_provider:
          cond do
            claude_http_available -> "claude_http"
            claude_zmq_available -> "claude"
            true -> "ollama"
          end,
        llm_model: "gpt-oss:latest",
        llm_available_models: available_models,
        llm_use_streaming: false,
        llm_force_schema: nil,
        claude_zmq_available: claude_zmq_available,
        claude_http_available: claude_http_available,
        # Keep claude_available for backwards compatibility
        claude_available: claude_zmq_available or claude_http_available
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"scenario" => scenario_key}, _uri, socket) do
    if Enum.any?(@scenarios, fn {key, _, _} -> key == scenario_key end) do
      socket =
        socket
        |> assign(active_scenario: scenario_key)
        |> clear_surfaces()
        |> load_scenario(scenario_key)

      {:noreply, socket}
    else
      {:noreply, push_patch(socket, to: ~p"/demo?scenario=basic")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, push_patch(socket, to: ~p"/demo?scenario=basic")}
  end

  @impl true
  def handle_info({:a2ui, _} = msg, socket) do
    A2UI.Phoenix.Live.handle_a2ui_message(msg, socket)
  end

  # Delayed message sending for streaming demo
  def handle_info({:send_delayed, json, delay_after}, socket) do
    send(self(), {:a2ui, json})

    if delay_after do
      Process.send_after(self(), delay_after, 300)
    end

    {:noreply, socket}
  end

  # Dynamic update responses
  def handle_info({:respond_to_action, action_name, surface_id}, socket) do
    socket = respond_to_action(socket, action_name, surface_id)
    {:noreply, socket}
  end

  # LLM response handler
  def handle_info({:llm_response, {:ok, messages}}, socket) do
    require Logger
    Logger.info("LLM generated #{length(messages)} A2UI messages")

    # Send each message to be processed by A2UI
    for json <- messages do
      send(self(), {:a2ui, json})
    end

    socket = assign(socket, llm_loading: false, llm_error: nil)
    {:noreply, socket}
  end

  def handle_info({:llm_response, {:error, reason}}, socket) do
    require Logger
    Logger.error("LLM generation failed: #{inspect(reason)}")
    socket = assign(socket, llm_loading: false, llm_error: format_llm_error(reason))
    {:noreply, socket}
  end

  # Claude generation streams A2UI messages via `on_message`, so the completion
  # notification must not re-send them (avoids duplicates).
  def handle_info({:llm_done, {:ok, _messages}}, socket) do
    {:noreply, assign(socket, llm_loading: false, llm_error: nil)}
  end

  def handle_info({:llm_done, {:error, reason}}, socket) do
    {:noreply, assign(socket, llm_loading: false, llm_error: format_llm_error(reason))}
  end

  # Ollama streaming currently uses `on_chunk` for token streaming; the demo UI
  # doesn't render partial tokens yet, but we must handle the message to avoid crashes.
  def handle_info({:llm_chunk, _chunk}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_scenario", %{"scenario" => scenario}, socket) do
    {:noreply, push_patch(socket, to: ~p"/demo?scenario=#{scenario}")}
  end

  def handle_event("clear_logs", _, socket) do
    {:noreply, assign(socket, action_log: [], error_log: [])}
  end

  def handle_event("trigger_error", %{"type" => type}, socket) do
    # Trigger various error types for demonstration
    case type do
      "parse" ->
        send(self(), {:a2ui, "not valid json {"})

      "unknown_type" ->
        send(self(), {:a2ui, ~s({"unknownMessageType": {}})})

      "unknown_component" ->
        send(
          self(),
          {:a2ui,
           ~s({"surfaceUpdate":{"surfaceId":"error-test","components":[{"id":"x","component":{"UnknownWidget":{}}}]}})}
        )

      "too_many_components" ->
        # Generate 1001 components to trigger limit
        components =
          1..1001
          |> Enum.map(fn i ->
            ~s({"id":"c#{i}","component":{"Text":{"text":{"literalString":"text"}}}})
          end)
          |> Enum.join(",")

        send(
          self(),
          {:a2ui, ~s({"surfaceUpdate":{"surfaceId":"error-test","components":[#{components}]}})}
        )
    end

    {:noreply, socket}
  end

  # Add item to template list
  def handle_event("add_list_item", _, socket) do
    surface = socket.assigns.a2ui_surfaces["template-list"]

    if surface do
      # Products are stored as a map with string keys ("0", "1", "2", etc.)
      products = get_in(surface.data_model, ["products"]) || %{}
      new_index = map_size(products)

      new_item_json =
        ~s({"dataModelUpdate":{"surfaceId":"template-list","path":"/products/#{new_index}","contents":[{"key":"name","valueString":"New Product #{new_index + 1}"},{"key":"price","valueString":"$#{:rand.uniform(100)}.99"},{"key":"id","valueString":"prod-#{new_index}"}]}})

      send(self(), {:a2ui, new_item_json})
    end

    {:noreply, socket}
  end

  # Remove item from template list
  def handle_event("remove_list_item", _, socket) do
    surface = socket.assigns.a2ui_surfaces["template-list"]

    if surface do
      products = get_in(surface.data_model, ["products"]) || %{}
      count = map_size(products)

      if count > 0 do
        # Remove last item by deleting the highest index key
        last_key = Integer.to_string(count - 1)
        new_products = Map.delete(products, last_key)

        new_data_model = put_in(surface.data_model, ["products"], new_products)

        surfaces =
          Map.put(socket.assigns.a2ui_surfaces, "template-list", %{
            surface
            | data_model: new_data_model
          })

        socket = Phoenix.Component.assign(socket, :a2ui_surfaces, surfaces)
        {:noreply, socket}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Add another surface
  def handle_event("add_surface", _, socket) do
    surface_id = "surface-#{System.unique_integer([:positive])}"
    send_additional_surface(self(), surface_id)
    {:noreply, socket}
  end

  # LLM Agent - update prompt text
  def handle_event("llm_prompt_change", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, llm_prompt: prompt)}
  end

  # LLM Agent - change provider (Claude or Ollama)
  def handle_event("llm_provider_change", %{"provider" => provider}, socket) do
    {:noreply, assign(socket, llm_provider: provider)}
  end

  # LLM Agent - change model
  def handle_event("llm_model_change", %{"model" => model}, socket) do
    {:noreply, assign(socket, llm_model: model)}
  end

  # LLM Agent - toggle streaming
  def handle_event("llm_toggle_streaming", _, socket) do
    {:noreply, assign(socket, llm_use_streaming: !socket.assigns.llm_use_streaming)}
  end

  # LLM Agent - cycle schema forcing (nil -> true -> false -> nil)
  def handle_event("llm_cycle_schema", _, socket) do
    new_value =
      case socket.assigns.llm_force_schema do
        nil -> true
        true -> false
        false -> nil
      end

    {:noreply, assign(socket, llm_force_schema: new_value)}
  end

  # LLM Agent - submit prompt
  def handle_event("llm_submit", _, socket) do
    prompt = socket.assigns.llm_prompt

    if prompt != "" and not socket.assigns.llm_loading do
      # Save the original prompt for later action handling
      socket = assign(socket, llm_loading: true, llm_error: nil, llm_original_prompt: prompt)
      pid = self()

      case socket.assigns.llm_provider do
        "claude" ->
          # Use Claude Agent SDK via ZMQ bridge
          # Claude can take 5+ minutes for complex queries with web search
          Task.start(fn ->
            result =
              A2UIDemo.Demo.ClaudeClient.generate(prompt,
                surface_id: "llm-surface",
                on_message: fn msg -> send(pid, {:a2ui, msg}) end,
                # 5 minutes
                timeout: 300_000
              )

            send(pid, {:llm_done, result})
          end)

        "claude_http" ->
          # Use Claude Agent SDK via HTTP+SSE bridge
          Task.start(fn ->
            result =
              A2UIDemo.Demo.ClaudeHTTPClient.generate(prompt,
                surface_id: "llm-surface",
                on_message: fn msg -> send(pid, {:a2ui, msg}) end,
                timeout: 300_000
              )

            send(pid, {:llm_done, result})
          end)

        _ollama ->
          opts = [
            model: socket.assigns.llm_model,
            surface_id: "llm-surface",
            stream: socket.assigns.llm_use_streaming,
            force_schema: socket.assigns.llm_force_schema
          ]

          # Add streaming callback if enabled
          opts =
            if socket.assigns.llm_use_streaming do
              Keyword.put(opts, :on_chunk, fn chunk ->
                send(pid, {:llm_chunk, chunk})
              end)
            else
              opts
            end

          Task.start(fn ->
            result = A2UIDemo.Demo.OllamaClient.generate(prompt, opts)
            send(pid, {:llm_response, result})
          end)
      end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Delete a specific surface
  def handle_event("delete_surface", %{"surface-id" => surface_id}, socket) do
    send(self(), {:a2ui, ~s({"deleteSurface":{"surfaceId":"#{surface_id}"}})})
    {:noreply, socket}
  end

  @impl true
  def handle_event("a2ui:" <> _ = event, params, socket) do
    A2UI.Phoenix.Live.handle_a2ui_event(event, params, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight text-zinc-950 dark:text-zinc-50 sm:text-3xl">
            A2UI v0.8 Communication Scenarios
          </h1>
          <p class="mt-2 max-w-3xl text-sm leading-6 text-zinc-700 dark:text-zinc-200">
            Interactive demonstration of all A2UI protocol message types and communication patterns.
          </p>
        </div>

        <%!-- Scenario Tabs --%>
        <nav class="flex flex-wrap gap-2 border-b border-zinc-200 pb-4 dark:border-zinc-800">
          <%= for {key, label, _desc} <- @scenarios do %>
            <button
              phx-click="select_scenario"
              phx-value-scenario={key}
              class={[
                "rounded-lg px-3 py-1.5 text-sm font-medium transition-colors",
                if(@active_scenario == key,
                  do: "bg-indigo-600 text-white shadow-sm",
                  else: "text-zinc-700 hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-zinc-800"
                )
              ]}
            >
              {label}
            </button>
          <% end %>
        </nav>

        <%!-- Scenario Description --%>
        <%= for {key, label, desc} <- @scenarios, key == @active_scenario do %>
          <div class="rounded-xl bg-indigo-50 p-4 dark:bg-indigo-950/30">
            <h2 class="font-semibold text-indigo-900 dark:text-indigo-100">{label}</h2>
            <p class="mt-1 text-sm text-indigo-700 dark:text-indigo-300">{desc}</p>
          </div>
        <% end %>

        <%!-- Scenario Controls --%>
        <.scenario_controls
          scenario={@active_scenario}
          surfaces={@a2ui_surfaces}
          llm_prompt={@llm_prompt}
          llm_loading={@llm_loading}
          llm_error={@llm_error}
          llm_provider={@llm_provider}
          llm_model={@llm_model}
          llm_available_models={@llm_available_models}
          llm_use_streaming={@llm_use_streaming}
          llm_force_schema={@llm_force_schema}
          claude_available={@claude_available}
          claude_zmq_available={@claude_zmq_available}
          claude_http_available={@claude_http_available}
        />

        <div class="grid grid-cols-1 gap-6 xl:grid-cols-2">
          <%!-- Rendered Surfaces --%>
          <section class="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
            <h2 class="mb-4 text-sm font-semibold text-zinc-950 dark:text-zinc-50">
              Rendered Surfaces ({map_size(@a2ui_surfaces)})
            </h2>
            <div class="space-y-4">
              <%= if map_size(@a2ui_surfaces) == 0 do %>
                <div class="flex items-center justify-center gap-3 py-16 text-sm text-zinc-600 dark:text-zinc-300">
                  <div class="size-5 animate-spin rounded-full border-2 border-zinc-300 border-t-zinc-700 dark:border-zinc-700 dark:border-t-zinc-200" />
                  Loading surfaces…
                </div>
              <% else %>
                <%= for {id, surface} <- @a2ui_surfaces do %>
                  <div class="rounded-xl border border-zinc-200 p-4 dark:border-zinc-700">
                    <div class="mb-3 flex items-center justify-between">
                      <span class="text-xs font-semibold uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
                        Surface: {id}
                      </span>
                      <%= if @active_scenario in ["multi_surface", "delete_surface"] do %>
                        <button
                          phx-click="delete_surface"
                          phx-value-surface-id={id}
                          class="rounded px-2 py-1 text-xs text-rose-600 hover:bg-rose-50 dark:text-rose-400 dark:hover:bg-rose-950/30"
                        >
                          Delete
                        </button>
                      <% end %>
                    </div>
                    <A2UI.Phoenix.Renderer.surface surface={surface} />
                  </div>
                <% end %>
              <% end %>
            </div>
          </section>

          <%!-- Debug Panel --%>
          <section class="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
            <div class="mb-4 flex items-center justify-between">
              <h2 class="text-sm font-semibold text-zinc-950 dark:text-zinc-50">Debug Panel</h2>
              <button
                phx-click="clear_logs"
                class="rounded px-2 py-1 text-xs text-zinc-600 hover:bg-zinc-100 dark:text-zinc-400 dark:hover:bg-zinc-800"
              >
                Clear Logs
              </button>
            </div>

            <div class="space-y-4 overflow-auto rounded-xl border border-zinc-200 bg-zinc-50 p-4 text-xs leading-5 dark:border-zinc-800 dark:bg-zinc-950">
              <%!-- Error Log --%>
              <%= if @a2ui_last_error do %>
                <div>
                  <div class="mb-2 text-[11px] font-semibold uppercase tracking-wide text-rose-500 dark:text-rose-400">
                    Last Error
                  </div>
                  <pre class="whitespace-pre-wrap text-rose-600 dark:text-rose-400"><%= Jason.encode!(@a2ui_last_error, pretty: true, escape: :html_safe) %></pre>
                </div>
              <% end %>

              <%!-- Action Log --%>
              <%= if @a2ui_last_action do %>
                <div>
                  <div class="mb-2 text-[11px] font-semibold uppercase tracking-wide text-emerald-600 dark:text-emerald-400">
                    Last userAction (Client → Server)
                  </div>
                  <pre class="whitespace-pre-wrap text-zinc-900 dark:text-zinc-50"><%= Jason.encode!(@a2ui_last_action, pretty: true, escape: :html_safe) %></pre>
                </div>
              <% end %>

              <%!-- Data Models --%>
              <%= for {id, surface} <- @a2ui_surfaces do %>
                <div>
                  <div class="mb-2 text-[11px] font-semibold uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
                    Data Model ({id})
                  </div>
                  <pre class="whitespace-pre-wrap text-zinc-900 dark:text-zinc-50"><%= Jason.encode!(surface.data_model, pretty: true, escape: :html_safe) %></pre>
                </div>
              <% end %>

              <%= if map_size(@a2ui_surfaces) == 0 and is_nil(@a2ui_last_action) and is_nil(@a2ui_last_error) do %>
                <div class="text-zinc-500 dark:text-zinc-400">Waiting for data…</div>
              <% end %>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Scenario-specific controls
  defp scenario_controls(%{scenario: "template_list"} = assigns) do
    ~H"""
    <div class="flex gap-2">
      <button
        phx-click="add_list_item"
        class="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-emerald-500"
      >
        + Add Item
      </button>
      <button
        phx-click="remove_list_item"
        class="rounded-lg bg-rose-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-rose-500"
      >
        − Remove Item
      </button>
    </div>
    """
  end

  defp scenario_controls(%{scenario: "multi_surface"} = assigns) do
    ~H"""
    <div class="flex gap-2">
      <button
        phx-click="add_surface"
        class="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-500"
      >
        + Add Surface
      </button>
      <span class="self-center text-sm text-zinc-500 dark:text-zinc-400">
        Each surface has its own data model and component tree
      </span>
    </div>
    """
  end

  defp scenario_controls(%{scenario: "delete_surface"} = assigns) do
    ~H"""
    <div class="text-sm text-zinc-600 dark:text-zinc-400">
      Click "Delete" on any surface to send a
      <code class="rounded bg-zinc-200 px-1 dark:bg-zinc-800">deleteSurface</code>
      message
    </div>
    """
  end

  defp scenario_controls(%{scenario: "error_handling"} = assigns) do
    ~H"""
    <div class="flex flex-wrap gap-2">
      <button
        phx-click="trigger_error"
        phx-value-type="parse"
        class="rounded-lg bg-rose-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-rose-500"
      >
        Trigger Parse Error
      </button>
      <button
        phx-click="trigger_error"
        phx-value-type="unknown_type"
        class="rounded-lg bg-rose-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-rose-500"
      >
        Unknown Message Type
      </button>
      <button
        phx-click="trigger_error"
        phx-value-type="unknown_component"
        class="rounded-lg bg-rose-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-rose-500"
      >
        Unknown Component
      </button>
      <button
        phx-click="trigger_error"
        phx-value-type="too_many_components"
        class="rounded-lg bg-rose-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-rose-500"
      >
        Too Many Components
      </button>
    </div>
    """
  end

  defp scenario_controls(%{scenario: "streaming"} = assigns) do
    ~H"""
    <div class="text-sm text-zinc-600 dark:text-zinc-400">
      Watch components appear progressively as
      <code class="rounded bg-zinc-200 px-1 dark:bg-zinc-800">surfaceUpdate</code>
      messages stream in
    </div>
    """
  end

  defp scenario_controls(%{scenario: "dynamic"} = assigns) do
    ~H"""
    <div class="text-sm text-zinc-600 dark:text-zinc-400">
      Click buttons to send <code class="rounded bg-zinc-200 px-1 dark:bg-zinc-800">userAction</code>
      messages and observe the server's response with updated UI
    </div>
    """
  end

  defp scenario_controls(%{scenario: "llm_agent"} = assigns) do
    ~H"""
    <div class="space-y-4">
      <%!-- Provider and Model Selection --%>
      <div class="flex flex-wrap items-center gap-4">
        <%!-- Provider Toggle --%>
        <form phx-change="llm_provider_change" class="flex items-center gap-2">
          <label class="text-sm font-medium text-zinc-700 dark:text-zinc-300">Provider:</label>
          <select
            name="provider"
            class="rounded-lg border border-zinc-300 bg-white px-3 py-1.5 text-sm focus:border-indigo-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-100"
            disabled={@llm_loading}
          >
            <option value="claude" selected={@llm_provider == "claude"}>
              Claude (ZMQ) {if @claude_zmq_available, do: "✓", else: "(unavailable)"}
            </option>
            <option value="claude_http" selected={@llm_provider == "claude_http"}>
              Claude (HTTP) {if @claude_http_available, do: "✓", else: "(unavailable)"}
            </option>
            <option value="ollama" selected={@llm_provider == "ollama"}>
              Ollama (local)
            </option>
          </select>
        </form>

        <%!-- Ollama-specific options --%>
        <%= if @llm_provider == "ollama" do %>
          <%!-- Model Dropdown --%>
          <form phx-change="llm_model_change" class="flex items-center gap-2">
            <label class="text-sm font-medium text-zinc-700 dark:text-zinc-300">Model:</label>
            <select
              name="model"
              class="rounded-lg border border-zinc-300 bg-white px-3 py-1.5 text-sm focus:border-indigo-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-100"
              disabled={@llm_loading}
            >
              <%= for model <- @llm_available_models do %>
                <option value={model.name} selected={model.name == @llm_model}>
                  {model.display_name}
                  <%= if model.supports_schema do %>
                    (schema ✓)
                  <% end %>
                </option>
              <% end %>
            </select>
          </form>

          <%!-- Streaming Toggle --%>
          <button
            type="button"
            phx-click="llm_toggle_streaming"
            disabled={@llm_loading}
            class={[
              "rounded-lg px-3 py-1.5 text-sm font-medium transition-colors",
              if(@llm_use_streaming,
                do: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400",
                else: "bg-zinc-100 text-zinc-600 dark:bg-zinc-800 dark:text-zinc-400"
              )
            ]}
          >
            Stream: {if @llm_use_streaming, do: "ON", else: "OFF"}
          </button>

          <%!-- Schema Force Toggle --%>
          <button
            type="button"
            phx-click="llm_cycle_schema"
            disabled={@llm_loading}
            class={[
              "rounded-lg px-3 py-1.5 text-sm font-medium transition-colors",
              case @llm_force_schema do
                nil -> "bg-zinc-100 text-zinc-600 dark:bg-zinc-800 dark:text-zinc-400"
                true -> "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400"
                false -> "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"
              end
            ]}
          >
            Schema:
            <%= case @llm_force_schema do %>
              <% nil -> %>
                Auto
              <% true -> %>
                Force ON
              <% false -> %>
                Force OFF
            <% end %>
          </button>
        <% end %>
      </div>

      <%!-- Provider/Model Info --%>
      <%= if @llm_provider == "claude" do %>
        <div class="text-xs text-zinc-500 dark:text-zinc-400">
          <span class="font-medium">Claude (ZMQ):</span>
          High-quality AI agent via Claude Agent SDK (ZMQ bridge)
          <%= if not @claude_zmq_available do %>
            <span class="ml-2 text-amber-600 dark:text-amber-400">
              ⚠ Bridge not running. Start with: cd priv/claude_bridge && npm start
            </span>
          <% end %>
        </div>
      <% else %>
        <%= if @llm_provider == "claude_http" do %>
          <div class="text-xs text-zinc-500 dark:text-zinc-400">
            <span class="font-medium">Claude (HTTP):</span>
            High-quality AI agent via Claude Agent SDK (HTTP+SSE bridge)
            <%= if not @claude_http_available do %>
              <span class="ml-2 text-amber-600 dark:text-amber-400">
                ⚠ Bridge not running. Start with: cd priv/claude_bridge_http && npm start
              </span>
            <% end %>
          </div>
        <% else %>
          <%= for model <- @llm_available_models, model.name == @llm_model do %>
            <div class="text-xs text-zinc-500 dark:text-zinc-400">
              <span class="font-medium">{model.display_name}:</span>
              {model.description}
              <span class="ml-2">
                [schema: {if model.supports_schema, do: "✓", else: "✗"},
                streaming: {if model.supports_streaming, do: "✓", else: "✗"},
                prompt: {model.prompt_style}]
              </span>
            </div>
          <% end %>
        <% end %>
      <% end %>

      <%!-- Prompt Input --%>
      <form phx-change="llm_prompt_change" phx-submit="llm_submit" class="flex gap-2">
        <input
          type="text"
          name="prompt"
          value={@llm_prompt}
          placeholder="Describe the UI you want (e.g., 'show weather for Tokyo', 'create a user profile')"
          class="flex-1 rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-100"
          disabled={@llm_loading}
          autocomplete="off"
        />
        <button
          type="submit"
          disabled={
            @llm_loading or @llm_prompt == "" or
              (@llm_provider == "claude" and not @claude_zmq_available) or
              (@llm_provider == "claude_http" and not @claude_http_available)
          }
          class={[
            "rounded-lg px-4 py-2 text-sm font-medium text-white shadow-sm transition-colors",
            if(@llm_loading,
              do: "bg-indigo-400 cursor-wait",
              else:
                "bg-indigo-600 hover:bg-indigo-500 disabled:bg-zinc-400 disabled:cursor-not-allowed"
            )
          ]}
        >
          <%= if @llm_loading do %>
            <span class="flex items-center gap-2">
              <span class="size-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
              Generating...
            </span>
          <% else %>
            Generate UI
          <% end %>
        </button>
      </form>

      <%!-- Error Display --%>
      <%= if @llm_error do %>
        <div class="rounded-lg bg-rose-50 p-3 text-sm text-rose-700 dark:bg-rose-950/30 dark:text-rose-400">
          <strong>Error:</strong> {@llm_error}
        </div>
      <% end %>
    </div>
    """
  end

  defp scenario_controls(assigns) do
    ~H"""
    <div class="text-sm text-zinc-600 dark:text-zinc-400">
      Interact with the rendered UI to observe the A2UI protocol in action
    </div>
    """
  end

  # Clear all surfaces
  defp clear_surfaces(socket) do
    Phoenix.Component.assign(socket,
      a2ui_surfaces: %{},
      a2ui_last_action: nil,
      a2ui_last_error: nil
    )
  end

  # Load scenario-specific content
  defp load_scenario(socket, "basic") do
    send_basic_form(self())
    socket
  end

  defp load_scenario(socket, "dynamic") do
    send_dynamic_update_demo(self())
    socket
  end

  defp load_scenario(socket, "multi_surface") do
    send_multi_surface_demo(self())
    socket
  end

  defp load_scenario(socket, "delete_surface") do
    send_delete_surface_demo(self())
    socket
  end

  defp load_scenario(socket, "streaming") do
    send_streaming_demo(self())
    socket
  end

  defp load_scenario(socket, "template_list") do
    send_template_list_demo(self())
    socket
  end

  defp load_scenario(socket, "data_binding") do
    send_data_binding_demo(self())
    socket
  end

  defp load_scenario(socket, "error_handling") do
    send_error_handling_demo(self())
    socket
  end

  defp load_scenario(socket, "llm_agent") do
    send_llm_agent_demo(self())

    # Refresh available models from Ollama
    available_models =
      case A2UIDemo.Demo.OllamaClient.list_available_models() do
        {:ok, models} -> models
        {:error, _} -> socket.assigns.llm_available_models
      end

    # Check Claude bridge availability (both ZMQ and HTTP)
    claude_zmq_available = A2UIDemo.Demo.ClaudeClient.available?()
    claude_http_available = A2UIDemo.Demo.ClaudeHTTPClient.available?()

    # Default provider: prefer HTTP if available, then ZMQ, then Ollama
    default_provider =
      cond do
        claude_http_available -> "claude_http"
        claude_zmq_available -> "claude"
        true -> "ollama"
      end

    assign(socket,
      llm_prompt: "",
      llm_original_prompt: nil,
      llm_loading: false,
      llm_error: nil,
      llm_available_models: available_models,
      claude_available: claude_zmq_available,
      claude_zmq_available: claude_zmq_available,
      claude_http_available: claude_http_available,
      llm_provider: default_provider
    )
  end

  defp load_scenario(socket, _), do: socket

  # Action callback - handles userAction and responds with UI updates
  defp handle_action(user_action, socket) do
    require Logger
    action = user_action["userAction"]
    action_name = action["name"]
    surface_id = action["surfaceId"]

    Logger.info("User action: #{action_name} on surface #{surface_id}")

    # Check if this is an action from the LLM-generated surface
    if surface_id == "llm-surface" and socket.assigns.llm_original_prompt do
      # Send action back to Claude for processing
      handle_llm_action(user_action, socket)
    else
      # Handle built-in demo actions
      if action_name in [
           "increment",
           "decrement",
           "reset_counter",
           "change_color",
           "toggle_visibility",
           "submit_form"
         ] do
        Process.send_after(self(), {:respond_to_action, action_name, surface_id}, 100)
      end

      socket
    end
  end

  # Handle actions from LLM-generated UI by sending them back to the LLM
  defp handle_llm_action(user_action, socket) do
    require Logger
    Logger.info("Sending LLM action back to provider: #{inspect(user_action)}")

    # Get the current data model for the LLM surface
    surface = socket.assigns.a2ui_surfaces["llm-surface"]
    data_model = if surface, do: surface.data_model, else: %{}

    # Get the original prompt
    original_prompt = socket.assigns.llm_original_prompt

    # Set loading state
    socket = assign(socket, llm_loading: true, llm_error: nil)
    pid = self()

    case socket.assigns.llm_provider do
      "claude" ->
        # Use Claude Agent SDK for follow-up via ZMQ bridge
        Task.start(fn ->
          result =
            A2UIDemo.Demo.ClaudeClient.generate_with_action(
              original_prompt,
              user_action,
              data_model,
              surface_id: "llm-surface",
              on_message: fn msg -> send(pid, {:a2ui, msg}) end,
              timeout: 300_000
            )

          send(pid, {:llm_done, result})
        end)

        socket

      "claude_http" ->
        # Use Claude Agent SDK for follow-up via HTTP+SSE bridge
        Task.start(fn ->
          result =
            A2UIDemo.Demo.ClaudeHTTPClient.generate_with_action(
              original_prompt,
              user_action,
              data_model,
              surface_id: "llm-surface",
              on_message: fn msg -> send(pid, {:a2ui, msg}) end,
              timeout: 300_000
            )

          send(pid, {:llm_done, result})
        end)

        socket

      _ollama ->
        # Use Ollama for follow-up
        Task.start(fn ->
          result =
            A2UIDemo.Demo.OllamaClient.generate_with_action(
              original_prompt,
              user_action,
              data_model,
              model: socket.assigns.llm_model,
              surface_id: "llm-surface",
              stream: socket.assigns.llm_use_streaming,
              force_schema: socket.assigns.llm_force_schema
            )

          send(pid, {:llm_response, result})
        end)

        socket
    end
  end

  # Error callback
  defp handle_error(error, socket) do
    require Logger
    Logger.warning("A2UI error: #{inspect(error)}")
    socket
  end

  # Respond to action with UI updates
  defp respond_to_action(socket, "increment", surface_id) do
    surface = socket.assigns.a2ui_surfaces[surface_id]

    if surface do
      current = get_in(surface.data_model, ["counter"]) || 0

      send(
        self(),
        {:a2ui,
         ~s({"dataModelUpdate":{"surfaceId":"#{surface_id}","contents":[{"key":"counter","valueNumber":#{current + 1}}]}})}
      )
    end

    socket
  end

  defp respond_to_action(socket, "decrement", surface_id) do
    surface = socket.assigns.a2ui_surfaces[surface_id]

    if surface do
      current = get_in(surface.data_model, ["counter"]) || 0

      send(
        self(),
        {:a2ui,
         ~s({"dataModelUpdate":{"surfaceId":"#{surface_id}","contents":[{"key":"counter","valueNumber":#{current - 1}}]}})}
      )
    end

    socket
  end

  defp respond_to_action(socket, "reset_counter", surface_id) do
    send(
      self(),
      {:a2ui,
       ~s({"dataModelUpdate":{"surfaceId":"#{surface_id}","contents":[{"key":"counter","valueNumber":0}]}})}
    )

    socket
  end

  defp respond_to_action(socket, "change_color", surface_id) do
    colors = ["#ef4444", "#f97316", "#eab308", "#22c55e", "#3b82f6", "#8b5cf6", "#ec4899"]
    new_color = Enum.random(colors)

    # Update the color component's text
    send(
      self(),
      {:a2ui,
       ~s({"dataModelUpdate":{"surfaceId":"#{surface_id}","contents":[{"key":"color","valueString":"#{new_color}"}]}})}
    )

    socket
  end

  defp respond_to_action(socket, "toggle_visibility", surface_id) do
    surface = socket.assigns.a2ui_surfaces[surface_id]

    if surface do
      visible = get_in(surface.data_model, ["visible"])
      new_visible = if visible == false, do: true, else: false

      send(
        self(),
        {:a2ui,
         ~s({"dataModelUpdate":{"surfaceId":"#{surface_id}","contents":[{"key":"visible","valueBoolean":#{new_visible}}]}})}
      )
    end

    socket
  end

  defp respond_to_action(socket, "submit_form", surface_id) do
    surface = socket.assigns.a2ui_surfaces[surface_id]

    if surface do
      form_data = get_in(surface.data_model, ["form"]) || %{}
      name = form_data["name"] || "Guest"

      # Update with success message
      send(
        self(),
        {:a2ui,
         ~s({"dataModelUpdate":{"surfaceId":"#{surface_id}","contents":[{"key":"status","valueString":"Thanks, #{name}! Form submitted."}]}})}
      )
    end

    socket
  end

  defp respond_to_action(socket, _, _), do: socket

  # ============================================================================
  # Scenario Message Generators
  # ============================================================================

  # Basic form demo (similar to existing MockAgent)
  defp send_basic_form(pid) do
    surface_update = ~S|{"surfaceUpdate":{"surfaceId":"basic","components":[
      {"id":"root","component":{"Column":{"children":{"explicitList":["header","form","actions"]}}}},
      {"id":"header","component":{"Text":{"text":{"literalString":"Contact Form"},"usageHint":"h1"}}},
      {"id":"form","component":{"Card":{"child":"form_fields"}}},
      {"id":"form_fields","component":{"Column":{"children":{"explicitList":["name_field","email_field","message_field","subscribe"]}}}},
      {"id":"name_field","component":{"TextField":{"label":{"literalString":"Name"},"text":{"path":"/form/name"},"textFieldType":"shortText"}}},
      {"id":"email_field","component":{"TextField":{"label":{"literalString":"Email"},"text":{"path":"/form/email"},"textFieldType":"shortText"}}},
      {"id":"message_field","component":{"TextField":{"label":{"literalString":"Message"},"text":{"path":"/form/message"},"textFieldType":"longText"}}},
      {"id":"subscribe","component":{"CheckBox":{"label":{"literalString":"Subscribe to updates"},"value":{"path":"/form/subscribe"}}}},
      {"id":"actions","component":{"Row":{"children":{"explicitList":["reset_btn","submit_btn"]},"distribution":"end"}}},
      {"id":"reset_btn","component":{"Button":{"child":"reset_text","primary":false,"action":{"name":"reset_form"}}}},
      {"id":"reset_text","component":{"Text":{"text":{"literalString":"Reset"}}}},
      {"id":"submit_btn","component":{"Button":{"child":"submit_text","primary":true,"action":{"name":"submit_form","context":[{"key":"formData","value":{"path":"/form"}}]}}}},
      {"id":"submit_text","component":{"Text":{"text":{"literalString":"Submit"}}}}
    ]}}|

    data_model = ~S|{"dataModelUpdate":{"surfaceId":"basic","contents":[
      {"key":"form","valueMap":[
        {"key":"name","valueString":""},
        {"key":"email","valueString":""},
        {"key":"message","valueString":""},
        {"key":"subscribe","valueBoolean":false}
      ]}
    ]}}|

    begin_rendering =
      ~s({"beginRendering":{"surfaceId":"basic","root":"root","styles":{"font":"Inter","primaryColor":"#4f46e5"}}})

    send(pid, {:a2ui, surface_update})
    send(pid, {:a2ui, data_model})
    send(pid, {:a2ui, begin_rendering})
  end

  # Dynamic update demo - counter with increment/decrement
  defp send_dynamic_update_demo(pid) do
    surface_update = ~S|{"surfaceUpdate":{"surfaceId":"dynamic","components":[
      {"id":"root","component":{"Column":{"alignment":"center","children":{"explicitList":["title","card","status_text"]}}}},
      {"id":"title","component":{"Text":{"text":{"literalString":"Counter Demo"},"usageHint":"h2"}}},
      {"id":"card","component":{"Card":{"child":"card_content"}}},
      {"id":"card_content","component":{"Column":{"alignment":"center","children":{"explicitList":["counter_display","button_row","color_row"]}}}},
      {"id":"counter_display","component":{"Text":{"text":{"path":"/counter"},"usageHint":"h1"}}},
      {"id":"button_row","component":{"Row":{"distribution":"center","children":{"explicitList":["dec_btn","reset_btn","inc_btn"]}}}},
      {"id":"dec_btn","component":{"Button":{"child":"dec_text","action":{"name":"decrement"}}}},
      {"id":"dec_text","component":{"Text":{"text":{"literalString":"−"}}}},
      {"id":"reset_btn","component":{"Button":{"child":"reset_text","primary":false,"action":{"name":"reset_counter"}}}},
      {"id":"reset_text","component":{"Text":{"text":{"literalString":"Reset"}}}},
      {"id":"inc_btn","component":{"Button":{"child":"inc_text","action":{"name":"increment"}}}},
      {"id":"inc_text","component":{"Text":{"text":{"literalString":"+"}}}},
      {"id":"color_row","component":{"Row":{"distribution":"center","children":{"explicitList":["color_btn","color_display"]}}}},
      {"id":"color_btn","component":{"Button":{"child":"color_btn_text","primary":false,"action":{"name":"change_color"}}}},
      {"id":"color_btn_text","component":{"Text":{"text":{"literalString":"Change Color"}}}},
      {"id":"color_display","component":{"Text":{"text":{"path":"/color"}}}},
      {"id":"status_text","component":{"Text":{"text":{"path":"/status"},"usageHint":"caption"}}}
    ]}}|

    data_model = ~S|{"dataModelUpdate":{"surfaceId":"dynamic","contents":[
      {"key":"counter","valueNumber":0},
      {"key":"color","valueString":"#3b82f6"},
      {"key":"status","valueString":"Click buttons to trigger userAction"}
    ]}}|

    begin_rendering = ~s({"beginRendering":{"surfaceId":"dynamic","root":"root"}})

    send(pid, {:a2ui, surface_update})
    send(pid, {:a2ui, data_model})
    send(pid, {:a2ui, begin_rendering})
  end

  # Multiple surfaces demo
  defp send_multi_surface_demo(pid) do
    # Surface 1 - Counter
    send(
      pid,
      {:a2ui, ~S|{"surfaceUpdate":{"surfaceId":"surface-1","components":[
      {"id":"root","component":{"Card":{"child":"content"}}},
      {"id":"content","component":{"Column":{"children":{"explicitList":["title","value"]}}}},
      {"id":"title","component":{"Text":{"text":{"literalString":"Surface 1: Counter"},"usageHint":"h4"}}},
      {"id":"value","component":{"Text":{"text":{"path":"/value"},"usageHint":"h2"}}}
    ]}}|}
    )

    send(
      pid,
      {:a2ui,
       ~s({"dataModelUpdate":{"surfaceId":"surface-1","contents":[{"key":"value","valueNumber":42}]}})}
    )

    send(pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"surface-1","root":"root"}})})

    # Surface 2 - Status
    send(
      pid,
      {:a2ui, ~S|{"surfaceUpdate":{"surfaceId":"surface-2","components":[
      {"id":"root","component":{"Card":{"child":"content"}}},
      {"id":"content","component":{"Column":{"children":{"explicitList":["title","status"]}}}},
      {"id":"title","component":{"Text":{"text":{"literalString":"Surface 2: Status"},"usageHint":"h4"}}},
      {"id":"status","component":{"Text":{"text":{"path":"/status"}}}}
    ]}}|}
    )

    send(
      pid,
      {:a2ui,
       ~s({"dataModelUpdate":{"surfaceId":"surface-2","contents":[{"key":"status","valueString":"Online"}]}})}
    )

    send(pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"surface-2","root":"root"}})})
  end

  # Send additional surface (for add button)
  defp send_additional_surface(pid, surface_id) do
    send(
      pid,
      {:a2ui, ~s|{"surfaceUpdate":{"surfaceId":"#{surface_id}","components":[
      {"id":"root","component":{"Card":{"child":"content"}}},
      {"id":"content","component":{"Column":{"children":{"explicitList":["title","time"]}}}},
      {"id":"title","component":{"Text":{"text":{"literalString":"New Surface"},"usageHint":"h4"}}},
      {"id":"time","component":{"Text":{"text":{"path":"/created"}}}}
    ]}}|}
    )

    send(
      pid,
      {:a2ui,
       ~s({"dataModelUpdate":{"surfaceId":"#{surface_id}","contents":[{"key":"created","valueString":"Created at #{DateTime.utc_now() |> DateTime.to_iso8601()}"}]}})}
    )

    send(pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"#{surface_id}","root":"root"}})})
  end

  # Delete surface demo
  defp send_delete_surface_demo(pid) do
    # Create 3 surfaces
    for i <- 1..3 do
      surface_id = "deletable-#{i}"

      send(
        pid,
        {:a2ui, ~s|{"surfaceUpdate":{"surfaceId":"#{surface_id}","components":[
        {"id":"root","component":{"Card":{"child":"content"}}},
        {"id":"content","component":{"Column":{"children":{"explicitList":["title","info"]}}}},
        {"id":"title","component":{"Text":{"text":{"literalString":"Surface #{i}"},"usageHint":"h4"}}},
        {"id":"info","component":{"Text":{"text":{"literalString":"Click Delete to remove this surface"}}}}
      ]}}|}
      )

      send(pid, {:a2ui, ~s({"dataModelUpdate":{"surfaceId":"#{surface_id}","contents":[]}})})
      send(pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"#{surface_id}","root":"root"}})})
    end
  end

  # Streaming demo - components added progressively
  defp send_streaming_demo(pid) do
    # Send components one at a time with delays
    messages = [
      ~S|{"surfaceUpdate":{"surfaceId":"streaming","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["loading"]}}}}
      ]}}|,
      ~s({"dataModelUpdate":{"surfaceId":"streaming","contents":[]}}),
      ~s({"beginRendering":{"surfaceId":"streaming","root":"root"}}),
      # Now stream in more components
      ~S|{"surfaceUpdate":{"surfaceId":"streaming","components":[
        {"id":"loading","component":{"Text":{"text":{"literalString":"Loading..."},"usageHint":"h3"}}}
      ]}}|,
      ~S|{"surfaceUpdate":{"surfaceId":"streaming","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["title","loading"]}}}}
      ]}}|,
      ~S|{"surfaceUpdate":{"surfaceId":"streaming","components":[
        {"id":"title","component":{"Text":{"text":{"literalString":"Streaming Demo"},"usageHint":"h2"}}}
      ]}}|,
      ~S|{"surfaceUpdate":{"surfaceId":"streaming","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["title","card1","loading"]}}}}
      ]}}|,
      ~S|{"surfaceUpdate":{"surfaceId":"streaming","components":[
        {"id":"card1","component":{"Card":{"child":"card1_text"}}},
        {"id":"card1_text","component":{"Text":{"text":{"literalString":"First card loaded!"}}}}
      ]}}|,
      ~S|{"surfaceUpdate":{"surfaceId":"streaming","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["title","card1","card2","loading"]}}}}
      ]}}|,
      ~S|{"surfaceUpdate":{"surfaceId":"streaming","components":[
        {"id":"card2","component":{"Card":{"child":"card2_text"}}},
        {"id":"card2_text","component":{"Text":{"text":{"literalString":"Second card loaded!"}}}}
      ]}}|,
      ~S|{"surfaceUpdate":{"surfaceId":"streaming","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["title","card1","card2","card3"]}}}}
      ]}}|,
      ~S|{"surfaceUpdate":{"surfaceId":"streaming","components":[
        {"id":"card3","component":{"Card":{"child":"card3_text"}}},
        {"id":"card3_text","component":{"Text":{"text":{"literalString":"All done! ✓"}}}}
      ]}}|
    ]

    # Send first 3 immediately, then delay the rest
    Enum.take(messages, 3) |> Enum.each(&send(pid, {:a2ui, &1}))

    # Schedule remaining messages with delays
    messages
    |> Enum.drop(3)
    |> Enum.with_index()
    |> Enum.each(fn {msg, i} ->
      Process.send_after(pid, {:a2ui, msg}, (i + 1) * 400)
    end)
  end

  # Template list demo
  defp send_template_list_demo(pid) do
    surface_update = ~S|{"surfaceUpdate":{"surfaceId":"template-list","components":[
      {"id":"root","component":{"Column":{"children":{"explicitList":["title","list_container"]}}}},
      {"id":"title","component":{"Text":{"text":{"literalString":"Product List (Template Rendering)"},"usageHint":"h2"}}},
      {"id":"list_container","component":{"Column":{"children":{"template":{"dataBinding":"/products","componentId":"product_card"}}}}},
      {"id":"product_card","component":{"Card":{"child":"product_content"}}},
      {"id":"product_content","component":{"Row":{"distribution":"spaceBetween","children":{"explicitList":["product_name","product_price"]}}}},
      {"id":"product_name","component":{"Text":{"text":{"path":"/name"},"usageHint":"h4"}}},
      {"id":"product_price","component":{"Text":{"text":{"path":"/price"},"usageHint":"caption"}}}
    ]}}|

    send(pid, {:a2ui, surface_update})

    # Initial products via path-based updates
    products = [
      {"Widget A", "$19.99", "prod-1"},
      {"Widget B", "$29.99", "prod-2"},
      {"Widget C", "$39.99", "prod-3"}
    ]

    for {{name, price, id}, i} <- Enum.with_index(products) do
      send(
        pid,
        {:a2ui,
         ~s({"dataModelUpdate":{"surfaceId":"template-list","path":"/products/#{i}","contents":[{"key":"name","valueString":"#{name}"},{"key":"price","valueString":"#{price}"},{"key":"id","valueString":"#{id}"}]}})}
      )
    end

    send(pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"template-list","root":"root"}})})
  end

  # Data binding demo - shows all binding modes
  defp send_data_binding_demo(pid) do
    surface_update = ~S|{"surfaceUpdate":{"surfaceId":"binding","components":[
      {"id":"root","component":{"Column":{"children":{"explicitList":["title","card"]}}}},
      {"id":"title","component":{"Text":{"text":{"literalString":"Data Binding Modes"},"usageHint":"h2"}}},
      {"id":"card","component":{"Card":{"child":"examples"}}},
      {"id":"examples","component":{"Column":{"children":{"explicitList":["literal_row","path_row","combined_row","input_row"]}}}},
      {"id":"literal_row","component":{"Row":{"children":{"explicitList":["literal_label","literal_value"]}}}},
      {"id":"literal_label","component":{"Text":{"text":{"literalString":"Literal only:"},"usageHint":"caption"}}},
      {"id":"literal_value","component":{"Text":{"text":{"literalString":"Static text (no binding)"}}}},
      {"id":"path_row","component":{"Row":{"children":{"explicitList":["path_label","path_value"]}}}},
      {"id":"path_label","component":{"Text":{"text":{"literalString":"Path only:"},"usageHint":"caption"}}},
      {"id":"path_value","component":{"Text":{"text":{"path":"/dynamic_value"}}}},
      {"id":"combined_row","component":{"Row":{"children":{"explicitList":["combined_label","combined_value"]}}}},
      {"id":"combined_label","component":{"Text":{"text":{"literalString":"Path + Literal (init):"},"usageHint":"caption"}}},
      {"id":"combined_value","component":{"Text":{"text":{"path":"/initialized_value","literalString":"Default Value"}}}},
      {"id":"input_row","component":{"Column":{"children":{"explicitList":["input_label","input_field","input_display"]}}}},
      {"id":"input_label","component":{"Text":{"text":{"literalString":"Two-way binding:"},"usageHint":"caption"}}},
      {"id":"input_field","component":{"TextField":{"label":{"literalString":"Type here"},"text":{"path":"/user_input"}}}},
      {"id":"input_display","component":{"Text":{"text":{"path":"/user_input"}}}}
    ]}}|

    data_model = ~S|{"dataModelUpdate":{"surfaceId":"binding","contents":[
      {"key":"dynamic_value","valueString":"Value from data model"},
      {"key":"user_input","valueString":"Edit me!"}
    ]}}|

    send(pid, {:a2ui, surface_update})
    send(pid, {:a2ui, data_model})
    send(pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"binding","root":"root"}})})
  end

  # Error handling demo - just a simple surface with instructions
  defp send_error_handling_demo(pid) do
    surface_update = ~S|{"surfaceUpdate":{"surfaceId":"error-demo","components":[
      {"id":"root","component":{"Column":{"children":{"explicitList":["title","instructions"]}}}},
      {"id":"title","component":{"Text":{"text":{"literalString":"Error Handling Demo"},"usageHint":"h2"}}},
      {"id":"instructions","component":{"Card":{"child":"instructions_text"}}},
      {"id":"instructions_text","component":{"Text":{"text":{"literalString":"Use the buttons above to trigger different error types. Errors will appear in the Debug Panel with the client→server error message format."}}}}
    ]}}|

    send(pid, {:a2ui, surface_update})
    send(pid, {:a2ui, ~s({"dataModelUpdate":{"surfaceId":"error-demo","contents":[]}})})
    send(pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"error-demo","root":"root"}})})
  end

  # LLM Agent demo - initial placeholder
  defp send_llm_agent_demo(pid) do
    surface_update = ~S|{"surfaceUpdate":{"surfaceId":"llm-surface","components":[
      {"id":"root","component":{"Column":{"alignment":"center","children":{"explicitList":["title","instructions"]}}}},
      {"id":"title","component":{"Text":{"text":{"literalString":"LLM-Generated UI"},"usageHint":"h2"}}},
      {"id":"instructions","component":{"Card":{"child":"instructions_content"}}},
      {"id":"instructions_content","component":{"Column":{"children":{"explicitList":["intro","examples"]}}}},
      {"id":"intro","component":{"Text":{"text":{"literalString":"Enter a prompt above to generate a UI. The LLM will create valid A2UI JSON that renders here."}}}},
      {"id":"examples","component":{"Text":{"text":{"literalString":"Try: 'show a user profile card', 'create a settings form', 'display weather for New York'"},"usageHint":"caption"}}}
    ]}}|

    send(pid, {:a2ui, surface_update})
    send(pid, {:a2ui, ~s({"dataModelUpdate":{"surfaceId":"llm-surface","contents":[]}})})
    send(pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"llm-surface","root":"root"}})})
  end

  # Format LLM errors for display
  defp format_llm_error(:not_connected) do
    "Could not connect to Claude bridge. Start it with: cd priv/claude_bridge && npm start"
  end

  defp format_llm_error({:bridge_error, msg}) do
    "Claude bridge error: #{msg}"
  end

  defp format_llm_error(:timeout) do
    "Request timed out. The model may be slow or the bridge crashed."
  end

  defp format_llm_error({:connection_failed, reason}) do
    "Could not connect to Ollama. Is it running? (#{inspect(reason)})"
  end

  defp format_llm_error({:model_not_found, model, available}) do
    "Model '#{model}' not found. Available: #{Enum.join(available, ", ")}"
  end

  defp format_llm_error({:api_error, status, body}) do
    "Ollama API error (#{status}): #{inspect(body)}"
  end

  defp format_llm_error({:json_parse_error, reason}) do
    "Failed to parse LLM response as JSON: #{inspect(reason)}"
  end

  defp format_llm_error(:unexpected_response_format) do
    "Unexpected response format from Ollama"
  end

  defp format_llm_error(reason) do
    "Error: #{inspect(reason)}"
  end
end
