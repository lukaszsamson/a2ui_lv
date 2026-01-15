defmodule A2UI.Phoenix.Renderer do
  @moduledoc """
  Top-level renderer for A2UI surfaces.

  Per Renderer Development Guide:
  - Buffer updates without immediate rendering
  - beginRendering signals explicit render initiation

  ## Catalog Selection

  The renderer uses `A2UI.Catalog.Registry` to look up the appropriate catalog
  module based on `surface.catalog_id`. If no catalog is registered for the
  surface's catalog ID, it falls back to `A2UI.Phoenix.Catalog.Standard`.

  To register custom catalogs:

      A2UI.Catalog.Registry.register("https://example.com/my-catalog.json", MyApp.Catalog)
  """

  use Phoenix.Component
  alias A2UI.Catalog.Registry
  alias A2UI.Phoenix.Catalog.Standard

  @doc """
  Renders an A2UI surface.

  Shows a loading state when the surface is not yet ready (before beginRendering).
  Uses the catalog module registered for `surface.catalog_id`, falling back to
  the standard catalog if not found.
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
        <.render_with_catalog surface={@surface} />
      <% else %>
        <div class="a2ui-loading flex items-center justify-center gap-3 p-8 text-sm text-zinc-600 dark:text-zinc-300">
          <div class="size-5 animate-spin rounded-full border-2 border-zinc-300 border-t-zinc-700 dark:border-zinc-700 dark:border-t-zinc-200" />
          Loading…
        </div>
      <% end %>
    </div>
    """
  end

  # Looks up the catalog module and renders the root component
  defp render_with_catalog(assigns) do
    catalog_id = assigns.surface.catalog_id
    catalog_module = Registry.lookup(catalog_id, Standard)
    assigns = assign(assigns, :catalog_module, catalog_module)

    ~H"""
    <.dynamic_catalog_render
      module={@catalog_module}
      id={@surface.root_id}
      surface={@surface}
      depth={0}
    />
    """
  end

  # Dynamic dispatch to catalog module's render_component/1
  attr :module, :atom, required: true
  attr :id, :string, required: true
  attr :surface, :map, required: true
  attr :depth, :integer, required: true

  defp dynamic_catalog_render(assigns) do
    # Use apply/3 for dynamic module dispatch
    assigns.module.render_component(assigns)
  end

  defp surface_style(%{styles: styles}) when is_map(styles) do
    primary = Map.get(styles, "primaryColor")

    []
    |> maybe_put_css_var("--a2ui-font", Map.get(styles, "font"), &valid_font_value?/1)
    |> maybe_put_css_var("--a2ui-primary-color", primary, &valid_hex_color?/1)
    |> maybe_put_css_var("--a2ui-primary-rgb", hex_to_rgb_triplet(primary), &valid_rgb_triplet?/1)
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

  defp hex_to_rgb_triplet(hex) when is_binary(hex) do
    if valid_hex_color?(hex) do
      <<?#, r1, r2, g1, g2, b1, b2>> = hex
      {r, ""} = Integer.parse(<<r1, r2>>, 16)
      {g, ""} = Integer.parse(<<g1, g2>>, 16)
      {b, ""} = Integer.parse(<<b1, b2>>, 16)
      "#{r} #{g} #{b}"
    else
      nil
    end
  end

  defp hex_to_rgb_triplet(_), do: nil

  defp valid_rgb_triplet?(value) when is_binary(value) do
    String.match?(value, ~r/^\d{1,3}\s+\d{1,3}\s+\d{1,3}$/)
  end

  defp valid_rgb_triplet?(_), do: false

  defp valid_font_value?(font) do
    String.match?(font, ~r/^[a-zA-Z0-9 ,"'_-]+$/)
  end
end
