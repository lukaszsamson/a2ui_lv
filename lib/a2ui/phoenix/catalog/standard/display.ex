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

  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_text(assigns) do
    opts = binding_opts(assigns.surface)

    text =
      Binding.resolve(assigns.props["text"], assigns.surface.data_model, assigns.scope_path, opts)

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
  """
  attr :props, :map, required: true
  attr :surface, :map, required: true
  attr :scope_path, :string, default: nil

  def a2ui_image(assigns) do
    opts = binding_opts(assigns.surface)

    raw_url =
      Binding.resolve(assigns.props["url"], assigns.surface.data_model, assigns.scope_path, opts)

    url = A2UI.Validator.sanitize_media_url(raw_url)
    fit = assigns.props["fit"] || "contain"
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
