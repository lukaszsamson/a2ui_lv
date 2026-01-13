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
        <div class="a2ui-loading flex items-center justify-center p-8 text-base-content/50">
          <span class="loading loading-spinner loading-md mr-2"></span>
          Loading...
        </div>
      <% end %>
    </div>
    """
  end
end
