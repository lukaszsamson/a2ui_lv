defmodule A2UI.Phoenix.Catalog.Standard.Input do
  @moduledoc false

  use Phoenix.Component

  import A2UI.Phoenix.Components, only: [input: 1]
  import A2UI.Phoenix.Catalog.Standard.Helpers

  alias A2UI.{Binding, Checks}
  alias A2UI.Props.Adapter
  alias A2UI.Phoenix.Catalog.Standard

  @doc """
  Button - clickable action trigger.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true
  attr :depth, :integer, default: 0
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def a2ui_button(assigns) do
    opts = binding_opts(assigns.surface)
    primary = assigns.props["primary"] || false
    has_action = assigns.props["action"] != nil and not assigns.suppress_events

    checks = assigns.props["checks"]
    checks_pass = Checks.all_pass?(checks, assigns.surface.data_model, assigns.scope_path, opts)
    disabled = not checks_pass

    assigns =
      assign(assigns,
        primary: primary,
        has_action: has_action,
        disabled: disabled
      )

    ~H"""
    <button
      type="button"
      class={button_classes(@primary, @disabled)}
      phx-click={@has_action && !@disabled && "a2ui:action"}
      phx-value-surface-id={@has_action && !@disabled && @surface.id}
      phx-value-component-id={@has_action && !@disabled && @id}
      phx-value-scope-path={@has_action && !@disabled && (@scope_path || "")}
      disabled={@disabled}
    >
      <Standard.render_component
        :if={@props["child"]}
        id={@props["child"]}
        surface={@surface}
        scope_path={@scope_path}
        depth={@depth + 1}
        suppress_events={@suppress_events}
        visited={@visited}
      />
    </button>
    """
  end

  @doc """
  TextField - text input with label and two-way binding.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true
  attr :suppress_events, :boolean, default: false

  def a2ui_text_field(assigns) do
    opts = binding_opts(assigns.surface)

    label =
      Binding.resolve(
        assigns.props["label"],
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    value_prop = Adapter.text_field_value_prop(assigns.props)
    text = Binding.resolve(value_prop, assigns.surface.data_model, assigns.scope_path, opts)
    field_type = Adapter.text_field_type_prop(assigns.props)

    raw_path = Binding.get_path(value_prop)
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path, opts), else: nil

    validation_regexp = assigns.props["validationRegexp"]
    checks = assigns.props["checks"]

    errors =
      build_text_field_errors(
        text || "",
        validation_regexp,
        checks,
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    assigns =
      assign(assigns,
        label: label,
        text: text || "",
        field_type: field_type,
        path: path,
        errors: errors
      )

    ~H"""
    <.form
      for={%{}}
      as={:a2ui_input}
      phx-change={!@suppress_events && "a2ui:input"}
      class="a2ui-text-field"
      id={component_dom_id(@surface.id, @id, @scope_path, "form")}
    >
      <input type="hidden" name="a2ui_input[surface_id]" value={@surface.id} />
      <input type="hidden" name="a2ui_input[path]" value={@path} />
      <.input
        name="a2ui_input[value]"
        id={component_dom_id(@surface.id, @id, @scope_path, "input")}
        type={input_type(@field_type)}
        label={@label}
        value={@text}
        disabled={@suppress_events}
        errors={@errors}
      />
    </.form>
    """
  end

  @doc """
  CheckBox - boolean toggle with two-way binding.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true
  attr :suppress_events, :boolean, default: false

  def a2ui_checkbox(assigns) do
    opts = binding_opts(assigns.surface)

    label =
      Binding.resolve(
        assigns.props["label"],
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    value =
      Binding.resolve(
        assigns.props["value"],
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    raw_path = Binding.get_path(assigns.props["value"])
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path, opts), else: nil

    checks = assigns.props["checks"]
    errors = Checks.evaluate_checks(checks, assigns.surface.data_model, assigns.scope_path, opts)

    assigns = assign(assigns, label: label, value: !!value, path: path, errors: errors)

    ~H"""
    <.form
      for={%{}}
      as={:a2ui_input}
      phx-change={!@suppress_events && "a2ui:toggle"}
      id={component_dom_id(@surface.id, @id, @scope_path, "form")}
    >
      <input type="hidden" name="a2ui_input[surface_id]" value={@surface.id} />
      <input type="hidden" name="a2ui_input[path]" value={@path} />
      <.input
        name="a2ui_input[value]"
        id={component_dom_id(@surface.id, @id, @scope_path, "checkbox")}
        type="checkbox"
        label={@label}
        value={@value}
        checked={@value}
        disabled={@suppress_events}
        errors={@errors}
      />
    </.form>
    """
  end

  @doc """
  Slider - range input with numeric two-way binding.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true
  attr :suppress_events, :boolean, default: false

  def a2ui_slider(assigns) do
    opts = binding_opts(assigns.surface)

    label =
      Binding.resolve(
        assigns.props["label"],
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    value =
      Binding.resolve(
        assigns.props["value"],
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    {min_val, max_val} = Adapter.slider_range_props(assigns.props)

    raw_path = Binding.get_path(assigns.props["value"])
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path, opts), else: nil

    checks = assigns.props["checks"]
    errors = Checks.evaluate_checks(checks, assigns.surface.data_model, assigns.scope_path, opts)

    assigns =
      assign(assigns,
        label: label,
        value: value || min_val,
        min_val: min_val,
        max_val: max_val,
        path: path,
        errors: errors
      )

    ~H"""
    <.form
      for={%{}}
      as={:a2ui_input}
      phx-change={!@suppress_events && "a2ui:slider"}
      class="a2ui-slider"
      id={component_dom_id(@surface.id, @id, @scope_path, "form")}
    >
      <input type="hidden" name="a2ui_input[surface_id]" value={@surface.id} />
      <input type="hidden" name="a2ui_input[path]" value={@path} />
      <div class="space-y-1">
        <label :if={@label} class="block text-sm font-medium text-zinc-700 dark:text-zinc-300">
          {@label}
        </label>
        <div class="flex items-center gap-3">
          <input
            type="range"
            name="a2ui_input[value]"
            id={component_dom_id(@surface.id, @id, @scope_path, "range")}
            value={@value}
            min={@min_val}
            max={@max_val}
            disabled={@suppress_events}
            class="h-2 w-full cursor-pointer appearance-none rounded-lg bg-zinc-200 dark:bg-zinc-700"
          />
          <span class="min-w-[3rem] text-sm text-zinc-600 dark:text-zinc-400">{@value}</span>
        </div>
        <p :for={error <- @errors} class="mt-1 text-sm text-rose-600 dark:text-rose-400">
          {error}
        </p>
      </div>
    </.form>
    """
  end

  @doc """
  DateTimeInput - date and/or time input with ISO 8601 binding.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true
  attr :suppress_events, :boolean, default: false

  def a2ui_datetime_input(assigns) do
    opts = binding_opts(assigns.surface)

    label =
      Binding.resolve(
        assigns.props["label"],
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    value =
      Binding.resolve(
        assigns.props["value"],
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    enable_date = assigns.props["enableDate"] != false
    enable_time = assigns.props["enableTime"] != false

    input_type =
      cond do
        enable_date and enable_time -> "datetime-local"
        enable_date -> "date"
        enable_time -> "time"
        true -> "datetime-local"
      end

    html_value = iso8601_to_html_datetime(value, input_type)

    step =
      case input_type do
        "time" -> "1"
        "datetime-local" -> "1"
        _ -> nil
      end

    raw_path = Binding.get_path(assigns.props["value"])
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path, opts), else: nil

    checks = assigns.props["checks"]
    errors = Checks.evaluate_checks(checks, assigns.surface.data_model, assigns.scope_path, opts)

    assigns =
      assign(assigns,
        label: label,
        html_value: html_value,
        input_type: input_type,
        path: path,
        step: step,
        errors: errors
      )

    ~H"""
    <.form
      for={%{}}
      as={:a2ui_input}
      phx-change={!@suppress_events && "a2ui:datetime"}
      class="a2ui-datetime-input"
      id={component_dom_id(@surface.id, @id, @scope_path, "form")}
    >
      <input type="hidden" name="a2ui_input[surface_id]" value={@surface.id} />
      <input type="hidden" name="a2ui_input[path]" value={@path} />
      <input type="hidden" name="a2ui_input[input_type]" value={@input_type} />
      <div class="space-y-1">
        <label :if={@label} class="block text-sm font-medium text-zinc-700 dark:text-zinc-300">
          {@label}
        </label>
        <input
          type={@input_type}
          name="a2ui_input[value]"
          id={component_dom_id(@surface.id, @id, @scope_path, "input")}
          value={@html_value}
          step={@step}
          disabled={@suppress_events}
          class="block w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-zinc-900 shadow-sm outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50"
        />
        <p :for={error <- @errors} class="mt-1 text-sm text-rose-600 dark:text-rose-400">
          {error}
        </p>
      </div>
    </.form>
    """
  end

  @doc """
  MultipleChoice - selection from multiple options with optional max selections.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :id, :string, required: true
  attr :suppress_events, :boolean, default: false

  def a2ui_multiple_choice(assigns) do
    opts = binding_opts(assigns.surface)

    label =
      Binding.resolve(
        assigns.props["label"],
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    selections_prop = Adapter.choice_selections_prop(assigns.props)

    raw_selections =
      Binding.resolve(
        selections_prop,
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    selections =
      cond do
        is_list(raw_selections) -> raw_selections
        is_map(raw_selections) -> Map.values(raw_selections)
        true -> []
      end

    selections = Enum.filter(selections, &is_binary/1)

    options = assigns.props["options"] || []

    max_allowed = assigns.props["maxAllowedSelections"]

    is_single_select = Adapter.choice_single_select?(assigns.props)

    raw_path = Binding.get_path(selections_prop)
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path, opts), else: nil

    current_count = length(selections)
    max_reached = is_integer(max_allowed) and max_allowed > 1 and current_count >= max_allowed

    checks = assigns.props["checks"]
    errors = Checks.evaluate_checks(checks, assigns.surface.data_model, assigns.scope_path, opts)

    assigns =
      assign(assigns,
        label: label,
        selections: selections,
        options: options,
        max_allowed: max_allowed,
        path: path,
        is_single_select: is_single_select,
        max_reached: max_reached,
        binding_opts: opts,
        errors: errors
      )

    ~H"""
    <.form
      for={%{}}
      as={:a2ui_input}
      phx-change={!@suppress_events && "a2ui:choice"}
      class="a2ui-multiple-choice"
      id={component_dom_id(@surface.id, @id, @scope_path, "form")}
    >
      <input type="hidden" name="a2ui_input[surface_id]" value={@surface.id} />
      <input type="hidden" name="a2ui_input[path]" value={@path} />
      <input type="hidden" name="a2ui_input[max_allowed]" value={@max_allowed || ""} />
      <input type="hidden" name="a2ui_input[is_single]" value={to_string(@is_single_select)} />
      <%!-- Empty value sentinel for when nothing is selected --%>
      <input type="hidden" name="a2ui_input[values][]" value="" />
      <div class="space-y-2">
        <label :if={@label} class="block text-sm font-medium text-zinc-700 dark:text-zinc-300">
          {@label}
        </label>
        <%= for option <- @options do %>
          <% opt_label =
            Binding.resolve(option["label"], @surface.data_model, @scope_path, @binding_opts)

          opt_value = option["value"]
          opt_value = if is_binary(opt_value), do: opt_value, else: ""
          is_selected = opt_value != "" and opt_value in @selections
          is_disabled = @suppress_events or (@max_reached and not is_selected) %>
          <label class={[
            "flex items-center gap-2",
            if(is_disabled, do: "opacity-50 cursor-not-allowed", else: "cursor-pointer")
          ]}>
            <%= if @is_single_select do %>
              <input
                type="radio"
                name="a2ui_input[values][]"
                value={opt_value}
                checked={is_selected}
                disabled={is_disabled}
                class="size-4 border-zinc-300"
              />
            <% else %>
              <input
                type="checkbox"
                name="a2ui_input[values][]"
                value={opt_value}
                checked={is_selected}
                disabled={is_disabled}
                class="size-4 rounded border-zinc-300 disabled:opacity-50"
              />
            <% end %>
            <span class="text-sm text-zinc-900 dark:text-zinc-50">{opt_label}</span>
          </label>
        <% end %>
        <p :for={error <- @errors} class="mt-1 text-sm text-rose-600 dark:text-rose-400">
          {error}
        </p>
      </div>
    </.form>
    """
  end
end
