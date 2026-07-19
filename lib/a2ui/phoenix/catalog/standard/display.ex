defmodule A2UI.Phoenix.Catalog.Standard.Display do
  @moduledoc false

  use Phoenix.Component

  import A2UI.Phoenix.Components, only: [icon: 1]
  import A2UI.Phoenix.Catalog.Standard.Helpers

  alias A2UI.Binding
  alias A2UI.Props.Adapter

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
    "fastForward" => "hero-forward",
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
    "pause" => "hero-pause",
    "payment" => "hero-credit-card",
    "person" => "hero-user",
    "phone" => "hero-phone",
    "photo" => "hero-photo",
    "play" => "hero-play",
    "print" => "hero-printer",
    "refresh" => "hero-arrow-path",
    "rewind" => "hero-backward",
    "schedule" => "hero-clock",
    "search" => "hero-magnifying-glass",
    "send" => "hero-paper-airplane",
    "settings" => "hero-cog-6-tooth",
    "share" => "hero-share",
    "shoppingCart" => "hero-shopping-cart",
    "skipNext" => "hero-forward",
    "skipPrevious" => "hero-backward",
    "star" => "hero-star-solid",
    "starHalf" => "hero-star",
    "starOff" => "hero-star",
    "stop" => "hero-stop",
    "upload" => "hero-arrow-up-tray",
    "visibility" => "hero-eye",
    "visibilityOff" => "hero-eye-slash",
    "volumeDown" => "hero-speaker-wave",
    "volumeMute" => "hero-speaker-x-mark",
    "volumeOff" => "hero-speaker-x-mark",
    "volumeUp" => "hero-speaker-wave",
    "warning" => "hero-exclamation-triangle"
  }

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_text(assigns) do
    opts = binding_opts(assigns.surface)

    text =
      Binding.resolve(assigns.props["text"], assigns.surface.data_model, assigns.scope_path, opts)

    # Get variant without default - nil means no variant specified
    variant = Adapter.variant_prop(assigns.props)

    rendered_html = render_markdown(text)

    if variant == nil do
      assigns = assign(assigns, rendered_html: rendered_html)

      ~H"""
      <div class="a2ui-text-markdown">
        {Phoenix.HTML.raw(@rendered_html)}
      </div>
      """
    else
      {style, class} = text_style(variant)
      assigns = assign(assigns, rendered_html: rendered_html, style: style, class: class)

      ~H"""
      <div class={["a2ui-text-markdown", @class]} style={@style}>
        {Phoenix.HTML.raw(@rendered_html)}
      </div>
      """
    end
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

    {hero_name, svg_path} =
      case name do
        %{"svgPath" => path} when is_binary(path) -> {nil, path}
        icon_name when is_binary(icon_name) -> {Map.get(@icon_mapping, icon_name), nil}
        _ -> {nil, nil}
      end

    assigns = assign(assigns, hero_name: hero_name, svg_path: svg_path)

    ~H"""
    <svg
      :if={@svg_path}
      class="a2ui-icon size-5 text-current"
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d={@svg_path} />
    </svg>
    <.icon :if={@hero_name} name={@hero_name} class="a2ui-icon size-5 text-current" />
    """
  end

  @doc """
  Image - displays an image with optional fit and usage hint.
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_image(assigns) do
    opts = binding_opts(assigns.surface)

    raw_url =
      Binding.resolve(assigns.props["url"], assigns.surface.data_model, assigns.scope_path, opts)

    url = A2UI.Validator.sanitize_media_url(raw_url)
    released? = assigns.surface.protocol_version in [:v0_9, :v0_9_1]
    fit = assigns.props["fit"] || if(released?, do: "fill", else: "contain")
    hint = Adapter.variant_prop(assigns.props) || if(released?, do: "mediumFeature")
    {wrapper_class, wrapper_style} = image_size_style(hint)

    description =
      Binding.resolve(
        assigns.props["description"],
        assigns.surface.data_model,
        assigns.scope_path,
        opts
      )

    assigns =
      assign(assigns,
        url: url,
        fit: fit,
        wrapper_class: wrapper_class,
        wrapper_style: wrapper_style,
        description: description || ""
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
          alt={@description}
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
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_audio_player(assigns) do
    opts = binding_opts(assigns.surface)

    raw_url =
      Binding.resolve(assigns.props["url"], assigns.surface.data_model, assigns.scope_path, opts)

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
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_video(assigns) do
    opts = binding_opts(assigns.surface)

    raw_url =
      Binding.resolve(assigns.props["url"], assigns.surface.data_model, assigns.scope_path, opts)

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
end
