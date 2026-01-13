defmodule A2UI.Catalog.Standard do
  @moduledoc """
  Standard A2UI component catalog as Phoenix function components.

  From LiveView docs on change tracking:
  - Be explicit about which data each component needs
  - Prefer stable DOM ids for efficient diffs

  Implements 8 core components from the A2UI specification:
  - Layout: Column, Row, Card
  - Display: Text, Divider
  - Interactive: Button, TextField, Checkbox
  """

  use Phoenix.Component
  import A2uiLvWeb.CoreComponents, only: [input: 1]
  alias A2UI.Binding

  # ============================================
  # Component Dispatch
  # ============================================

  @doc """
  Dispatches to the appropriate component by type.

  This is the main entry point - looks up component by ID,
  then delegates to the type-specific renderer.

  Per DESIGN_V1.md: Pass `scope_path` (a JSON Pointer string like "/items/0")
  instead of the full scope object. This keeps DOM payloads small and
  bindings are resolved at render/event time.
  """
  attr :id, :string, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :depth, :integer, default: 0

  def render_component(assigns) do
    component = assigns.surface.components[assigns.id]

    if component do
      assigns = assign(assigns, :component, component)

      # Use display:contents to not break flex layout while keeping the wrapper for debugging
      ~H"""
      <div class="a2ui-component contents" id={"a2ui-#{@surface.id}-#{@id}"}>
        <%= if @depth > A2UI.Validator.max_depth() do %>
          <div class="a2ui-error text-error text-sm p-2">Max render depth exceeded</div>
        <% else %>
          <%= case @component.type do %>
            <% "Column" -> %>
              <.a2ui_column props={@component.props} surface={@surface} scope_path={@scope_path} depth={@depth} />
            <% "Row" -> %>
              <.a2ui_row props={@component.props} surface={@surface} scope_path={@scope_path} depth={@depth} />
            <% "Card" -> %>
              <.a2ui_card props={@component.props} surface={@surface} scope_path={@scope_path} id={@id} depth={@depth} />
            <% "Text" -> %>
              <.a2ui_text props={@component.props} surface={@surface} scope_path={@scope_path} />
            <% "Divider" -> %>
              <.a2ui_divider props={@component.props} />
            <% "Button" -> %>
              <.a2ui_button props={@component.props} surface={@surface} scope_path={@scope_path} id={@id} depth={@depth} />
            <% "TextField" -> %>
              <.a2ui_text_field props={@component.props} surface={@surface} scope_path={@scope_path} id={@id} />
            <% "Checkbox" -> %>
              <.a2ui_checkbox props={@component.props} surface={@surface} scope_path={@scope_path} id={@id} />
            <% "CheckBox" -> %>
              <.a2ui_checkbox props={@component.props} surface={@surface} scope_path={@scope_path} id={@id} />
            <% unknown -> %>
              <.a2ui_unknown type={unknown} />
          <% end %>
        <% end %>
      </div>
      """
    else
      ~H"""
      <div class="a2ui-missing text-error text-sm">Missing component: <%= @id %></div>
      """
    end
  end

  # ============================================
  # Layout Components
  # ============================================

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :depth, :integer, default: 0

  def a2ui_column(assigns) do
    distribution = assigns.props["distribution"] || "start"
    alignment = assigns.props["alignment"] || "stretch"
    assigns = assign(assigns, distribution: distribution, alignment: alignment)

    ~H"""
    <div
      class="a2ui-column"
      style={"display: flex; flex-direction: column; gap: 0.5rem; #{flex_style(@distribution, @alignment)}"}
    >
      <.render_children props={@props} surface={@surface} scope_path={@scope_path} depth={@depth} />
    </div>
    """
  end

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :depth, :integer, default: 0

  def a2ui_row(assigns) do
    distribution = assigns.props["distribution"] || "start"
    alignment = assigns.props["alignment"] || "center"
    assigns = assign(assigns, distribution: distribution, alignment: alignment)

    ~H"""
    <div
      class="a2ui-row"
      style={"display: flex; flex-direction: row; gap: 0.5rem; #{flex_style(@distribution, @alignment)}"}
    >
      <.render_children props={@props} surface={@surface} scope_path={@scope_path} depth={@depth} />
    </div>
    """
  end

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true
  attr :depth, :integer, default: 0

  def a2ui_card(assigns) do
    ~H"""
    <div class="a2ui-card card bg-base-100 shadow-sm border border-base-300 p-4">
      <.render_component
        :if={@props["child"]}
        id={@props["child"]}
        surface={@surface}
        scope_path={@scope_path}
        depth={@depth + 1}
      />
    </div>
    """
  end

  # ============================================
  # Display Components
  # ============================================

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_text(assigns) do
    text = Binding.resolve(assigns.props["text"], assigns.surface.data_model, assigns.scope_path)
    hint = assigns.props["usageHint"] || "body"
    assigns = assign(assigns, text: text, hint: hint)

    ~H"""
    <span class={text_classes(@hint)}><%= @text %></span>
    """
  end

  attr :props, :map, required: true

  def a2ui_divider(assigns) do
    axis = assigns.props["axis"] || "horizontal"
    assigns = assign(assigns, axis: axis)

    ~H"""
    <div class={divider_classes(@axis)}></div>
    """
  end

  # ============================================
  # Interactive Components
  # ============================================

  @doc """
  Button - clickable action trigger.

  Per DESIGN_V1.md: Don't embed action JSON in DOM - just pass surface_id
  and component_id. Server looks up the component definition and resolves
  action.context at event time. This avoids large DOM payloads.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true
  attr :depth, :integer, default: 0

  def a2ui_button(assigns) do
    primary = assigns.props["primary"] || false
    assigns = assign(assigns, primary: primary)

    ~H"""
    <button
      class={button_classes(@primary)}
      phx-click="a2ui:action"
      phx-value-surface-id={@surface.id}
      phx-value-component-id={@id}
      phx-value-scope-path={@scope_path || ""}
    >
      <.render_component
        :if={@props["child"]}
        id={@props["child"]}
        surface={@surface}
        scope_path={@scope_path}
        depth={@depth + 1}
      />
    </button>
    """
  end

  @doc """
  TextField - text input with label and two-way binding.

  Per DESIGN_V1.md: Uses the project's `<.input>` component from
  core_components.ex. Wraps in a form with phx-change for proper
  LiveView form handling.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true

  def a2ui_text_field(assigns) do
    label = Binding.resolve(assigns.props["label"], assigns.surface.data_model, assigns.scope_path)
    # v0.8 uses "text", v0.9 uses "value"
    text_prop = assigns.props["text"] || assigns.props["value"]
    text = Binding.resolve(text_prop, assigns.surface.data_model, assigns.scope_path)
    # v0.8 uses "textFieldType", v0.9 uses "variant"
    field_type = assigns.props["textFieldType"] || assigns.props["variant"] || "shortText"

    # Get absolute path for binding (expand if relative)
    raw_path = Binding.get_path(text_prop)
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path), else: nil

    assigns = assign(assigns, label: label, text: text || "", field_type: field_type, path: path)

    ~H"""
    <.form
      for={%{}}
      as={:a2ui_input}
      phx-change="a2ui:input"
      class="a2ui-text-field"
      id={"a2ui-form-#{@surface.id}-#{@id}"}
    >
      <input type="hidden" name="a2ui_input[surface_id]" value={@surface.id} />
      <input type="hidden" name="a2ui_input[path]" value={@path} />
      <.input
        name="a2ui_input[value]"
        id={"a2ui-input-#{@surface.id}-#{@id}"}
        label={@label}
        value={@text}
        type={input_type(@field_type)}
        phx-debounce="300"
      />
    </.form>
    """
  end

  @doc """
  Checkbox - boolean toggle with two-way binding.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true

  def a2ui_checkbox(assigns) do
    label = Binding.resolve(assigns.props["label"], assigns.surface.data_model, assigns.scope_path)
    value = Binding.resolve(assigns.props["value"], assigns.surface.data_model, assigns.scope_path)

    # Get absolute path for binding
    raw_path = Binding.get_path(assigns.props["value"])
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path), else: nil

    assigns = assign(assigns, label: label, value: !!value, path: path)

    ~H"""
    <.form
      for={%{}}
      as={:a2ui_input}
      phx-change="a2ui:toggle"
      id={"a2ui-form-#{@surface.id}-#{@id}"}
    >
      <input type="hidden" name="a2ui_input[surface_id]" value={@surface.id} />
      <input type="hidden" name="a2ui_input[path]" value={@path} />
      <.input
        name="a2ui_input[value]"
        id={"a2ui-checkbox-#{@surface.id}-#{@id}"}
        type="checkbox"
        label={@label}
        value={@value}
        checked={@value}
      />
    </.form>
    """
  end

  # ============================================
  # Children Rendering
  # ============================================

  @doc """
  Renders children from explicitList or template.

  Per DESIGN_V1.md: For templates, pass scope_path (e.g., "/items/0")
  rather than the full scope object. This keeps DOM payloads small
  and resolves bindings at render/event time.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :depth, :integer, default: 0

  def render_children(assigns) do
    children_spec = assigns.props["children"]

    cond do
      # Explicit list of component IDs
      is_map(children_spec) && Map.has_key?(children_spec, "explicitList") ->
        assigns = assign(assigns, child_ids: children_spec["explicitList"])

        ~H"""
        <%= for child_id <- @child_ids do %>
          <.render_component id={child_id} surface={@surface} scope_path={@scope_path} depth={@depth + 1} />
        <% end %>
        """

      # Template (dynamic list from data binding)
      is_map(children_spec) && Map.has_key?(children_spec, "template") ->
        template = children_spec["template"]
        data_binding = template["dataBinding"]
        template_id = template["componentId"]

        # Resolve the array path to get items
        items =
          Binding.resolve(%{"path" => data_binding}, assigns.surface.data_model, assigns.scope_path) ||
            []

        # Enforce template item limit
        items =
          if length(items) > A2UI.Validator.max_template_items() do
            Enum.take(items, A2UI.Validator.max_template_items())
          else
            items
          end

        # Compute base path for template items
        base_path = Binding.expand_path(data_binding, assigns.scope_path)

        assigns = assign(assigns, items: items, template_id: template_id, base_path: base_path)

        ~H"""
        <%= for {_item, idx} <- Enum.with_index(@items) do %>
          <.render_component
            id={@template_id}
            surface={@surface}
            scope_path={"#{@base_path}/#{idx}"}
            depth={@depth + 1}
          />
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
    <div class="a2ui-unknown text-warning border border-warning rounded p-2 text-sm">
      Unsupported component type: <%= @type %>
    </div>
    """
  end

  # ============================================
  # Style Helpers
  # ============================================

  defp flex_style(distribution, alignment) do
    justify =
      case distribution do
        "center" -> "center"
        "end" -> "flex-end"
        "start" -> "flex-start"
        "spaceAround" -> "space-around"
        "spaceBetween" -> "space-between"
        "spaceEvenly" -> "space-evenly"
        _ -> "flex-start"
      end

    align =
      case alignment do
        "center" -> "center"
        "end" -> "flex-end"
        "start" -> "flex-start"
        "stretch" -> "stretch"
        _ -> "stretch"
      end

    "justify-content: #{justify}; align-items: #{align};"
  end

  defp text_classes(hint) do
    case hint do
      "h1" -> "text-3xl font-bold"
      "h2" -> "text-2xl font-bold"
      "h3" -> "text-xl font-semibold"
      "h4" -> "text-lg font-semibold"
      "h5" -> "text-base font-medium"
      "caption" -> "text-sm text-base-content/60"
      "body" -> "text-base"
      _ -> "text-base"
    end
  end

  defp divider_classes("vertical"), do: "divider divider-horizontal h-full"
  defp divider_classes(_), do: "divider w-full"

  defp button_classes(true) do
    "btn btn-primary"
  end

  defp button_classes(false) do
    "btn btn-outline"
  end

  defp input_type("number"), do: "number"
  defp input_type("date"), do: "date"
  defp input_type("obscured"), do: "password"
  defp input_type("longText"), do: "textarea"
  defp input_type(_), do: "text"
end
