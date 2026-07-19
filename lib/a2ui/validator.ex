defmodule A2UI.Validator do
  @moduledoc """
  Safety limits validation for A2UI surfaces.

  Per DESIGN_V1.md, enforces limits to prevent runaway agent outputs:
  - Max depth: 30 (prevent infinite recursion)
  - Max components per surface: 1000 (memory/render performance)
  - Max template expansion: 200 items (prevent huge lists)
  - Max data model size: 100KB (memory bounds)

  Additional security validations:
  - Cycle detection: Prevent infinite loops in component graph
  - URL scheme validation: Only allow safe schemes for media components
  """

  @max_components 1000
  @max_depth 30
  @max_template_items 200
  @max_data_model_bytes 100_000

  alias A2UI.Catalog.Components

  # Allowed URL schemes for media components (Image, Video, AudioPlayer)
  @allowed_url_schemes ~w(https http data blob)
  @open_url_schemes ~w(https http)

  @component_contracts %{
    "Text" => {~w(component text), ~w(id accessibility weight component text variant)},
    "Image" =>
      {~w(component url), ~w(id accessibility weight component url description fit variant)},
    "Icon" => {~w(component name), ~w(id accessibility weight component name)},
    "Video" => {~w(component url), ~w(id accessibility weight component url)},
    "AudioPlayer" => {~w(component url), ~w(id accessibility weight component url description)},
    "Row" =>
      {~w(component children), ~w(id accessibility weight component children align justify)},
    "Column" =>
      {~w(component children), ~w(id accessibility weight component children align justify)},
    "List" =>
      {~w(component children), ~w(id accessibility weight component children align direction)},
    "Card" => {~w(component child), ~w(id accessibility weight component child)},
    "Tabs" => {~w(component tabs), ~w(id accessibility weight component tabs)},
    "Modal" =>
      {~w(component trigger content), ~w(id accessibility weight component trigger content)},
    "Divider" => {~w(component), ~w(id accessibility weight component axis)},
    "Button" =>
      {~w(component child action),
       ~w(id accessibility weight component child action variant checks)},
    "TextField" =>
      {~w(component label),
       ~w(id accessibility weight component label value variant validationRegexp checks)},
    "CheckBox" =>
      {~w(component label value), ~w(id accessibility weight component label value checks)},
    "ChoicePicker" =>
      {~w(component options value),
       ~w(id accessibility weight component label options value variant displayStyle filterable checks)},
    "Slider" =>
      {~w(component value max), ~w(id accessibility weight component label value min max checks)},
    "DateTimeInput" =>
      {~w(component value),
       ~w(id accessibility weight component label value enableDate enableTime min max checks)}
  }
  @component_enums %{
    {"Text", "variant"} => ~w(h1 h2 h3 h4 h5 caption body),
    {"Image", "fit"} => ~w(contain cover fill none scaleDown),
    {"Image", "variant"} => ~w(icon avatar smallFeature mediumFeature largeFeature header),
    {"Row", "justify"} => ~w(center end spaceAround spaceBetween spaceEvenly start stretch),
    {"Row", "align"} => ~w(start center end stretch),
    {"Column", "justify"} => ~w(start center end spaceBetween spaceAround spaceEvenly stretch),
    {"Column", "align"} => ~w(center end start stretch),
    {"List", "direction"} => ~w(vertical horizontal),
    {"List", "align"} => ~w(start center end stretch),
    {"Divider", "axis"} => ~w(horizontal vertical),
    {"Button", "variant"} => ~w(default primary borderless),
    {"TextField", "variant"} => ~w(longText number shortText obscured),
    {"ChoicePicker", "variant"} => ~w(multipleSelection mutuallyExclusive),
    {"ChoicePicker", "displayStyle"} => ~w(checkbox chips)
  }
  @function_names ~w(required regex length numeric email formatString formatNumber formatCurrency formatDate pluralize openUrl and or not)
  @icon_names ~w(accountCircle add arrowBack arrowForward attachFile calendarToday call camera check close delete download edit event error fastForward favorite favoriteOff folder help home info locationOn lock lockOpen mail menu moreVert moreHoriz notificationsOff notifications pause payment person phone photo play print refresh rewind search send settings share shoppingCart skipNext skipPrevious star starHalf starOff stop upload visibility visibilityOff volumeDown volumeMute volumeOff volumeUp warning)

  @doc "Validates a released v0.9/v0.9.1 server message before it is adapted."
  @spec validate_server_message(map(), :v0_9 | :v0_9_1, map() | nil) ::
          :ok | {:error, term()}
  def validate_server_message(message, version, catalog_schema \\ nil)
      when version in [:v0_9, :v0_9_1] do
    expected_version = if version == :v0_9, do: "v0.9", else: "v0.9.1"

    with :ok <-
           require(
             message["version"] == expected_version,
             "/version",
             "must equal #{expected_version}"
           ),
         :ok <- validate_official_schema(message, version, catalog_schema),
         :ok <- validate_released_semantics(message) do
      :ok
    else
      {:error, _} = error -> error
    end
  end

  defp validate_official_schema(message, version, catalog_schema) do
    case A2UI.Schema.validate_server_message(message, version, catalog_schema) do
      :ok -> :ok
      {:error, {path, message}} -> validation_error(path, message)
      {:error, reason} -> validation_error("/", "schema compilation failed: #{inspect(reason)}")
    end
  end

  defp validate_released_semantics(%{"updateComponents" => %{"components" => components}}) do
    with :ok <- validate_unique_component_ids(components),
         :ok <- validate_component_paths(components) do
      :ok
    end
  end

  defp validate_released_semantics(%{"updateDataModel" => payload}) do
    validate_pointer_value(payload["path"], "/updateDataModel/path", true)
  end

  defp validate_released_semantics(_message), do: :ok

  defp validate_component_paths(components) do
    components
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {component, index}, :ok ->
      case validate_paths_in_value(component, "/updateComponents/components/#{index}") do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_paths_in_value(%{"path" => pointer} = value, path) when map_size(value) == 1 do
    validate_pointer_value(pointer, path <> "/path", false)
  end

  defp validate_paths_in_value(%{"componentId" => _, "path" => pointer} = value, path)
       when map_size(value) == 2 do
    validate_pointer_value(pointer, path <> "/path", false)
  end

  defp validate_paths_in_value(value, path) when is_map(value) do
    Enum.reduce_while(value, :ok, fn {key, nested}, :ok ->
      case validate_paths_in_value(nested, path <> "/" <> escape_pointer(key)) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_paths_in_value(value, path) when is_list(value) do
    value
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {nested, index}, :ok ->
      case validate_paths_in_value(nested, path <> "/#{index}") do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_paths_in_value(_value, _path), do: :ok

  defp validate_pointer_value(nil, _path, true), do: :ok

  defp validate_pointer_value(pointer, path, absolute?) do
    case A2UI.JsonPointer.validate(pointer, absolute: absolute?) do
      :ok -> :ok
      {:error, reason} -> validation_error(path, reason)
    end
  end

  @doc false
  def validate_envelope(envelope, payload) when not is_map(payload),
    do: validation_error("/#{envelope}", "must be an object")

  def validate_envelope("createSurface", payload) do
    with :ok <- required_string(payload, "surfaceId", "/createSurface"),
         :ok <- required_string(payload, "catalogId", "/createSurface"),
         :ok <- optional_boolean(payload, "sendDataModel", "/createSurface"),
         :ok <- optional_map(payload, "theme", "/createSurface"),
         :ok <- validate_theme(payload["theme"]),
         :ok <-
           reject_extra_keys(
             payload,
             ~w(surfaceId catalogId theme sendDataModel),
             "/createSurface"
           ) do
      :ok
    end
  end

  def validate_envelope("updateComponents", payload) do
    with :ok <- required_string(payload, "surfaceId", "/updateComponents"),
         :ok <-
           require(
             is_list(payload["components"]),
             "/updateComponents/components",
             "must be an array"
           ),
         :ok <-
           require(
             payload["components"] != [],
             "/updateComponents/components",
             "must not be empty"
           ),
         :ok <- reject_extra_keys(payload, ~w(surfaceId components), "/updateComponents"),
         :ok <- validate_wire_components(payload["components"]) do
      :ok
    end
  end

  def validate_envelope("updateDataModel", payload) do
    with :ok <- required_string(payload, "surfaceId", "/updateDataModel"),
         :ok <- optional_string(payload, "path", "/updateDataModel"),
         :ok <- reject_extra_keys(payload, ~w(surfaceId path value), "/updateDataModel") do
      :ok
    end
  end

  def validate_envelope("deleteSurface", payload) do
    with :ok <- required_string(payload, "surfaceId", "/deleteSurface"),
         :ok <- reject_extra_keys(payload, ~w(surfaceId), "/deleteSurface") do
      :ok
    end
  end

  defp validate_wire_components(components) do
    with :ok <- validate_unique_component_ids(components) do
      components
      |> Enum.with_index()
      |> Enum.reduce_while(:ok, fn {component, index}, :ok ->
        case validate_wire_component(component, index) do
          :ok -> {:cont, :ok}
          {:error, _} = error -> {:halt, error}
        end
      end)
    end
  end

  defp validate_unique_component_ids(components) do
    components
    |> Enum.with_index()
    |> Enum.reduce_while(MapSet.new(), fn {component, index}, ids ->
      id = is_map(component) && component["id"]

      if is_binary(id) and MapSet.member?(ids, id) do
        {:halt,
         validation_error(
           "/updateComponents/components/#{index}/id",
           "must be unique within an updateComponents message"
         )}
      else
        {:cont, if(is_binary(id), do: MapSet.put(ids, id), else: ids)}
      end
    end)
    |> case do
      %MapSet{} -> :ok
      error -> error
    end
  end

  defp validate_wire_component(component, index) when is_map(component) do
    path = "/updateComponents/components/#{index}"
    type = component["component"]

    with :ok <- required_string(component, "id", path),
         :ok <- required_string(component, "component", path),
         {required, allowed} when is_list(required) <- Map.get(@component_contracts, type),
         :ok <- require_fields(component, required, path),
         :ok <- reject_extra_keys(component, allowed, path),
         :ok <- validate_component_common(component, path),
         :ok <- validate_component_enums(type, component, path),
         :ok <- validate_checks(component["checks"], path),
         :ok <- validate_component_values(type, component, path) do
      :ok
    else
      nil -> validation_error(path <> "/component", "is not in the Basic Catalog")
      {:error, _} = error -> error
    end
  end

  defp validate_wire_component(_, index),
    do: validation_error("/updateComponents/components/#{index}", "must be an object")

  defp validate_component_values("Button", component, path) do
    action = component["action"]

    cond do
      not is_map(action) or map_size(action) != 1 ->
        validation_error(path <> "/action", "must contain exactly one event or functionCall")

      Map.has_key?(action, "event") ->
        validate_event_action(action["event"], path <> "/action/event")

      Map.has_key?(action, "functionCall") ->
        validate_function_call(action["functionCall"], path <> "/action/functionCall")

      true ->
        validation_error(path <> "/action", "must contain exactly one event or functionCall")
    end
  end

  defp validate_component_values("Tabs", component, path) do
    tabs = component["tabs"]

    with :ok <-
           require(is_list(tabs) and tabs != [], path <> "/tabs", "must be a non-empty array") do
      validate_tabs(tabs, path <> "/tabs")
    end
  end

  defp validate_component_values("ChoicePicker", component, path) do
    with :ok <- validate_choice_options(component["options"], path <> "/options"),
         :ok <- validate_dynamic(component["value"], :string_list, path <> "/value"),
         :ok <- optional_dynamic(component, "label", :string, path),
         :ok <- optional_boolean(component, "filterable", path) do
      :ok
    end
  end

  defp validate_component_values("DateTimeInput", component, path) do
    with :ok <- optional_boolean(component, "enableDate", path),
         :ok <- optional_boolean(component, "enableTime", path),
         :ok <- optional_dynamic(component, "label", :string, path),
         :ok <- validate_dynamic(component["value"], :string, path <> "/value"),
         :ok <- optional_date_time_bound(component, "min", path),
         :ok <- optional_date_time_bound(component, "max", path) do
      :ok
    end
  end

  defp validate_component_values("Slider", component, path) do
    with :ok <- require(is_number(component["max"]), path <> "/max", "must be a number"),
         :ok <- optional_number(component, "min", path),
         :ok <- validate_dynamic(component["value"], :number, path <> "/value"),
         :ok <- optional_dynamic(component, "label", :string, path) do
      :ok
    end
  end

  defp validate_component_values(type, component, path) when type in ~w(Row Column List) do
    validate_child_list(component["children"], path <> "/children")
  end

  defp validate_component_values(type, component, path) when type in ~w(Card) do
    required_string(component, "child", path)
  end

  defp validate_component_values("Modal", component, path) do
    with :ok <- required_string(component, "trigger", path),
         :ok <- required_string(component, "content", path) do
      :ok
    end
  end

  defp validate_component_values("Text", component, path),
    do: validate_dynamic(component["text"], :string, path <> "/text")

  defp validate_component_values(type, component, path)
       when type in ~w(Image Video AudioPlayer) do
    with :ok <- validate_dynamic(component["url"], :string, path <> "/url"),
         :ok <- optional_dynamic(component, "description", :string, path) do
      :ok
    end
  end

  defp validate_component_values("Icon", component, path) do
    case component["name"] do
      name when name in @icon_names ->
        :ok

      %{"svgPath" => svg_path} = icon when is_binary(svg_path) ->
        reject_extra_keys(icon, ~w(svgPath), path <> "/name")

      %{"path" => pointer} = binding when is_binary(pointer) ->
        reject_extra_keys(binding, ~w(path), path <> "/name")

      _ ->
        validation_error(path <> "/name", "must be a supported icon, SVG path, or binding")
    end
  end

  defp validate_component_values("TextField", component, path) do
    with :ok <- validate_dynamic(component["label"], :string, path <> "/label"),
         :ok <- optional_dynamic(component, "value", :string, path),
         :ok <- optional_string(component, "validationRegexp", path) do
      :ok
    end
  end

  defp validate_component_values("CheckBox", component, path) do
    with :ok <- validate_dynamic(component["label"], :string, path <> "/label"),
         :ok <- validate_dynamic(component["value"], :boolean, path <> "/value") do
      :ok
    end
  end

  defp validate_component_values(_type, _component, _path), do: :ok

  defp validate_component_common(component, path) do
    with :ok <- optional_number(component, "weight", path),
         :ok <- optional_map(component, "accessibility", path) do
      case component["accessibility"] do
        nil ->
          :ok

        accessibility ->
          with :ok <-
                 reject_extra_keys(accessibility, ~w(label description), path <> "/accessibility"),
               :ok <- optional_dynamic(accessibility, "label", :string, path <> "/accessibility"),
               :ok <-
                 optional_dynamic(accessibility, "description", :string, path <> "/accessibility") do
            :ok
          end
      end
    end
  end

  defp validate_tabs(tabs, path) do
    tabs
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {tab, index}, :ok ->
      tab_path = path <> "/#{index}"

      result =
        with :ok <- require(is_map(tab), tab_path, "must be an object"),
             :ok <- require_fields(tab, ~w(title child), tab_path),
             :ok <- reject_extra_keys(tab, ~w(title child), tab_path),
             :ok <- validate_dynamic(tab["title"], :string, tab_path <> "/title"),
             :ok <- required_string(tab, "child", tab_path) do
          :ok
        end

      case result do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_choice_options(options, path) do
    with :ok <- require(is_list(options), path, "must be an array") do
      options
      |> Enum.with_index()
      |> Enum.reduce_while(:ok, fn {option, index}, :ok ->
        option_path = path <> "/#{index}"

        result =
          with :ok <- require(is_map(option), option_path, "must be an object"),
               :ok <- require_fields(option, ~w(label value), option_path),
               :ok <- reject_extra_keys(option, ~w(label value), option_path),
               :ok <- validate_dynamic(option["label"], :string, option_path <> "/label"),
               :ok <- required_string(option, "value", option_path) do
            :ok
          end

        case result do
          :ok -> {:cont, :ok}
          {:error, _} = error -> {:halt, error}
        end
      end)
    end
  end

  defp validate_child_list(children, path) when is_list(children) do
    require(
      Enum.all?(children, &is_binary/1),
      path,
      "must contain component IDs"
    )
  end

  defp validate_child_list(%{"componentId" => id, "path" => pointer} = template, path) do
    with :ok <-
           require(is_binary(id), path <> "/componentId", "must be a component ID"),
         :ok <- require(is_binary(pointer), path <> "/path", "must be a string"),
         :ok <- reject_extra_keys(template, ~w(componentId path), path) do
      :ok
    end
  end

  defp validate_child_list(_, path),
    do: validation_error(path, "must be an array of component IDs or a child template")

  defp validate_event_action(event, path) when is_map(event) do
    with :ok <- required_string(event, "name", path),
         :ok <- reject_extra_keys(event, ~w(name context), path),
         :ok <- optional_map(event, "context", path),
         :ok <- validate_dynamic_map(event["context"], path <> "/context") do
      :ok
    end
  end

  defp validate_event_action(_, path), do: validation_error(path, "must be an object")

  defp validate_dynamic_map(nil, _path), do: :ok

  defp validate_dynamic_map(map, path) do
    Enum.reduce_while(map, :ok, fn {key, value}, :ok ->
      case validate_dynamic(value, :any, path <> "/" <> escape_pointer(key)) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_function_call(function, path) when is_map(function) do
    call = function["call"]

    with :ok <- required_string(function, "call", path),
         :ok <- require(call in @function_names, path <> "/call", "is not in the Basic Catalog"),
         :ok <- require(is_map(function["args"]), path <> "/args", "must be an object"),
         :ok <- reject_extra_keys(function, ~w(call args returnType), path),
         :ok <- validate_function_return_type(function, call, path),
         :ok <- validate_function_args(call, function["args"], path <> "/args") do
      :ok
    end
  end

  defp validate_function_call(_, path), do: validation_error(path, "must be an object")

  defp validate_function_return_type(function, call, path) do
    expected =
      if call in ~w(formatString formatNumber formatCurrency formatDate pluralize),
        do: "string",
        else: if(call == "openUrl", do: "void", else: "boolean")

    require(
      not Map.has_key?(function, "returnType") or function["returnType"] == expected,
      path <> "/returnType",
      "must equal #{expected}"
    )
  end

  defp validate_function_args("required", args, path),
    do: validate_args(args, ~w(value), ~w(value), path, &validate_dynamic(&2, :any, &1))

  defp validate_function_args("regex", args, path) do
    with :ok <- validate_args_shape(args, ~w(value pattern), ~w(value pattern), path),
         :ok <- validate_dynamic(args["value"], :string, path <> "/value"),
         :ok <- require(is_binary(args["pattern"]), path <> "/pattern", "must be a string") do
      :ok
    end
  end

  defp validate_function_args("length", args, path) do
    with :ok <- validate_args_shape(args, ~w(value), ~w(value min max), path),
         :ok <-
           require(
             Map.has_key?(args, "min") or Map.has_key?(args, "max"),
             path,
             "must contain min or max"
           ),
         :ok <- validate_dynamic(args["value"], :string, path <> "/value"),
         :ok <- optional_non_negative_integer(args, "min", path),
         :ok <- optional_non_negative_integer(args, "max", path) do
      :ok
    end
  end

  defp validate_function_args("numeric", args, path) do
    with :ok <- validate_args_shape(args, ~w(value), ~w(value min max), path),
         :ok <-
           require(
             Map.has_key?(args, "min") or Map.has_key?(args, "max"),
             path,
             "must contain min or max"
           ),
         :ok <- validate_dynamic(args["value"], :number, path <> "/value"),
         :ok <- optional_number(args, "min", path),
         :ok <- optional_number(args, "max", path) do
      :ok
    end
  end

  defp validate_function_args("email", args, path),
    do: validate_args(args, ~w(value), ~w(value), path, &validate_dynamic(&2, :string, &1))

  defp validate_function_args("formatString", args, path),
    do: validate_args(args, ~w(value), ~w(value), path, &validate_dynamic(&2, :string, &1))

  defp validate_function_args("formatNumber", args, path) do
    with :ok <- validate_args_shape(args, ~w(value), ~w(value decimals grouping), path),
         :ok <- validate_dynamic(args["value"], :number, path <> "/value"),
         :ok <- optional_dynamic(args, "decimals", :number, path),
         :ok <- optional_dynamic(args, "grouping", :boolean, path) do
      :ok
    end
  end

  defp validate_function_args("formatCurrency", args, path) do
    with :ok <-
           validate_args_shape(
             args,
             ~w(value currency),
             ~w(value currency decimals grouping),
             path
           ),
         :ok <- validate_dynamic(args["value"], :number, path <> "/value"),
         :ok <- validate_dynamic(args["currency"], :string, path <> "/currency"),
         :ok <- optional_dynamic(args, "decimals", :number, path),
         :ok <- optional_dynamic(args, "grouping", :boolean, path) do
      :ok
    end
  end

  defp validate_function_args("formatDate", args, path) do
    with :ok <- validate_args_shape(args, ~w(value format), ~w(value format), path),
         :ok <- validate_dynamic(args["value"], :string, path <> "/value"),
         :ok <- validate_dynamic(args["format"], :string, path <> "/format") do
      :ok
    end
  end

  defp validate_function_args("pluralize", args, path) do
    with :ok <-
           validate_args_shape(args, ~w(value other), ~w(value zero one two few many other), path),
         :ok <- validate_dynamic(args["value"], :number, path <> "/value") do
      ~w(zero one two few many other)
      |> Enum.reduce_while(:ok, fn key, :ok ->
        case optional_dynamic(args, key, :string, path) do
          :ok -> {:cont, :ok}
          {:error, _} = error -> {:halt, error}
        end
      end)
    end
  end

  defp validate_function_args("openUrl", args, path) do
    with :ok <- validate_args_shape(args, ~w(url), ~w(url), path),
         {:ok, _url} <- validate_open_url(args["url"]) do
      :ok
    else
      {:error, _} -> validation_error(path <> "/url", "must be an HTTP or HTTPS URI")
    end
  end

  defp validate_function_args(call, args, path) when call in ~w(and or) do
    with :ok <- validate_args_shape(args, ~w(values), ~w(values), path),
         :ok <-
           require(
             is_list(args["values"]) and length(args["values"]) >= 2,
             path <> "/values",
             "must contain at least two values"
           ) do
      args["values"]
      |> Enum.with_index()
      |> Enum.reduce_while(:ok, fn {value, index}, :ok ->
        case validate_dynamic(value, :boolean, path <> "/values/#{index}") do
          :ok -> {:cont, :ok}
          {:error, _} = error -> {:halt, error}
        end
      end)
    end
  end

  defp validate_function_args("not", args, path),
    do: validate_args(args, ~w(value), ~w(value), path, &validate_dynamic(&2, :boolean, &1))

  defp validate_args(args, required, allowed, path, validator) do
    with :ok <- validate_args_shape(args, required, allowed, path) do
      key = hd(required)
      validator.(path <> "/" <> key, args[key])
    end
  end

  defp validate_args_shape(args, required, allowed, path) do
    with :ok <- require_fields(args, required, path),
         :ok <- reject_extra_keys(args, allowed, path) do
      :ok
    end
  end

  defp validate_dynamic(value, :any, path) do
    cond do
      is_binary(value) or is_number(value) or is_boolean(value) or is_list(value) -> :ok
      is_map(value) and Map.has_key?(value, "path") -> validate_binding(value, path)
      is_map(value) and Map.has_key?(value, "call") -> validate_function_call(value, path)
      true -> validation_error(path, "must be a dynamic value")
    end
  end

  defp validate_dynamic(value, :string, _path) when is_binary(value), do: :ok
  defp validate_dynamic(value, :number, _path) when is_number(value), do: :ok
  defp validate_dynamic(value, :boolean, _path) when is_boolean(value), do: :ok

  defp validate_dynamic(value, :string_list, path) when is_list(value) do
    require(Enum.all?(value, &is_binary/1), path, "must contain strings")
  end

  defp validate_dynamic(%{"path" => _} = binding, _type, path),
    do: validate_binding(binding, path)

  defp validate_dynamic(%{"call" => _} = function, type, path) do
    with :ok <- validate_function_call(function, path),
         :ok <- validate_function_result_type(function["call"], type, path) do
      :ok
    end
  end

  defp validate_dynamic(_value, type, path),
    do: validation_error(path, "must be a dynamic #{dynamic_type_name(type)}")

  defp validate_binding(binding, path) do
    with :ok <- required_string(binding, "path", path),
         :ok <- reject_extra_keys(binding, ~w(path), path) do
      :ok
    end
  end

  defp validate_function_result_type(call, type, path) do
    expected =
      cond do
        call in ~w(formatString formatNumber formatCurrency formatDate pluralize) -> :string
        call == "openUrl" -> :void
        true -> :boolean
      end

    require(
      type == expected,
      path <> "/call",
      "does not return #{dynamic_type_name(type)}"
    )
  end

  defp dynamic_type_name(:string_list), do: "string array"
  defp dynamic_type_name(type), do: Atom.to_string(type)

  defp optional_dynamic(map, key, type, path) do
    if Map.has_key?(map, key), do: validate_dynamic(map[key], type, path <> "/" <> key), else: :ok
  end

  defp optional_date_time_bound(map, key, path) do
    case Map.fetch(map, key) do
      :error ->
        :ok

      {:ok, value} when is_binary(value) ->
        require(
          iso8601_date_or_time?(value),
          path <> "/" <> key,
          "must be an ISO 8601 date or time"
        )

      {:ok, value} ->
        validate_dynamic(value, :string, path <> "/" <> key)
    end
  end

  defp iso8601_date_or_time?(value) do
    match?({:ok, _}, Date.from_iso8601(value)) or
      match?({:ok, _}, Time.from_iso8601(value)) or
      match?({:ok, _, _}, DateTime.from_iso8601(value)) or
      match?({:ok, _}, NaiveDateTime.from_iso8601(value))
  end

  defp validate_component_enums(type, component, path) do
    @component_enums
    |> Enum.filter(fn {{enum_type, _key}, _values} -> enum_type == type end)
    |> Enum.reduce_while(:ok, fn {{_type, key}, values}, :ok ->
      case optional_enum(component, key, values, path) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_theme(nil), do: :ok

  defp validate_theme(theme) do
    with :ok <-
           require(
             not Map.has_key?(theme, "primaryColor") or
               (is_binary(theme["primaryColor"]) and
                  String.match?(theme["primaryColor"], ~r/^#[0-9a-fA-F]{6}$/)),
             "/createSurface/theme/primaryColor",
             "must be a six-digit hexadecimal color"
           ),
         :ok <- optional_string(theme, "iconUrl", "/createSurface/theme"),
         :ok <- optional_uri(theme, "iconUrl", "/createSurface/theme"),
         :ok <- optional_string(theme, "agentDisplayName", "/createSurface/theme") do
      :ok
    end
  end

  defp validate_checks(nil, _path), do: :ok

  defp validate_checks(checks, path) when is_list(checks) do
    checks
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {check, index}, :ok ->
      check_path = path <> "/checks/#{index}"

      result =
        with :ok <- require(is_map(check), check_path, "must be an object"),
             :ok <-
               require(is_binary(check["message"]), check_path <> "/message", "must be a string"),
             :ok <- reject_extra_keys(check, ~w(condition message), check_path),
             :ok <- validate_dynamic(check["condition"], :boolean, check_path <> "/condition") do
          :ok
        end

      case result do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_checks(_checks, path),
    do: validation_error(path <> "/checks", "must be an array")

  defp required_string(map, key, path),
    do:
      require(
        is_binary(map[key]),
        path <> "/" <> key,
        "must be a string"
      )

  defp optional_string(map, key, path) do
    require(
      not Map.has_key?(map, key) or is_binary(map[key]),
      path <> "/" <> key,
      "must be a string"
    )
  end

  defp optional_boolean(map, key, path) do
    require(
      not Map.has_key?(map, key) or is_boolean(map[key]),
      path <> "/" <> key,
      "must be a boolean"
    )
  end

  defp optional_number(map, key, path) do
    require(
      not Map.has_key?(map, key) or is_number(map[key]),
      path <> "/" <> key,
      "must be a number"
    )
  end

  defp optional_non_negative_integer(map, key, path) do
    require(
      not Map.has_key?(map, key) or
        (is_integer(map[key]) and map[key] >= 0),
      path <> "/" <> key,
      "must be a non-negative integer"
    )
  end

  defp optional_map(map, key, path) do
    require(
      not Map.has_key?(map, key) or is_map(map[key]),
      path <> "/" <> key,
      "must be an object"
    )
  end

  defp optional_uri(map, key, path) do
    valid? =
      case Map.fetch(map, key) do
        :error ->
          true

        {:ok, value} when is_binary(value) ->
          uri = URI.parse(value)
          is_binary(uri.scheme) and not String.contains?(value, " ")

        _ ->
          false
      end

    require(valid?, path <> "/" <> key, "must be a URI")
  end

  defp optional_enum(map, key, values, path) do
    require(
      not Map.has_key?(map, key) or map[key] in values,
      path <> "/" <> key,
      "has an invalid value"
    )
  end

  defp require_fields(map, fields, path) do
    case Enum.find(fields, &(not Map.has_key?(map, &1))) do
      nil -> :ok
      key -> validation_error(path <> "/" <> key, "is required")
    end
  end

  defp reject_extra_keys(map, allowed, path) do
    case Enum.find(Map.keys(map), &(&1 not in allowed)) do
      nil -> :ok
      key -> validation_error(path <> key_suffix(path, key), "is not allowed")
    end
  end

  defp key_suffix("/", key), do: key
  defp key_suffix(_path, key), do: "/" <> key

  defp escape_pointer(value) do
    value
    |> to_string()
    |> String.replace("~", "~0")
    |> String.replace("/", "~1")
  end

  defp require(true, _path, _message), do: :ok
  defp require(false, path, message), do: validation_error(path, message)
  defp validation_error(path, message), do: {:error, {:validation_failed, path, message}}

  @doc """
  Returns the maximum number of components allowed per surface.
  """
  @spec max_components() :: pos_integer()
  def max_components, do: @max_components

  @doc """
  Returns the maximum render depth allowed.
  """
  @spec max_depth() :: pos_integer()
  def max_depth, do: @max_depth

  @doc """
  Returns the maximum number of template items allowed per expansion.
  """
  @spec max_template_items() :: pos_integer()
  def max_template_items, do: @max_template_items

  @doc """
  Returns the list of allowed component types for a catalog.

  If no catalog_id is provided, returns all known types across catalogs.
  """
  @spec allowed_types(String.t() | nil) :: [String.t()]
  def allowed_types(catalog_id \\ nil) do
    Components.allowed_types(catalog_id) || Components.all_known_types()
  end

  @doc """
  Validates a surface update message.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.

  ## Parameters

  - `msg` - The surface update message with components
  - `catalog_id` - Optional catalog ID for type validation. If nil, validates
    against all known component types across catalogs (permissive mode for
    when catalog is not yet known, e.g., v0.8 surfaceUpdate before beginRendering).

  ## Examples

      iex> components = [%A2UI.Component{id: "a", type: "Text", props: %{}}]
      iex> A2UI.Validator.validate_surface_update(%{components: components})
      :ok

      iex> A2UI.Validator.validate_surface_update(%{components: Enum.map(1..1001, fn i -> %A2UI.Component{id: "\#{i}", type: "Text", props: %{}} end)})
      {:error, {:too_many_components, 1001, 1000}}
  """
  @spec validate_surface_update(%{components: [A2UI.Component.t()]}, String.t() | nil) ::
          :ok | {:error, term()}
  def validate_surface_update(msg, catalog_id \\ nil)

  def validate_surface_update(%{components: components}, catalog_id) do
    with :ok <- validate_count(components),
         :ok <- validate_types(components, catalog_id) do
      :ok
    end
  end

  @doc """
  Validates component count.
  """
  @spec validate_count([A2UI.Component.t()]) :: :ok | {:error, term()}
  def validate_count(components) do
    count = length(components)

    if count <= @max_components do
      :ok
    else
      {:error, {:too_many_components, count, @max_components}}
    end
  end

  @doc """
  Validates component types against the catalog's allowlist.

  If catalog_id is nil, validates against all known types (permissive mode).
  """
  @spec validate_types([A2UI.Component.t()], String.t() | nil) :: :ok | {:error, term()}
  def validate_types(components, catalog_id \\ nil) do
    custom_schema? =
      is_binary(catalog_id) and match?({:ok, _}, A2UI.Catalog.Registry.schema(catalog_id))

    if custom_schema? do
      :ok
    else
      types = Enum.map(components, & &1.type)
      unknown = Components.invalid_types(types, catalog_id)

      if unknown == [], do: :ok, else: {:error, {:unknown_component_types, unknown}}
    end
  end

  @doc """
  Validates that a component with id "root" exists.

  Per v0.9 protocol: "at least one component must have `id: \"root\"`
  to serve as the root of the component tree."

  This validation is typically performed when a surface becomes ready
  (during BeginRendering processing), not on individual updates, since
  incremental updates may not include the root component.

  ## Parameters

  - `components` - Map or list of components to check

  ## Returns

  - `:ok` - A root component exists
  - `{:error, :missing_root_component}` - No component with id "root"

  ## Examples

      iex> components = %{"root" => %A2UI.Component{id: "root", type: "Column"}}
      iex> A2UI.Validator.validate_has_root(components)
      :ok

      iex> components = %{"other" => %A2UI.Component{id: "other", type: "Text"}}
      iex> A2UI.Validator.validate_has_root(components)
      {:error, :missing_root_component}
  """
  @spec validate_has_root(%{String.t() => A2UI.Component.t()} | [A2UI.Component.t()]) ::
          :ok | {:error, :missing_root_component}
  def validate_has_root(components) when is_map(components) do
    if Map.has_key?(components, "root") do
      :ok
    else
      {:error, :missing_root_component}
    end
  end

  def validate_has_root(components) when is_list(components) do
    if Enum.any?(components, &(&1.id == "root")) do
      :ok
    else
      {:error, :missing_root_component}
    end
  end

  @doc """
  Validates render depth hasn't been exceeded.
  """
  @spec validate_depth(non_neg_integer()) :: :ok | {:error, term()}
  def validate_depth(depth) when depth <= @max_depth, do: :ok
  def validate_depth(depth), do: {:error, {:max_depth_exceeded, depth, @max_depth}}

  @doc """
  Validates template expansion count.
  """
  @spec validate_template_items(non_neg_integer()) :: :ok | {:error, term()}
  def validate_template_items(count) when count <= @max_template_items, do: :ok

  def validate_template_items(count),
    do: {:error, {:too_many_template_items, count, @max_template_items}}

  @doc """
  Validates data model size.
  """
  @spec validate_data_model_size(term()) :: :ok | {:error, term()}
  def validate_data_model_size(data_model) do
    size = :erlang.external_size(data_model)

    if size <= @max_data_model_bytes do
      :ok
    else
      {:error, {:data_model_too_large, size, @max_data_model_bytes}}
    end
  end

  # ============================================
  # Cycle Detection
  # ============================================

  @doc """
  Checks if rendering a component would create a cycle.

  A cycle occurs when a component references itself directly or indirectly
  through its children. This is detected by tracking the path of component
  IDs during traversal.

  ## Parameters

  - `component_id` - The component ID about to be rendered
  - `visited` - MapSet of component IDs already in the current render path

  ## Returns

  - `:ok` - No cycle detected, safe to render
  - `{:error, {:cycle_detected, component_id}}` - Cycle detected

  ## Example

      visited = MapSet.new(["root", "card1"])
      :ok = A2UI.Validator.check_cycle("text1", visited)
      {:error, {:cycle_detected, "root"}} = A2UI.Validator.check_cycle("root", visited)
  """
  @spec check_cycle(String.t(), MapSet.t(String.t())) :: :ok | {:error, term()}
  def check_cycle(component_id, visited) do
    if MapSet.member?(visited, component_id) do
      {:error, {:cycle_detected, component_id}}
    else
      :ok
    end
  end

  @doc """
  Adds a component ID to the visited set for cycle tracking.

  ## Example

      visited = A2UI.Validator.track_visited("root", MapSet.new())
      visited = A2UI.Validator.track_visited("card1", visited)
  """
  @spec track_visited(String.t(), MapSet.t(String.t())) :: MapSet.t(String.t())
  def track_visited(component_id, visited) do
    MapSet.put(visited, component_id)
  end

  @doc """
  Creates a new empty visited set for cycle detection.
  """
  @dialyzer {:nowarn_function, new_visited: 0}
  @spec new_visited() :: MapSet.t(String.t())
  def new_visited, do: MapSet.new()

  # ============================================
  # URL Scheme Validation
  # ============================================

  @doc """
  Returns the list of allowed URL schemes for media components.
  """
  @spec allowed_url_schemes() :: [String.t()]
  def allowed_url_schemes, do: @allowed_url_schemes

  @doc """
  Validates a URL for use in media components (Image, Video, AudioPlayer).

  Only allows safe URL schemes: https, http, data, blob.
  Returns the URL unchanged if valid, or nil if invalid.

  ## Parameters

  - `url` - The URL to validate (may be nil or any term)

  ## Returns

  - `{:ok, url}` - URL is valid and safe to use
  - `{:error, :invalid_url}` - URL is nil, empty, or not a string
  - `{:error, {:unsafe_scheme, scheme}}` - URL uses an unsafe scheme

  ## Examples

      iex> A2UI.Validator.validate_media_url("https://example.com/image.png")
      {:ok, "https://example.com/image.png"}

      iex> A2UI.Validator.validate_media_url("data:image/png;base64,...")
      {:ok, "data:image/png;base64,..."}

      iex> A2UI.Validator.validate_media_url("javascript:alert(1)")
      {:error, {:unsafe_scheme, "javascript"}}

      iex> A2UI.Validator.validate_media_url(nil)
      {:error, :invalid_url}
  """
  @spec validate_media_url(term()) :: {:ok, String.t()} | {:error, term()}
  def validate_media_url(nil), do: {:error, :invalid_url}
  def validate_media_url(""), do: {:error, :invalid_url}

  def validate_media_url(url) when is_binary(url) do
    case extract_scheme(url) do
      {:ok, scheme} ->
        if scheme in @allowed_url_schemes do
          {:ok, url}
        else
          {:error, {:unsafe_scheme, scheme}}
        end

      :error ->
        # No scheme found - could be a relative URL, which is safe
        # (will be resolved relative to the page origin)
        {:ok, url}
    end
  end

  def validate_media_url(_), do: {:error, :invalid_url}

  @doc "Validates an openUrl target. Only absolute HTTP(S) URLs are allowed."
  @spec validate_open_url(term()) :: {:ok, String.t()} | {:error, term()}
  def validate_open_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in @open_url_schemes and is_binary(host) ->
        {:ok, url}

      %URI{scheme: scheme} when is_binary(scheme) ->
        {:error, {:unsafe_scheme, String.downcase(scheme)}}

      _ ->
        {:error, :invalid_url}
    end
  end

  def validate_open_url(_), do: {:error, :invalid_url}

  @doc """
  Sanitizes a URL for media components, returning nil for invalid URLs.

  This is a convenience wrapper around `validate_media_url/1` that returns
  the URL or nil, suitable for use in templates.

  ## Examples

      iex> A2UI.Validator.sanitize_media_url("https://example.com/img.png")
      "https://example.com/img.png"

      iex> A2UI.Validator.sanitize_media_url("javascript:alert(1)")
      nil

      iex> A2UI.Validator.sanitize_media_url(nil)
      nil
  """
  @spec sanitize_media_url(term()) :: String.t() | nil
  def sanitize_media_url(url) do
    case validate_media_url(url) do
      {:ok, valid_url} -> valid_url
      {:error, _} -> nil
    end
  end

  # Extract scheme from URL (e.g., "https" from "https://example.com")
  defp extract_scheme(url) when is_binary(url) do
    case Regex.run(~r/^([a-zA-Z][a-zA-Z0-9+.-]*):/, url) do
      [_, scheme] -> {:ok, String.downcase(scheme)}
      _ -> :error
    end
  end
end
