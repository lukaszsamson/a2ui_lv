defmodule A2UI.Phoenix.Catalog.Standard do
  @moduledoc """
  Standard A2UI component catalog as Phoenix function components.

  From LiveView docs on change tracking:
  - Be explicit about which data each component needs
  - Prefer stable DOM ids for efficient diffs

  Implements all 18 standard catalog components from the A2UI v0.8 specification:

  ## Layout Components
  - `Column` - Vertical flex container
  - `Row` - Horizontal flex container
  - `Card` - Elevated visual container
  - `List` - Flex container with direction/alignment

  ## Display Components
  - `Text` - Text display with semantic hints (h1-h5, body, caption)
  - `Divider` - Visual separator (horizontal/vertical)
  - `Icon` - Standard icon set mapped to Heroicons
  - `Image` - Image display with fit and usage hints

  ## Media Components
  - `AudioPlayer` - HTML5 audio player with optional description
  - `Video` - HTML5 video player

  ## Interactive Components
  - `Button` - Clickable action trigger
  - `TextField` - Text input with label, two-way binding, and validation
  - `CheckBox` - Boolean toggle with two-way binding
  - `Slider` - Range input with numeric two-way binding
  - `DateTimeInput` - Date/time input with ISO 8601 binding
  - `MultipleChoice` - Selection from options with optional max selections

  ## Container Components
  - `Tabs` - Tabbed container with JS-based switching
  - `Modal` - Dialog triggered by entry point component
  """

  use Phoenix.Component

  import A2UI.Phoenix.Catalog.Standard.Display
  import A2UI.Phoenix.Catalog.Standard.Helpers
  import A2UI.Phoenix.Catalog.Standard.Input
  import A2UI.Phoenix.Catalog.Standard.Layout

  alias A2UI.Binding

  # ============================================
  # Component Dispatch
  # ============================================

  @doc """
  Dispatches to the appropriate component by type.
  """
  attr :id, :string, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :depth, :integer, default: 0
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def render_component(assigns) do
    component = assigns.surface.components[assigns.id]
    visited = assigns.visited || A2UI.Validator.new_visited()

    case A2UI.Validator.check_cycle(assigns.id, visited) do
      {:error, {:cycle_detected, _id}} ->
        assigns = assign(assigns, :cycle_id, assigns.id)

        ~H"""
        <div class="a2ui-error rounded-lg border border-rose-200 bg-rose-50 p-3 text-sm text-rose-900 dark:border-rose-900/50 dark:bg-rose-950/30 dark:text-rose-100">
          Cycle detected: component {@cycle_id} references itself
        </div>
        """

      :ok ->
        if component do
          new_visited = A2UI.Validator.track_visited(assigns.id, visited)
          assigns = assign(assigns, component: component, visited: new_visited)

          ~H"""
          <div
            class="a2ui-component contents"
            id={component_dom_id(@surface.id, @id, @scope_path)}
            data-a2ui-scope={@scope_path || ""}
          >
            <%= if @depth > A2UI.Validator.max_depth() do %>
              <div class="a2ui-error rounded-lg border border-rose-200 bg-rose-50 p-3 text-sm text-rose-900 dark:border-rose-900/50 dark:bg-rose-950/30 dark:text-rose-100">
                Max render depth exceeded
              </div>
            <% else %>
              <%= case @component.type do %>
                <% "Column" -> %>
                  <.a2ui_column
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    depth={@depth}
                    suppress_events={@suppress_events}
                    visited={@visited}
                  />
                <% "Row" -> %>
                  <.a2ui_row
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    depth={@depth}
                    suppress_events={@suppress_events}
                    visited={@visited}
                  />
                <% "Card" -> %>
                  <.a2ui_card
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    id={@id}
                    depth={@depth}
                    suppress_events={@suppress_events}
                    visited={@visited}
                  />
                <% "Text" -> %>
                  <.a2ui_text props={@component.props} surface={@surface} scope_path={@scope_path} />
                <% "Divider" -> %>
                  <.a2ui_divider props={@component.props} />
                <% "Button" -> %>
                  <.a2ui_button
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    id={@id}
                    depth={@depth}
                    suppress_events={@suppress_events}
                    visited={@visited}
                  />
                <% "TextField" -> %>
                  <.a2ui_text_field
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    id={@id}
                    suppress_events={@suppress_events}
                  />
                <% "CheckBox" -> %>
                  <.a2ui_checkbox
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    id={@id}
                    suppress_events={@suppress_events}
                  />
                <% "Icon" -> %>
                  <.a2ui_icon props={@component.props} surface={@surface} scope_path={@scope_path} />
                <% "Image" -> %>
                  <.a2ui_image props={@component.props} surface={@surface} scope_path={@scope_path} />
                <% "AudioPlayer" -> %>
                  <.a2ui_audio_player
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                  />
                <% "Video" -> %>
                  <.a2ui_video props={@component.props} surface={@surface} scope_path={@scope_path} />
                <% "Slider" -> %>
                  <.a2ui_slider
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    id={@id}
                    suppress_events={@suppress_events}
                  />
                <% "DateTimeInput" -> %>
                  <.a2ui_datetime_input
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    id={@id}
                    suppress_events={@suppress_events}
                  />
                <% "MultipleChoice" -> %>
                  <.a2ui_multiple_choice
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    id={@id}
                    suppress_events={@suppress_events}
                  />
                <% "ChoicePicker" -> %>
                  <.a2ui_multiple_choice
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    id={@id}
                    suppress_events={@suppress_events}
                  />
                <% "List" -> %>
                  <.a2ui_list
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    depth={@depth}
                    suppress_events={@suppress_events}
                    visited={@visited}
                  />
                <% "Tabs" -> %>
                  <.a2ui_tabs
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    id={@id}
                    depth={@depth}
                    suppress_events={@suppress_events}
                    visited={@visited}
                  />
                <% "Modal" -> %>
                  <.a2ui_modal
                    props={@component.props}
                    surface={@surface}
                    scope_path={@scope_path}
                    id={@id}
                    depth={@depth}
                    suppress_events={@suppress_events}
                    visited={@visited}
                  />
                <% _ -> %>
                  <.a2ui_unknown type={@component.type} />
              <% end %>
            <% end %>
          </div>
          """
        else
          ~H"""
          <div class="a2ui-missing rounded-lg border border-rose-200 bg-rose-50 p-3 text-sm text-rose-900 dark:border-rose-900/50 dark:bg-rose-950/30 dark:text-rose-100">
            Missing component: {@id}
          </div>
          """
        end
    end
  end

  # ============================================
  # Children Rendering
  # ============================================

  @doc """
  Renders children from explicitList or template.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :depth, :integer, default: 0
  attr :apply_weight, :boolean, default: false
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def render_children(assigns) do
    children_spec = assigns.props["children"]

    cond do
      is_list(children_spec) ->
        child_ids = children_spec

        child_entries =
          Enum.map(child_ids, fn child_id ->
            {child_id, assigns.apply_weight && component_weight(assigns.surface, child_id)}
          end)

        assigns = assign(assigns, child_entries: child_entries)

        ~H"""
        <%= for {child_id, weight} <- @child_entries do %>
          <%= if is_number(weight) do %>
            <div
              class="a2ui-weighted"
              style={"flex: #{weight} 1 0%; min-width: 0; display: flex; align-items: stretch;"}
            >
              <.render_component
                id={child_id}
                surface={@surface}
                scope_path={@scope_path}
                depth={@depth + 1}
                suppress_events={@suppress_events}
                visited={@visited}
              />
            </div>
          <% else %>
            <.render_component
              id={child_id}
              surface={@surface}
              scope_path={@scope_path}
              depth={@depth + 1}
              suppress_events={@suppress_events}
              visited={@visited}
            />
          <% end %>
        <% end %>
        """

      is_map(children_spec) && Map.has_key?(children_spec, "explicitList") ->
        child_ids = children_spec["explicitList"]

        child_entries =
          Enum.map(child_ids, fn child_id ->
            {child_id, assigns.apply_weight && component_weight(assigns.surface, child_id)}
          end)

        assigns = assign(assigns, child_entries: child_entries)

        ~H"""
        <%= for {child_id, weight} <- @child_entries do %>
          <%= if is_number(weight) do %>
            <div
              class="a2ui-weighted"
              style={"flex: #{weight} 1 0%; min-width: 0; display: flex; align-items: stretch;"}
            >
              <.render_component
                id={child_id}
                surface={@surface}
                scope_path={@scope_path}
                depth={@depth + 1}
                suppress_events={@suppress_events}
                visited={@visited}
              />
            </div>
          <% else %>
            <.render_component
              id={child_id}
              surface={@surface}
              scope_path={@scope_path}
              depth={@depth + 1}
              suppress_events={@suppress_events}
              visited={@visited}
            />
          <% end %>
        <% end %>
        """

      is_map(children_spec) && Map.has_key?(children_spec, "path") &&
          Map.has_key?(children_spec, "componentId") ->
        data_binding = children_spec["path"]
        template_id = children_spec["componentId"]

        base_path =
          Binding.expand_path(data_binding, assigns.scope_path, binding_opts(assigns.surface))

        collection = Binding.get_at_pointer(assigns.surface.data_model, base_path)
        max_items = A2UI.Validator.max_template_items()
        template_weight = assigns.apply_weight && component_weight(assigns.surface, template_id)

        render_template_collection(
          assigns,
          collection,
          template_id,
          base_path,
          template_weight,
          max_items
        )

      is_map(children_spec) && Map.has_key?(children_spec, "template") ->
        template = children_spec["template"]
        data_binding = template["dataBinding"]
        template_id = template["componentId"]

        base_path =
          Binding.expand_path(data_binding, assigns.scope_path, binding_opts(assigns.surface))

        collection = Binding.get_at_pointer(assigns.surface.data_model, base_path)
        max_items = A2UI.Validator.max_template_items()
        template_weight = assigns.apply_weight && component_weight(assigns.surface, template_id)

        render_template_collection(
          assigns,
          collection,
          template_id,
          base_path,
          template_weight,
          max_items
        )

      true ->
        ~H""
    end
  end

  defp render_template_collection(
         assigns,
         collection,
         template_id,
         base_path,
         template_weight,
         max_items
       ) do
    cond do
      is_list(collection) ->
        indices =
          collection
          |> Enum.with_index()
          |> Enum.take(max_items)
          |> Enum.map(fn {_item, idx} -> to_string(idx) end)

        assigns =
          assign(assigns,
            indices: indices,
            template_id: template_id,
            base_path: base_path,
            template_weight: template_weight
          )

        ~H"""
        <%= for idx <- @indices do %>
          <%= if is_number(@template_weight) do %>
            <div
              class="a2ui-weighted"
              style={"flex: #{@template_weight} 1 0%; min-width: 0; display: flex; align-items: stretch;"}
            >
              <.render_component
                id={@template_id}
                surface={@surface}
                scope_path={Binding.append_pointer_segment(@base_path, idx)}
                depth={@depth + 1}
                suppress_events={@suppress_events}
                visited={@visited}
              />
            </div>
          <% else %>
            <.render_component
              id={@template_id}
              surface={@surface}
              scope_path={Binding.append_pointer_segment(@base_path, idx)}
              depth={@depth + 1}
              suppress_events={@suppress_events}
              visited={@visited}
            />
          <% end %>
        <% end %>
        """

      is_map(collection) ->
        keys =
          collection
          |> stable_template_keys()
          |> Enum.take(max_items)

        assigns =
          assign(assigns,
            keys: keys,
            template_id: template_id,
            base_path: base_path,
            template_weight: template_weight
          )

        ~H"""
        <%= for key <- @keys do %>
          <%= if is_number(@template_weight) do %>
            <div
              class="a2ui-weighted"
              style={"flex: #{@template_weight} 1 0%; min-width: 0; display: flex; align-items: stretch;"}
            >
              <.render_component
                id={@template_id}
                surface={@surface}
                scope_path={Binding.append_pointer_segment(@base_path, key)}
                depth={@depth + 1}
                suppress_events={@suppress_events}
                visited={@visited}
              />
            </div>
          <% else %>
            <.render_component
              id={@template_id}
              surface={@surface}
              scope_path={Binding.append_pointer_segment(@base_path, key)}
              depth={@depth + 1}
              suppress_events={@suppress_events}
              visited={@visited}
            />
          <% end %>
        <% end %>
        """

      true ->
        ~H""
    end
  end

  # ============================================
  # Unknown Component Handler
  # ============================================

  attr :type, :string, required: true

  def a2ui_unknown(assigns) do
    ~H"""
    <div class="a2ui-unknown rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-100">
      Unsupported component type: {@type}
    </div>
    """
  end
end
