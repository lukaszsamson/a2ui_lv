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
      style={surface_style(@surface)}
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

  defp surface_style(%{styles: styles}) when is_map(styles) do
    []
    |> maybe_put_css_var("--a2ui-font", Map.get(styles, "font"), &valid_font_value?/1)
    |> maybe_put_css_var(
      "--a2ui-primary-color",
      Map.get(styles, "primaryColor"),
      &valid_hex_color?/1
    )
    |> Enum.join(" ")
  end

  defp surface_style(_), do: nil

  defp maybe_put_css_var(acc, _name, nil, _valid?), do: acc

  defp maybe_put_css_var(acc, name, value, valid?) when is_binary(value) do
    if valid?.(value) do
      acc ++ ["#{name}: #{value};"]
    else
      acc
    end
  end

  defp maybe_put_css_var(acc, _name, _value, _valid?), do: acc

  defp valid_hex_color?(<<"#", rest::binary>>) do
    byte_size(rest) == 6 && String.match?(rest, ~r/^[0-9a-fA-F]{6}$/)
  end

  defp valid_hex_color?(_), do: false

  defp valid_font_value?(font) do
    String.match?(font, ~r/^[a-zA-Z0-9 ,"'_-]+$/)
  end
end
