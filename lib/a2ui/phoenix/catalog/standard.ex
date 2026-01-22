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
  import A2UI.Phoenix.Components, only: [input: 1, icon: 1]
  alias A2UI.{Binding, Checks}
  alias A2UI.Props.Adapter

  # A2UI standard icon names mapped to Heroicons
  @icon_mapping %{
    "accountCircle" => "hero-user-circle",
    "add" => "hero-plus",
    "arrowBack" => "hero-arrow-left",
    "arrowForward" => "hero-arrow-right",
    "attachFile" => "hero-paper-clip",
    "calendarToday" => "hero-calendar",
    "call" => "hero-phone",
    "camera" => "hero-camera",
    "check" => "hero-check",
    "close" => "hero-x-mark",
    "delete" => "hero-trash",
    "download" => "hero-arrow-down-tray",
    "edit" => "hero-pencil",
    "event" => "hero-calendar-days",
    "error" => "hero-exclamation-circle",
    "favorite" => "hero-heart-solid",
    "favoriteOff" => "hero-heart",
    "flight" => "hero-paper-airplane",
    "folder" => "hero-folder",
    "help" => "hero-question-mark-circle",
    "home" => "hero-home",
    "info" => "hero-information-circle",
    "locationOn" => "hero-map-pin",
    "lock" => "hero-lock-closed",
    "lockOpen" => "hero-lock-open",
    "mail" => "hero-envelope",
    "menu" => "hero-bars-3",
    "moreVert" => "hero-ellipsis-vertical",
    "moreHoriz" => "hero-ellipsis-horizontal",
    "notifications" => "hero-bell",
    "notificationsOff" => "hero-bell-slash",
    "payment" => "hero-credit-card",
    "person" => "hero-user",
    "phone" => "hero-phone",
    "photo" => "hero-photo",
    "print" => "hero-printer",
    "refresh" => "hero-arrow-path",
    "schedule" => "hero-clock",
    "search" => "hero-magnifying-glass",
    "send" => "hero-paper-airplane",
    "settings" => "hero-cog-6-tooth",
    "share" => "hero-share",
    "shoppingCart" => "hero-shopping-cart",
    "star" => "hero-star-solid",
    "starHalf" => "hero-star",
    "starOff" => "hero-star",
    "upload" => "hero-arrow-up-tray",
    "visibility" => "hero-eye",
    "visibilityOff" => "hero-eye-slash",
    "warning" => "hero-exclamation-triangle"
  }

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

  Cycle detection: The `visited` attribute tracks component IDs seen in the
  current render path. If a component references itself directly or indirectly,
  a cycle error is displayed instead of infinite recursion.
  """
  attr :id, :string, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :depth, :integer, default: 0
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def render_component(assigns) do
    component = assigns.surface.components[assigns.id]
    # Initialize visited set if nil (first render in this path)
    visited = assigns.visited || A2UI.Validator.new_visited()

    # Check for cycles before rendering
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
          # Track this component as visited for child renders
          new_visited = A2UI.Validator.track_visited(assigns.id, visited)
          assigns = assign(assigns, component: component, visited: new_visited)

          # Use display:contents to not break flex layout while keeping the wrapper for debugging
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
                  <%!-- v0.9 renamed MultipleChoice to ChoicePicker --%>
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
                <% unknown -> %>
                  <.a2ui_unknown type={unknown} />
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
  # Layout Components
  # ============================================

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil
  attr :depth, :integer, default: 0
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def a2ui_column(assigns) do
    # Support both v0.8 (distribution/alignment) and v0.9 (justify/align)
    {justify, align} = Adapter.row_column_props(assigns.props, "stretch")
    assigns = assign(assigns, distribution: justify, alignment: align)

    ~H"""
    <div
      class="a2ui-column"
      style={"display: flex; flex-direction: column; gap: 0.5rem; width: 100%; #{flex_style(@distribution, @alignment)}"}
    >
      <.render_children
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
    # Support both v0.8 (distribution/alignment) and v0.9 (justify/align)
    {justify, align} = Adapter.row_column_props(assigns.props, "center")
    # Row needs full width for all distributions except "start" (which can be content-sized)
    needs_full_width = justify != "start"
    width_style = if needs_full_width, do: "width: 100%;", else: ""

    assigns =
      assign(assigns, distribution: justify, alignment: align, width_style: width_style)

    ~H"""
    <div
      class="a2ui-row"
      style={"display: flex; flex-direction: row; gap: 0.5rem; #{@width_style} #{flex_style(@distribution, @alignment)}"}
    >
      <.render_children
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
      <.render_component
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

  # ============================================
  # Display Components
  # ============================================

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_text(assigns) do
    opts = binding_opts(assigns.surface)

    text =
      Binding.resolve(assigns.props["text"], assigns.surface.data_model, assigns.scope_path, opts)

    # Support both v0.8 (usageHint) and v0.9 (variant)
    hint = Adapter.variant_prop(assigns.props, "body")
    {style, class} = text_style(hint)
    assigns = assign(assigns, text: text, style: style, class: class)

    ~H"""
    <span class={@class} style={@style}>{@text}</span>
    """
  end

  attr :props, :map, required: true

  def a2ui_divider(assigns) do
    axis = assigns.props["axis"] || "horizontal"
    thickness = assigns.props["thickness"]
    color = assigns.props["color"]
    assigns = assign(assigns, axis: axis, thickness: thickness, color: color)

    ~H"""
    <div style={divider_style(@axis, @thickness, @color)} />
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
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def a2ui_button(assigns) do
    opts = binding_opts(assigns.surface)
    primary = assigns.props["primary"] || false
    has_action = assigns.props["action"] != nil and not assigns.suppress_events

    # v0.9 checks: evaluate to determine if button should be disabled
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
      <.render_component
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

  Per DESIGN_V1.md: Uses the project's `<.input>` component from
  core_components.ex. Wraps in a form with phx-change for proper
  LiveView form handling.
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

    # Support both v0.8 "text" and v0.9 "value" props
    value_prop = Adapter.text_field_value_prop(assigns.props)
    text = Binding.resolve(value_prop, assigns.surface.data_model, assigns.scope_path, opts)
    # Support both v0.8 "textFieldType" and v0.9 "variant"
    field_type = Adapter.text_field_type_prop(assigns.props)

    # Get absolute path for binding (expand if relative)
    raw_path = Binding.get_path(value_prop)
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path, opts), else: nil

    # Build error messages from v0.8 validationRegexp and/or v0.9 checks
    validation_regexp = assigns.props["validationRegexp"]
    checks = assigns.props["checks"]
    errors = build_text_field_errors(text || "", validation_regexp, checks, assigns.surface.data_model, assigns.scope_path, opts)

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
        label={@label}
        value={@text}
        type={input_type(@field_type)}
        phx-debounce="300"
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

    # Get absolute path for binding
    raw_path = Binding.get_path(assigns.props["value"])
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path, opts), else: nil

    # v0.9 checks
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

  # ============================================
  # New Display Components (v0.8 Catalog)
  # ============================================

  @doc """
  Icon - displays a standard icon from the A2UI icon set.
  Maps A2UI icon names to Heroicons.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_icon(assigns) do
    opts = binding_opts(assigns.surface)

    name =
      Binding.resolve(assigns.props["name"], assigns.surface.data_model, assigns.scope_path, opts)

    hero_name = Map.get(@icon_mapping, name, "hero-question-mark-circle")
    assigns = assign(assigns, hero_name: hero_name)

    ~H"""
    <.icon name={@hero_name} class="a2ui-icon size-5" />
    """
  end

  @doc """
  Image - displays an image with optional fit and usage hint.

  URL validation: Only allows safe URL schemes (https, http, data, blob).
  Unsafe schemes like javascript: are rejected for security.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_image(assigns) do
    opts = binding_opts(assigns.surface)

    raw_url =
      Binding.resolve(assigns.props["url"], assigns.surface.data_model, assigns.scope_path, opts)

    # Sanitize URL - returns nil for unsafe schemes
    url = A2UI.Validator.sanitize_media_url(raw_url)
    fit = assigns.props["fit"] || "contain"
    # Support both v0.8 (usageHint) and v0.9 (variant)
    hint = Adapter.variant_prop(assigns.props)
    {wrapper_class, wrapper_style} = image_size_style(hint)

    assigns =
      assign(assigns,
        url: url,
        fit: fit,
        wrapper_class: wrapper_class,
        wrapper_style: wrapper_style
      )

    ~H"""
    <div
      class={[
        "a2ui-image-wrapper overflow-hidden bg-zinc-200 dark:bg-zinc-700",
        @wrapper_class
      ]}
      style={@wrapper_style}
    >
      <%= if @url do %>
        <img
          src={@url}
          class="a2ui-image w-full h-full"
          style={"object-fit: #{@fit};"}
          loading="lazy"
        />
      <% else %>
        <div class="flex h-full w-full items-center justify-center text-zinc-400 dark:text-zinc-500">
          <.icon name="hero-photo" class="size-8" />
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  AudioPlayer - HTML5 audio player with optional description.

  URL validation: Only allows safe URL schemes (https, http, data, blob).
  Unsafe schemes like javascript: are rejected for security.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_audio_player(assigns) do
    opts = binding_opts(assigns.surface)

    raw_url =
      Binding.resolve(assigns.props["url"], assigns.surface.data_model, assigns.scope_path, opts)

    # Sanitize URL - returns nil for unsafe schemes
    url = A2UI.Validator.sanitize_media_url(raw_url)

    description =
      Binding.resolve(
        assigns.props["description"],
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    assigns = assign(assigns, url: url, description: description)

    ~H"""
    <div class="a2ui-audio-player">
      <p :if={@description} class="mb-2 text-sm text-zinc-600 dark:text-zinc-400">{@description}</p>
      <%= if @url do %>
        <audio controls class="w-full">
          <source src={@url} /> Your browser does not support the audio element.
        </audio>
      <% else %>
        <div class="flex items-center gap-2 rounded-lg bg-zinc-100 p-3 text-sm text-zinc-500 dark:bg-zinc-800 dark:text-zinc-400">
          <.icon name="hero-musical-note" class="size-5" />
          <span>Invalid audio URL</span>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Video - HTML5 video player.

  URL validation: Only allows safe URL schemes (https, http, data, blob).
  Unsafe schemes like javascript: are rejected for security.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_video(assigns) do
    opts = binding_opts(assigns.surface)

    raw_url =
      Binding.resolve(assigns.props["url"], assigns.surface.data_model, assigns.scope_path, opts)

    # Sanitize URL - returns nil for unsafe schemes
    url = A2UI.Validator.sanitize_media_url(raw_url)
    assigns = assign(assigns, url: url)

    ~H"""
    <%= if @url do %>
      <video controls class="a2ui-video w-full rounded-lg">
        <source src={@url} /> Your browser does not support the video element.
      </video>
    <% else %>
      <div class="flex items-center justify-center rounded-lg bg-zinc-100 p-6 text-zinc-500 dark:bg-zinc-800 dark:text-zinc-400">
        <div class="flex flex-col items-center gap-2">
          <.icon name="hero-video-camera-slash" class="size-8" />
          <span class="text-sm">Invalid video URL</span>
        </div>
      </div>
    <% end %>
    """
  end

  # ============================================
  # New Two-Way Binding Components (v0.8 Catalog)
  # ============================================

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

    # Support both v0.8 "minValue"/"maxValue" and v0.9 "min"/"max"
    {min_val, max_val} = Adapter.slider_range_props(assigns.props)

    # Get absolute path for binding
    raw_path = Binding.get_path(assigns.props["value"])
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path, opts), else: nil

    # v0.9 checks
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

    # Determine input type based on flags
    input_type =
      cond do
        enable_date and enable_time -> "datetime-local"
        enable_date -> "date"
        enable_time -> "time"
        true -> "datetime-local"
      end

    # Convert ISO 8601 to HTML input format
    html_value = iso8601_to_html_datetime(value, input_type)

    step =
      case input_type do
        "time" -> "1"
        "datetime-local" -> "1"
        _ -> nil
      end

    # Get absolute path for binding
    raw_path = Binding.get_path(assigns.props["value"])
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path, opts), else: nil

    # v0.9 checks
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

    # Support both v0.8 "selections" and v0.9 "value" props
    selections_prop = Adapter.choice_selections_prop(assigns.props)

    raw_selections =
      Binding.resolve(
        selections_prop,
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    # Ensure selections is a list (it might come as a map or nil)
    selections =
      cond do
        is_list(raw_selections) -> raw_selections
        is_map(raw_selections) -> Map.values(raw_selections)
        true -> []
      end

    selections = Enum.filter(selections, &is_binary/1)

    options = assigns.props["options"] || []

    # v0.9 uses "variant" ("mutuallyExclusive" or "multipleSelection")
    # v0.8 uses "maxAllowedSelections" (1 = single select)
    max_allowed = assigns.props["maxAllowedSelections"]

    # Determine if this should be radio (single select) or checkbox (multi select)
    is_single_select = Adapter.choice_single_select?(assigns.props)

    # Get absolute path for binding
    raw_path = Binding.get_path(selections_prop)
    path = if raw_path, do: Binding.expand_path(raw_path, assigns.scope_path, opts), else: nil

    # Check if max selections reached (for disabling unchecked boxes)
    current_count = length(selections)
    max_reached = is_integer(max_allowed) and max_allowed > 1 and current_count >= max_allowed

    # v0.9 checks
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
          # Disable if max reached and not already selected
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

  # ============================================
  # New Container Components (v0.8 Catalog)
  # ============================================

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
      <.render_children
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
    # Support both v0.8 (tabItems) and v0.9 (tabs)
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
            <.render_component
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
    # Support both v0.8 (entryPointChild/contentChild) and v0.9 (trigger/content)
    {entry_point_child, content_child} = Adapter.modal_props(assigns.props)
    dialog_id = component_dom_id(assigns.surface.id, assigns.id, assigns.scope_path, "dialog")

    # Build the JS commands for opening/closing the modal
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
        <.render_component
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
            <.render_component
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
  attr :apply_weight, :boolean, default: false
  attr :suppress_events, :boolean, default: false
  attr :visited, :any, default: nil

  def render_children(assigns) do
    children_spec = assigns.props["children"]

    cond do
      # Explicit list of component IDs
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

      # Template (dynamic list from data binding)
      is_map(children_spec) && Map.has_key?(children_spec, "template") ->
        template = children_spec["template"]
        data_binding = template["dataBinding"]
        template_id = template["componentId"]

        # Compute base path for template items (version-aware expansion)
        base_path =
          Binding.expand_path(data_binding, assigns.scope_path, binding_opts(assigns.surface))

        collection = Binding.get_at_pointer(assigns.surface.data_model, base_path)
        max_items = A2UI.Validator.max_template_items()
        template_weight = assigns.apply_weight && component_weight(assigns.surface, template_id)

        cond do
          # v0.9 semantics: collections are native JSON arrays
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

          # v0.8 wire schema produced maps with numeric string keys:
          # {"0": item0, "1": item1, ...}
          # The stable_template_keys function sorts numeric keys numerically.
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

  # Returns {inline_style, class} for text styling
  # Using inline styles for font-size to avoid Tailwind JIT issues
  defp text_style("h1"),
    do:
      {"font-size: 2.25rem; font-weight: 700; letter-spacing: -0.025em;",
       "text-zinc-950 dark:text-zinc-50"}

  defp text_style("h2"),
    do:
      {"font-size: 1.875rem; font-weight: 600; letter-spacing: -0.025em;",
       "text-zinc-950 dark:text-zinc-50"}

  defp text_style("h3"),
    do: {"font-size: 1.5rem; font-weight: 600;", "text-zinc-950 dark:text-zinc-50"}

  defp text_style("h4"),
    do: {"font-size: 1.25rem; font-weight: 600;", "text-zinc-950 dark:text-zinc-50"}

  defp text_style("h5"),
    do: {"font-size: 1.125rem; font-weight: 500;", "text-zinc-950 dark:text-zinc-50"}

  defp text_style("caption"), do: {"font-size: 0.875rem;", "text-zinc-600 dark:text-zinc-400"}
  defp text_style("body"), do: {"font-size: 1rem;", "text-zinc-900 dark:text-zinc-50"}
  defp text_style(_), do: {"font-size: 1rem;", "text-zinc-900 dark:text-zinc-50"}

  defp divider_style(axis, thickness, color) do
    thickness_px = parse_thickness(thickness)
    bg_color = parse_color(color) || "#a1a1aa"

    case axis do
      "vertical" ->
        "height: 100%; min-height: 2rem; width: #{thickness_px}px; background-color: #{bg_color};"

      _ ->
        "height: #{thickness_px}px; width: 100%; background-color: #{bg_color}; margin: 0.75rem 0;"
    end
  end

  defp parse_thickness(nil), do: 2
  defp parse_thickness(n) when is_number(n), do: max(1, n)

  defp parse_thickness(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> max(1, n)
      :error -> 2
    end
  end

  defp parse_thickness(_), do: 2

  # Only allow safe hex colors
  defp parse_color(nil), do: nil

  defp parse_color(<<"#", rest::binary>> = color) when byte_size(rest) in [3, 6] do
    if String.match?(rest, ~r/^[0-9a-fA-F]+$/) do
      color
    else
      nil
    end
  end

  defp parse_color(_), do: nil

  defp button_classes(primary, disabled)

  defp button_classes(true, true) do
    "a2ui-button-primary inline-flex items-center justify-center rounded-lg px-3 py-2 text-sm font-semibold text-white shadow-sm transition opacity-50 cursor-not-allowed"
  end

  defp button_classes(true, false) do
    "a2ui-button-primary inline-flex items-center justify-center rounded-lg px-3 py-2 text-sm font-semibold text-white shadow-sm transition"
  end

  defp button_classes(false, true) do
    "a2ui-button-secondary inline-flex items-center justify-center rounded-lg bg-zinc-100 px-3 py-2 text-sm font-semibold text-zinc-400 shadow-sm ring-1 ring-inset ring-zinc-200 cursor-not-allowed dark:bg-zinc-800 dark:text-zinc-500 dark:ring-zinc-700"
  end

  defp button_classes(false, false) do
    "a2ui-button-secondary inline-flex items-center justify-center rounded-lg bg-white px-3 py-2 text-sm font-semibold text-zinc-900 shadow-sm ring-1 ring-inset ring-zinc-200 transition hover:bg-zinc-50 active:bg-zinc-100 dark:bg-zinc-900 dark:text-zinc-50 dark:ring-zinc-800 dark:hover:bg-zinc-800"
  end

  defp input_type("number"), do: "number"
  defp input_type("date"), do: "date"
  defp input_type("obscured"), do: "password"
  defp input_type("longText"), do: "textarea"
  defp input_type(_), do: "text"

  # Image sizing classes based on usageHint
  # Using fixed width AND height so object-fit differences are visible
  # Returns {inline_style, extra_classes} for image wrapper sizing
  # Using inline styles to prevent flex containers from overriding dimensions
  # Returns {class, style} for image wrapper
  # icon/avatar use fixed sizes, others fill container width with aspect ratio hints
  defp image_size_style("icon"), do: {"shrink-0", "width: 24px; height: 24px;"}
  defp image_size_style("avatar"), do: {"shrink-0 rounded-full", "width: 40px; height: 40px;"}
  defp image_size_style("smallFeature"), do: {"w-full", "aspect-ratio: 4/3; max-width: 128px;"}
  defp image_size_style("mediumFeature"), do: {"w-full", "aspect-ratio: 4/3; max-width: 256px;"}
  defp image_size_style("largeFeature"), do: {"w-full", "aspect-ratio: 4/3; max-width: 384px;"}
  defp image_size_style("header"), do: {"w-full", "height: 128px;"}
  # No hint: fill container, auto height based on image
  defp image_size_style(_), do: {"w-full", ""}

  # List component helpers
  defp list_flex_direction("horizontal"), do: "row"
  defp list_flex_direction(_), do: "column"

  defp list_alignment_style("start"), do: "align-items: flex-start;"
  defp list_alignment_style("center"), do: "align-items: center;"
  defp list_alignment_style("end"), do: "align-items: flex-end;"
  defp list_alignment_style(_), do: "align-items: stretch;"

  # DateTime conversion helpers
  defp iso8601_to_html_datetime(nil, _type), do: ""
  defp iso8601_to_html_datetime("", _type), do: ""

  defp iso8601_to_html_datetime(iso_string, "date") when is_binary(iso_string) do
    maybe_date = String.slice(iso_string, 0, 10)

    case Date.from_iso8601(maybe_date) do
      {:ok, _} -> maybe_date
      _ -> ""
    end
  end

  defp iso8601_to_html_datetime(iso_string, "time") when is_binary(iso_string) do
    time_part =
      case String.split(iso_string, "T", parts: 2) do
        [_, t] -> t
        _ -> iso_string
      end

    time_part =
      time_part
      |> String.replace(~r/Z$/, "")
      |> String.replace(~r/[+-]\d{2}:\d{2}$/, "")

    case Regex.run(~r/^(\d{2}):(\d{2})(?::(\d{2}))?/, time_part) do
      [_, h, m, s] when is_binary(s) -> "#{h}:#{m}:#{s}"
      [_, h, m] -> "#{h}:#{m}"
      _ -> ""
    end
  end

  defp iso8601_to_html_datetime(iso_string, "datetime-local") when is_binary(iso_string) do
    naive =
      iso_string
      |> String.replace(~r/Z$/, "")
      |> String.replace(~r/[+-]\d{2}:\d{2}$/, "")

    case Regex.run(~r/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}(?::\d{2})?)/, naive) do
      [_, date, time] -> "#{date}T#{time}"
      _ -> ""
    end
  end

  defp iso8601_to_html_datetime(_, _), do: ""

  # TextField validation helper
  defp validate_text_field(_text, nil), do: true
  defp validate_text_field("", _regexp), do: true

  defp validate_text_field(text, regexp) when is_binary(regexp) do
    case Regex.compile(regexp) do
      {:ok, regex} -> Regex.match?(regex, text)
      {:error, _} -> true
    end
  end

  defp validate_text_field(_, _), do: true

  # Builds error list from v0.8 validationRegexp and/or v0.9 checks
  defp build_text_field_errors(text, validation_regexp, checks, data_model, scope_path, opts) do
    errors = []

    # v0.8: validationRegexp produces "Invalid format" error
    errors =
      if validation_regexp != nil and text != "" and not validate_text_field(text, validation_regexp) do
        ["Invalid format" | errors]
      else
        errors
      end

    # v0.9: checks produce their message when failing
    check_errors = Checks.evaluate_checks(checks, data_model, scope_path, opts)
    errors ++ check_errors
  end

  defp component_dom_id(surface_id, component_id, scope_path, suffix \\ nil) do
    base = "a2ui-#{surface_id}-#{component_id}"

    base =
      case scope_dom_suffix(scope_path) do
        nil -> base
        scope_suffix -> base <> "-s" <> scope_suffix
      end

    if suffix, do: base <> "-" <> suffix, else: base
  end

  defp scope_dom_suffix(nil), do: nil
  defp scope_dom_suffix(""), do: nil

  defp scope_dom_suffix(scope_path) when is_binary(scope_path) do
    scope_path
    |> :erlang.phash2()
    |> Integer.to_string(36)
  end

  defp component_weight(surface, component_id) do
    component = surface.components[component_id]

    case component && component.weight do
      weight when is_number(weight) -> weight
      _ -> nil
    end
  end

  defp stable_template_keys(map) when is_map(map) do
    keys = Map.keys(map)

    if Enum.all?(keys, &numeric_string?/1) do
      keys
      |> Enum.map(fn key -> {key, String.to_integer(key)} end)
      |> Enum.sort_by(fn {_key, int} -> int end)
      |> Enum.map(fn {key, _int} -> key end)
    else
      Enum.sort_by(keys, &to_string/1)
    end
  end

  defp numeric_string?(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 -> true
      _ -> false
    end
  end

  defp numeric_string?(_), do: false

  # Returns binding options based on the surface's protocol version.
  # This affects how paths are scoped in templates:
  # - v0.8: `/path` is scoped in template context
  # - v0.9: `/path` is absolute even in template context
  defp binding_opts(surface) do
    version = surface.protocol_version || :v0_8
    [version: version]
  end
end
