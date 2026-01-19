defmodule A2UI.Props.Adapter do
  @moduledoc """
  Adapts v0.9 component props to the internal format expected by the catalog.

  The A2UI v0.9 spec renamed several component properties. This adapter module
  provides functions to normalize props from either version to a canonical
  internal format, allowing the catalog to work with both versions seamlessly.

  ## Property Renames (v0.8 → v0.9)

  | Component      | v0.8 prop          | v0.9 prop   |
  |----------------|--------------------|-------------|
  | Row/Column     | distribution       | justify     |
  | Row/Column     | alignment          | align       |
  | Modal          | entryPointChild    | trigger     |
  | Modal          | contentChild       | content     |
  | Tabs           | tabItems           | tabs        |
  | TextField      | text               | value       |
  | TextField      | textFieldType      | variant     |
  | Slider         | minValue           | min         |
  | Slider         | maxValue           | max         |
  | MultipleChoice | selections         | value       |
  | Many           | usageHint          | variant     |

  ## Usage

  In catalog components, use the adapter to get normalized values:

      # Row/Column
      {justify, align} = Adapter.row_column_props(props)

      # Modal
      {trigger, content} = Adapter.modal_props(props)

      # Tabs
      tabs = Adapter.tabs_props(props)

      # Text/Image
      variant = Adapter.variant_prop(props)
  """

  @doc """
  Extracts Row/Column layout props with v0.8/v0.9 compatibility.

  Returns `{justify, align}` tuple where:
  - `justify` is from v0.9 `justify` or v0.8 `distribution` (default: "start")
  - `align` is from v0.9 `align` or v0.8 `alignment` (default varies by component)

  ## Examples

      iex> A2UI.Props.Adapter.row_column_props(%{"justify" => "center", "align" => "end"})
      {"center", "end"}

      iex> A2UI.Props.Adapter.row_column_props(%{"distribution" => "spaceBetween", "alignment" => "center"})
      {"spaceBetween", "center"}

      iex> A2UI.Props.Adapter.row_column_props(%{"justify" => "center"}, "stretch")
      {"center", "stretch"}
  """
  @spec row_column_props(map(), String.t()) :: {String.t(), String.t()}
  def row_column_props(props, default_align \\ "stretch") do
    # v0.9 props take precedence over v0.8 props
    justify = props["justify"] || props["distribution"] || "start"
    align = props["align"] || props["alignment"] || default_align
    {justify, align}
  end

  @doc """
  Extracts Modal child props with v0.8/v0.9 compatibility.

  Returns `{trigger_child, content_child}` tuple where:
  - `trigger_child` is from v0.9 `trigger` or v0.8 `entryPointChild`
  - `content_child` is from v0.9 `content` or v0.8 `contentChild`

  ## Examples

      iex> A2UI.Props.Adapter.modal_props(%{"trigger" => "btn", "content" => "dialog"})
      {"btn", "dialog"}

      iex> A2UI.Props.Adapter.modal_props(%{"entryPointChild" => "btn", "contentChild" => "dialog"})
      {"btn", "dialog"}
  """
  @spec modal_props(map()) :: {String.t() | nil, String.t() | nil}
  def modal_props(props) do
    trigger = props["trigger"] || props["entryPointChild"]
    content = props["content"] || props["contentChild"]
    {trigger, content}
  end

  @doc """
  Extracts Tabs items prop with v0.8/v0.9 compatibility.

  Returns the tabs list from v0.9 `tabs` or v0.8 `tabItems`.

  ## Examples

      iex> A2UI.Props.Adapter.tabs_props(%{"tabs" => [%{"title" => "Tab 1"}]})
      [%{"title" => "Tab 1"}]

      iex> A2UI.Props.Adapter.tabs_props(%{"tabItems" => [%{"title" => "Tab 1"}]})
      [%{"title" => "Tab 1"}]
  """
  @spec tabs_props(map()) :: list()
  def tabs_props(props) do
    props["tabs"] || props["tabItems"] || []
  end

  @doc """
  Extracts the variant/usageHint prop with v0.8/v0.9 compatibility.

  Returns the variant from v0.9 `variant` or v0.8 `usageHint`.

  ## Examples

      iex> A2UI.Props.Adapter.variant_prop(%{"variant" => "h1"})
      "h1"

      iex> A2UI.Props.Adapter.variant_prop(%{"usageHint" => "h1"})
      "h1"

      iex> A2UI.Props.Adapter.variant_prop(%{}, "body")
      "body"
  """
  @spec variant_prop(map(), String.t() | nil) :: String.t() | nil
  def variant_prop(props, default \\ nil) do
    props["variant"] || props["usageHint"] || default
  end

  @doc """
  Extracts TextField value prop with v0.8/v0.9 compatibility.

  Returns the value binding from v0.9 `value` or v0.8 `text`.

  ## Examples

      iex> A2UI.Props.Adapter.text_field_value_prop(%{"value" => %{"path" => "/email"}})
      %{"path" => "/email"}

      iex> A2UI.Props.Adapter.text_field_value_prop(%{"text" => "hello"})
      "hello"
  """
  @spec text_field_value_prop(map()) :: term()
  def text_field_value_prop(props) do
    props["value"] || props["text"]
  end

  @doc """
  Extracts TextField type prop with v0.8/v0.9 compatibility.

  Returns the field type from v0.9 `variant` or v0.8 `textFieldType`.

  ## Examples

      iex> A2UI.Props.Adapter.text_field_type_prop(%{"variant" => "obscured"})
      "obscured"

      iex> A2UI.Props.Adapter.text_field_type_prop(%{"textFieldType" => "email"})
      "email"

      iex> A2UI.Props.Adapter.text_field_type_prop(%{})
      "shortText"
  """
  @spec text_field_type_prop(map()) :: String.t()
  def text_field_type_prop(props) do
    props["variant"] || props["textFieldType"] || "shortText"
  end

  @doc """
  Extracts Slider min/max props with v0.8/v0.9 compatibility.

  Returns `{min, max}` tuple from v0.9 `min`/`max` or v0.8 `minValue`/`maxValue`.

  ## Examples

      iex> A2UI.Props.Adapter.slider_range_props(%{"min" => 0, "max" => 100})
      {0, 100}

      iex> A2UI.Props.Adapter.slider_range_props(%{"minValue" => 10, "maxValue" => 50})
      {10, 50}
  """
  @spec slider_range_props(map()) :: {number(), number()}
  def slider_range_props(props) do
    min_val = props["min"] || props["minValue"] || 0
    max_val = props["max"] || props["maxValue"] || 100
    {min_val, max_val}
  end

  @doc """
  Extracts MultipleChoice/ChoicePicker selection prop with v0.8/v0.9 compatibility.

  Returns the selections binding from v0.9 `value` or v0.8 `selections`.

  ## Examples

      iex> A2UI.Props.Adapter.choice_selections_prop(%{"value" => %{"path" => "/selected"}})
      %{"path" => "/selected"}

      iex> A2UI.Props.Adapter.choice_selections_prop(%{"selections" => ["a", "b"]})
      ["a", "b"]
  """
  @spec choice_selections_prop(map()) :: term()
  def choice_selections_prop(props) do
    props["value"] || props["selections"]
  end

  @doc """
  Determines if ChoicePicker should use single selection mode.

  v0.9 uses `variant`: "mutuallyExclusive" for single, "multipleSelection" for multi.
  v0.8 uses `maxAllowedSelections`: 1 for single select.

  ## Examples

      iex> A2UI.Props.Adapter.choice_single_select?(%{"variant" => "mutuallyExclusive"})
      true

      iex> A2UI.Props.Adapter.choice_single_select?(%{"variant" => "multipleSelection"})
      false

      iex> A2UI.Props.Adapter.choice_single_select?(%{"maxAllowedSelections" => 1})
      true

      iex> A2UI.Props.Adapter.choice_single_select?(%{})
      false
  """
  @spec choice_single_select?(map()) :: boolean()
  def choice_single_select?(props) do
    variant = props["variant"]
    max_allowed = props["maxAllowedSelections"]

    cond do
      # v0.9 variant takes precedence
      variant == "mutuallyExclusive" -> true
      variant == "multipleSelection" -> false
      # Fall back to v0.8 maxAllowedSelections
      max_allowed == 1 -> true
      true -> false
    end
  end
end
