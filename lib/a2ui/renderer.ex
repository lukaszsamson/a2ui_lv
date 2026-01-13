defmodule A2UI.Renderer do
  @moduledoc """
  Top-level renderer for A2UI surfaces.

  Per Renderer Development Guide:
  - Buffer updates without immediate rendering
  - beginRendering signals explicit render initiation
  """

  use Phoenix.Component
  alias A2UI.Catalog.Standard

  @doc """
  Renders an A2UI surface.

  Shows a loading state when the surface is not yet ready (before beginRendering).
  """
  attr :surface, :map, required: true

  def surface(assigns) do
    ~H"""
    <div
      class="a2ui-surface"
      id={"a2ui-surface-#{@surface.id}"}
      data-surface-id={@surface.id}
    >
      <%= if @surface.ready? do %>
        <Standard.render_component
          id={@surface.root_id}
          surface={@surface}
          depth={0}
        />
      <% else %>
        <div class="a2ui-loading flex items-center justify-center gap-3 p-8 text-sm text-zinc-600 dark:text-zinc-300">
          <div class="size-5 animate-spin rounded-full border-2 border-zinc-300 border-t-zinc-700 dark:border-zinc-700 dark:border-t-zinc-200" />
          Loading…
        </div>
      <% end %>
    </div>
    """
  end
end
