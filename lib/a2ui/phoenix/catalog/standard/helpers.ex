defmodule A2UI.Phoenix.Catalog.Standard.Helpers do
  @moduledoc false

  alias A2UI.Checks

  @doc """
  Renders simple markdown text to safe HTML.

  Per A2UI spec, this supports basic markdown formatting but strips:
  - HTML tags
  - Images
  - Links (converted to plain text)

  Supported: bold, italic, code, lists, blockquotes, headings.
  """
  def render_markdown(nil), do: ""
  def render_markdown(""), do: ""

  def render_markdown(text) when is_binary(text) do
    text
    |> Earmark.as_html!(
      compact_output: true,
      code_class_prefix: "a2ui-code-",
      smartypants: false
    )
    |> sanitize_markdown_html()
  end

  def render_markdown(other), do: to_string(other)

  # Sanitize markdown HTML output per A2UI spec:
  # - Strip <img> tags completely
  # - Convert <a> links to plain text (keep inner content)
  # - Strip any raw HTML that might have been in the source
  defp sanitize_markdown_html(html) do
    html
    # Remove image tags completely
    |> String.replace(~r/<img[^>]*>/i, "")
    # Convert links to plain text (keep the link text, remove the anchor)
    |> String.replace(~r/<a[^>]*>([^<]*)<\/a>/i, "\\1")
    # Remove dangerous tags with their content
    |> remove_dangerous_tags_with_content()
    # Remove any other potentially dangerous tags but keep safe ones
    |> sanitize_allowed_tags()
  end

  # Tags that should be removed along with their content
  @dangerous_tags_with_content ~w(script style iframe object embed form)

  defp remove_dangerous_tags_with_content(html) do
    Enum.reduce(@dangerous_tags_with_content, html, fn tag, acc ->
      # Remove opening/closing tag pairs with content
      acc
      |> String.replace(~r/<#{tag}[^>]*>.*?<\/#{tag}>/is, "")
      # Remove self-closing variants
      |> String.replace(~r/<#{tag}[^>]*\/?>/i, "")
    end)
  end

  # Allow only safe markdown-generated tags
  @allowed_tags ~w(p br strong em b i code pre ul ol li blockquote h1 h2 h3 h4 h5 h6 hr)

  defp sanitize_allowed_tags(html) do
    # Remove any tag that's not in our allowed list
    # This handles any raw HTML that was in the markdown source
    Regex.replace(
      ~r/<\/?([a-zA-Z][a-zA-Z0-9]*)[^>]*>/,
      html,
      fn full_match, tag_name ->
        if String.downcase(tag_name) in @allowed_tags do
          full_match
        else
          ""
        end
      end
    )
  end

  def flex_style(distribution, alignment) do
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

  def text_style("h1"),
    do:
      {"font-size: 2.25rem; font-weight: 700; letter-spacing: -0.025em;",
       "text-zinc-950 dark:text-zinc-50"}

  def text_style("h2"),
    do:
      {"font-size: 1.875rem; font-weight: 600; letter-spacing: -0.025em;",
       "text-zinc-950 dark:text-zinc-50"}

  def text_style("h3"),
    do: {"font-size: 1.5rem; font-weight: 600;", "text-zinc-950 dark:text-zinc-50"}

  def text_style("h4"),
    do: {"font-size: 1.25rem; font-weight: 600;", "text-zinc-950 dark:text-zinc-50"}

  def text_style("h5"),
    do: {"font-size: 1.125rem; font-weight: 500;", "text-zinc-950 dark:text-zinc-50"}

  def text_style("caption"), do: {"font-size: 0.875rem;", "text-zinc-600 dark:text-zinc-400"}
  def text_style("body"), do: {"font-size: 1rem;", "text-zinc-900 dark:text-zinc-50"}
  def text_style(_), do: {"font-size: 1rem;", "text-zinc-900 dark:text-zinc-50"}

  def divider_style(axis, thickness, color) do
    thickness_px = parse_thickness(thickness)
    bg_color = parse_color(color) || "#a1a1aa"

    case axis do
      "vertical" ->
        "height: 100%; min-height: 2rem; width: #{thickness_px}px; background-color: #{bg_color};"

      _ ->
        "height: #{thickness_px}px; width: 100%; background-color: #{bg_color}; margin: 0.75rem 0;"
    end
  end

  def parse_thickness(nil), do: 2
  def parse_thickness(n) when is_number(n), do: max(1, n)

  def parse_thickness(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> max(1, n)
      :error -> 2
    end
  end

  def parse_thickness(_), do: 2

  def parse_color(nil), do: nil

  def parse_color(<<"#", rest::binary>> = color) when byte_size(rest) in [3, 6] do
    if String.match?(rest, ~r/^[0-9a-fA-F]+$/) do
      color
    else
      nil
    end
  end

  def parse_color(_), do: nil

  def button_classes(primary, disabled)

  def button_classes(true, true) do
    "a2ui-button-primary inline-flex items-center justify-center rounded-lg px-3 py-2 text-sm font-semibold text-white shadow-sm transition opacity-50 cursor-not-allowed"
  end

  def button_classes(true, false) do
    "a2ui-button-primary inline-flex items-center justify-center rounded-lg px-3 py-2 text-sm font-semibold text-white shadow-sm transition"
  end

  def button_classes(false, true) do
    "a2ui-button-secondary inline-flex items-center justify-center rounded-lg bg-zinc-100 px-3 py-2 text-sm font-semibold text-zinc-400 shadow-sm ring-1 ring-inset ring-zinc-200 cursor-not-allowed dark:bg-zinc-800 dark:text-zinc-500 dark:ring-zinc-700"
  end

  def button_classes(false, false) do
    "a2ui-button-secondary inline-flex items-center justify-center rounded-lg bg-white px-3 py-2 text-sm font-semibold text-zinc-900 shadow-sm ring-1 ring-inset ring-zinc-200 transition hover:bg-zinc-50 active:bg-zinc-100 dark:bg-zinc-900 dark:text-zinc-50 dark:ring-zinc-800 dark:hover:bg-zinc-800"
  end

  def input_type("number"), do: "number"
  def input_type("date"), do: "date"
  def input_type("email"), do: "email"
  def input_type("obscured"), do: "password"
  def input_type("password"), do: "password"
  def input_type("longText"), do: "textarea"
  def input_type(_), do: "text"

  def image_size_style("icon"), do: {"shrink-0", "width: 24px; height: 24px;"}
  def image_size_style("avatar"), do: {"shrink-0 rounded-full", "width: 40px; height: 40px;"}
  def image_size_style("smallFeature"), do: {"w-full", "aspect-ratio: 4/3; max-width: 128px;"}
  def image_size_style("mediumFeature"), do: {"w-full", "aspect-ratio: 4/3; max-width: 256px;"}
  def image_size_style("largeFeature"), do: {"w-full", "aspect-ratio: 4/3; max-width: 384px;"}
  def image_size_style("header"), do: {"w-full", "height: 128px;"}
  def image_size_style(_), do: {"w-full", ""}

  def list_flex_direction("horizontal"), do: "row"
  def list_flex_direction(_), do: "column"

  def list_alignment_style("start"), do: "align-items: flex-start;"
  def list_alignment_style("center"), do: "align-items: center;"
  def list_alignment_style("end"), do: "align-items: flex-end;"
  def list_alignment_style(_), do: "align-items: stretch;"

  def iso8601_to_html_datetime(nil, _type), do: ""
  def iso8601_to_html_datetime("", _type), do: ""

  def iso8601_to_html_datetime(iso_string, "date") when is_binary(iso_string) do
    maybe_date = String.slice(iso_string, 0, 10)

    case Date.from_iso8601(maybe_date) do
      {:ok, _} -> maybe_date
      _ -> ""
    end
  end

  def iso8601_to_html_datetime(iso_string, "time") when is_binary(iso_string) do
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

  def iso8601_to_html_datetime(iso_string, "datetime-local") when is_binary(iso_string) do
    naive =
      iso_string
      |> String.replace(~r/Z$/, "")
      |> String.replace(~r/[+-]\d{2}:\d{2}$/, "")

    case Regex.run(~r/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}(?::\d{2})?)/, naive) do
      [_, date, time] -> "#{date}T#{time}"
      _ -> ""
    end
  end

  def iso8601_to_html_datetime(_, _), do: ""

  def validate_text_field(_text, nil), do: true
  def validate_text_field("", _regexp), do: true

  def validate_text_field(text, regexp) when is_binary(regexp) do
    case Regex.compile(regexp) do
      {:ok, regex} -> Regex.match?(regex, text)
      {:error, _} -> true
    end
  end

  def validate_text_field(_, _), do: true

  def build_text_field_errors(text, validation_regexp, checks, data_model, scope_path, opts) do
    errors = []

    errors =
      if validation_regexp != nil and text != "" and
           not validate_text_field(text, validation_regexp) do
        ["Invalid format" | errors]
      else
        errors
      end

    checks_with_value = inject_implicit_value(checks, text)
    check_errors = Checks.evaluate_checks(checks_with_value, data_model, scope_path, opts)
    errors ++ check_errors
  end

  def inject_implicit_value(nil, _value), do: nil

  def inject_implicit_value(checks, value) when is_list(checks) do
    Enum.map(checks, fn check ->
      inject_check_value(check, value)
    end)
  end

  def inject_check_value(%{"call" => _} = check, value) do
    args = check["args"] || %{}

    if Map.has_key?(args, "value") do
      check
    else
      Map.put(check, "args", Map.put(args, "value", value))
    end
  end

  def inject_check_value(check, _value), do: check

  def component_dom_id(surface_id, component_id, scope_path, suffix \\ nil) do
    base = "a2ui-#{surface_id}-#{component_id}"

    base =
      case scope_dom_suffix(scope_path) do
        nil -> base
        scope_suffix -> base <> "-s" <> scope_suffix
      end

    if suffix, do: base <> "-" <> suffix, else: base
  end

  def scope_dom_suffix(nil), do: nil
  def scope_dom_suffix(""), do: nil

  def scope_dom_suffix(scope_path) when is_binary(scope_path) do
    scope_path
    |> :erlang.phash2()
    |> Integer.to_string(36)
  end

  def component_weight(surface, component_id) do
    component = surface.components[component_id]

    case component && component.weight do
      weight when is_number(weight) -> weight
      _ -> nil
    end
  end

  def stable_template_keys(map) when is_map(map) do
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

  def numeric_string?(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 -> true
      _ -> false
    end
  end

  def numeric_string?(_), do: false

  def binding_opts(surface) do
    version = surface.protocol_version || :v0_8
    [version: version]
  end
end
