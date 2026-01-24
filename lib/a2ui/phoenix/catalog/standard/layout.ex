defmodule A2UI.Phoenix.Catalog.Standard.Layout do
  @moduledoc false

  use Phoenix.Component

  import A2UI.Phoenix.Components, only: [icon: 1]
  import A2UI.Phoenix.Catalog.Standard.Helpers

  alias A2UI.Binding
  alias A2UI.Props.Adapter
  alias A2UI.Phoenix.Catalog.Standard

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :depth, :integer, default: 0
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def a2ui_column(assigns) do
    {justify, align} = Adapter.row_column_props(assigns.props, "stretch")
    assigns = assign(assigns, distribution: justify, alignment: align)

    ~H"""
    <div
      class="a2ui-column"
      style={"display: flex; flex-direction: column; gap: 0.5rem; width: 100%; #{flex_style(@distribution, @alignment)}"}
    >
      <Standard.render_children
        props={@props}
        surface={@surface}
        scope_path={@scope_path}
        depth={@depth}
        apply_weight={true}
        suppress_events={@suppress_events}
        visited={@visited}
      />
    </div>
    """
  end

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :depth, :integer, default: 0
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def a2ui_row(assigns) do
    {justify, align} = Adapter.row_column_props(assigns.props, "center")
    needs_full_width = justify != "start"
    width_style = if needs_full_width, do: "width: 100%;", else: ""

    assigns =
      assign(assigns, distribution: justify, alignment: align, width_style: width_style)

    ~H"""
    <div
      class="a2ui-row"
      style={"display: flex; flex-direction: row; gap: 0.5rem; #{@width_style} #{flex_style(@distribution, @alignment)}"}
    >
      <Standard.render_children
        props={@props}
        surface={@surface}
        scope_path={@scope_path}
        depth={@depth}
        apply_weight={true}
        suppress_events={@suppress_events}
        visited={@visited}
      />
    </div>
    """
  end

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true
  attr :depth, :integer, default: 0
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def a2ui_card(assigns) do
    ~H"""
    <div class="a2ui-card flex h-full w-full rounded-2xl border border-zinc-200 bg-white p-4 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
      <Standard.render_component
        :if={@props["child"]}
        id={@props["child"]}
        surface={@surface}
        scope_path={@scope_path}
        depth={@depth + 1}
        suppress_events={@suppress_events}
        visited={@visited}
      />
    </div>
    """
  end

  @doc """
  List - flex container for children with direction and alignment.
  Similar to Row/Column but with explicit List semantics.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :depth, :integer, default: 0
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def a2ui_list(assigns) do
    direction = assigns.props["direction"] || "vertical"
    alignment = assigns.props["alignment"] || "stretch"
    assigns = assign(assigns, direction: direction, alignment: alignment)

    ~H"""
    <div
      class="a2ui-list"
      style={"display: flex; flex-direction: #{list_flex_direction(@direction)}; gap: 0.5rem; #{list_alignment_style(@alignment)}"}
    >
      <Standard.render_children
        props={@props}
        surface={@surface}
        scope_path={@scope_path}
        depth={@depth}
        suppress_events={@suppress_events}
        visited={@visited}
      />
    </div>
    """
  end

  @doc """
  Tabs - tabbed container showing one tab at a time.
  Uses JS-based tab switching for performance.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true
  attr :depth, :integer, default: 0
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def a2ui_tabs(assigns) do
    tab_items = Adapter.tabs_props(assigns.props)
    opts = binding_opts(assigns.surface)
    assigns = assign(assigns, tab_items: tab_items, binding_opts: opts)

    ~H"""
    <div class="a2ui-tabs" id={component_dom_id(@surface.id, @id, @scope_path, "tabs")}>
      <%!-- Tab Headers --%>
      <div class="flex border-b border-zinc-200 dark:border-zinc-700">
        <%= for {tab, idx} <- Enum.with_index(@tab_items) do %>
          <% title = Binding.resolve(tab["title"], @surface.data_model, @scope_path, @binding_opts) %>
          <button
            type="button"
            phx-click={
              Phoenix.LiveView.JS.hide(
                to: "##{component_dom_id(@surface.id, @id, @scope_path, "tabs")} .a2ui-tab-content"
              )
              |> Phoenix.LiveView.JS.show(
                to: "##{component_dom_id(@surface.id, @id, @scope_path, "tab-#{idx}")}"
              )
              |> Phoenix.LiveView.JS.remove_class(
                "a2ui-tab-active",
                to: "##{component_dom_id(@surface.id, @id, @scope_path, "tabs")} .a2ui-tab-btn"
              )
              |> Phoenix.LiveView.JS.add_class(
                "a2ui-tab-active",
                to: "##{component_dom_id(@surface.id, @id, @scope_path, "tab-btn-#{idx}")}"
              )
            }
            id={component_dom_id(@surface.id, @id, @scope_path, "tab-btn-#{idx}")}
            class={[
              "a2ui-tab-btn -mb-px border-b-2 px-4 py-2 text-sm font-medium transition-colors",
              "border-transparent text-zinc-500 hover:border-zinc-300 hover:text-zinc-700 dark:text-zinc-400 dark:hover:text-zinc-300",
              idx == 0 && "a2ui-tab-active"
            ]}
          >
            {title}
          </button>
        <% end %>
      </div>
      <%!-- Tab Content Panels --%>
      <div class="pt-4">
        <%= for {tab, idx} <- Enum.with_index(@tab_items) do %>
          <div
            id={component_dom_id(@surface.id, @id, @scope_path, "tab-#{idx}")}
            class={["a2ui-tab-content", if(idx != 0, do: "hidden")]}
          >
            <Standard.render_component
              :if={tab["child"]}
              id={tab["child"]}
              surface={@surface}
              scope_path={@scope_path}
              depth={@depth + 1}
              suppress_events={@suppress_events}
              visited={@visited}
            />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Modal - dialog triggered by entry point, showing content in overlay.
  Uses JS-based show/hide for performance.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true
  attr :depth, :integer, default: 0
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def a2ui_modal(assigns) do
    {entry_point_child, content_child} = Adapter.modal_props(assigns.props)
    dialog_id = component_dom_id(assigns.surface.id, assigns.id, assigns.scope_path, "dialog")

    open_js =
      Phoenix.LiveView.JS.show(
        to: "##{dialog_id}",
        transition: {"ease-out duration-200", "opacity-0", "opacity-100"}
      )
      |> Phoenix.LiveView.JS.focus(to: "##{dialog_id}")

    close_js =
      Phoenix.LiveView.JS.hide(
        to: "##{dialog_id}",
        transition: {"ease-in duration-150", "opacity-100", "opacity-0"}
      )

    assigns =
      assign(assigns,
        entry_point_child: entry_point_child,
        content_child: content_child,
        dialog_id: dialog_id,
        open_js: open_js,
        close_js: close_js
      )

    ~H"""
    <div class="a2ui-modal">
      <%!-- Entry Point (trigger) --%>
      <div phx-click={@open_js} class="cursor-pointer">
        <Standard.render_component
          :if={@entry_point_child}
          id={@entry_point_child}
          surface={@surface}
          scope_path={@scope_path}
          depth={@depth + 1}
          suppress_events={true}
          visited={@visited}
        />
      </div>
      <%!-- Modal Dialog --%>
      <div
        id={@dialog_id}
        class="fixed inset-0 z-50 hidden overflow-y-auto outline-none"
        role="dialog"
        aria-modal="true"
        tabindex="-1"
        phx-window-keydown={@close_js}
        phx-key="Escape"
      >
        <%!-- Backdrop --%>
        <div class="fixed inset-0 bg-zinc-900/50 backdrop-blur-sm" phx-click={@close_js} />
        <%!-- Content Container --%>
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="relative w-full max-w-lg rounded-2xl border border-zinc-200 bg-white p-6 shadow-xl dark:border-zinc-700 dark:bg-zinc-900">
            <%!-- Close Button --%>
            <button
              type="button"
              class="absolute right-4 top-4 rounded-lg p-1 text-zinc-400 hover:bg-zinc-100 hover:text-zinc-600 dark:hover:bg-zinc-800 dark:hover:text-zinc-300"
              phx-click={@close_js}
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
            <%!-- Modal Content --%>
            <Standard.render_component
              :if={@content_child}
              id={@content_child}
              surface={@surface}
              scope_path={@scope_path}
              depth={@depth + 1}
              suppress_events={@suppress_events}
              visited={@visited}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
