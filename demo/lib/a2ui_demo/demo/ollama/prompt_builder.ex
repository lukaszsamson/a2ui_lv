defmodule A2UIDemo.Demo.Ollama.PromptBuilder do
  @moduledoc """
  Builds system prompts for A2UI generation based on model capabilities.

  Different models work better with different prompt styles:
  - `:minimal` - Very short, just the essentials (for reasoning models)
  - `:concise` - Compact but complete (default)
  - `:detailed` - Full documentation with examples
  """

  alias A2UIDemo.Demo.Ollama.ModelConfig

  # Path to the library's spec file (in parent directory since demo is a subdirectory)
  @catalog_definition_path Path.expand(
                             "../../../../../priv/a2ui/spec/v0_8/json/standard_catalog_definition.json",
                             __DIR__
                           )
  @external_resource @catalog_definition_path

  @catalog_definition Jason.decode!(File.read!(@catalog_definition_path))
  @catalog_components Map.fetch!(@catalog_definition, "components")

  @doc """
  Build a system prompt for the given model and surface ID.
  """
  @spec build(ModelConfig.t(), String.t()) :: String.t()
  def build(%ModelConfig{prompt_style: style}, surface_id) do
    case style do
      :minimal -> minimal_prompt(surface_id)
      :concise -> concise_prompt(surface_id)
      :detailed -> detailed_prompt(surface_id)
    end
  end

  @doc """
  Build a prompt for handling follow-up actions.
  """
  @spec build_action_prompt(ModelConfig.t(), String.t(), map()) :: String.t()
  def build_action_prompt(%ModelConfig{prompt_style: style}, surface_id, action_info) do
    case style do
      :minimal -> minimal_action_prompt(surface_id, action_info)
      :concise -> concise_action_prompt(surface_id, action_info)
      :detailed -> detailed_action_prompt(surface_id, action_info)
    end
  end

  @doc """
  Get the JSON schema for models that support it.
  """
  @spec a2ui_schema() :: map()
  def a2ui_schema do
    component_one_of =
      @catalog_components
      |> Enum.map(fn {type, schema} ->
        %{
          "type" => "object",
          "additionalProperties" => false,
          "properties" => %{type => schema},
          "required" => [type]
        }
      end)

    component_wrapper = %{
      "type" => "object",
      "minProperties" => 1,
      "maxProperties" => 1,
      "oneOf" => component_one_of
    }

    %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => %{
        "surfaceUpdate" => %{
          "type" => "object",
          "additionalProperties" => false,
          "properties" => %{
            "surfaceId" => %{"type" => "string"},
            "components" => %{
              "type" => "array",
              "minItems" => 1,
              "items" => %{
                "type" => "object",
                "additionalProperties" => false,
                "properties" => %{
                  "id" => %{"type" => "string"},
                  "weight" => %{"type" => "number"},
                  "component" => component_wrapper
                },
                "required" => ["id", "component"]
              }
            }
          },
          "required" => ["surfaceId", "components"]
        },
        "dataModel" => %{"type" => "object"},
        "beginRendering" => %{
          "type" => "object",
          "additionalProperties" => false,
          "properties" => %{
            "surfaceId" => %{"type" => "string"},
            "root" => %{"type" => "string"},
            "catalogId" => %{"type" => "string"},
            "styles" => %{"type" => "object", "additionalProperties" => true}
          },
          "required" => ["surfaceId", "root"]
        }
      },
      "required" => ["surfaceUpdate", "dataModel", "beginRendering"]
    }
  end

  # Minimal prompt for reasoning models that output thinking
  defp minimal_prompt(surface_id) do
    """
    OUTPUT JSON ONLY. No explanation.

    A2UI format: {"surfaceUpdate":{"surfaceId":"#{surface_id}","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["c1"]}}}},...]},"dataModel":{"key":"value"},"beginRendering":{"surfaceId":"#{surface_id}","root":"root"}}

    Components: Column, Row, Card, Text, Button, TextField, CheckBox
    Text: {"text":{"literalString":"static"} or {"path":"/dataKey"}}
    Children: {"explicitList":["id1","id2"]} - reference by ID
    """
  end

  # Concise prompt - good balance
  defp concise_prompt(surface_id) do
    """
    OUTPUT ONLY VALID JSON. NO EXPLANATION. NO MARKDOWN. JUST THE JSON OBJECT.

    You are an AI agent. Respond with A2UI JSON to build the requested UI.

    Required structure:
    {"surfaceUpdate":{"surfaceId":"#{surface_id}","components":[...]},"dataModel":{...},"beginRendering":{"surfaceId":"#{surface_id}","root":"root"}}

    Component format: {"id":"unique_id","component":{"TypeName":{...props...}}}

    Types:
    - Column: {"children":{"explicitList":["id1","id2"]}} - vertical stack
    - Row: {"children":{"explicitList":["id1","id2"]}} - horizontal stack
    - Card: {"child":"content_id"} - container
    - Text: {"text":{"literalString":"static"} or {"path":"/key"},"usageHint":"h1|h2|h3|body|caption"}
    - Button: {"child":"label_id","action":{"name":"action"}}
    - TextField: {"label":{"literalString":"Label"},"text":{"path":"/field"}}
    - CheckBox: {"label":{"literalString":"Label"},"value":{"path":"/bool"}}

    dataModel: Prefer primitives. Avoid arrays (v0.8 contents cannot represent arrays); if you need a list, use an object with numeric string keys: {"items":{"0":{"name":"A"},"1":{"name":"B"}}}
    Use {"path":"/key1"} in components to display dataModel values.

    EXAMPLE for "show a greeting":
    {"surfaceUpdate":{"surfaceId":"#{surface_id}","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["title","msg"]}}}},{"id":"title","component":{"Text":{"text":{"literalString":"Hello"},"usageHint":"h1"}}},{"id":"msg","component":{"Text":{"text":{"path":"/message"}}}}]},"dataModel":{"message":"Welcome to the app!"},"beginRendering":{"surfaceId":"#{surface_id}","root":"root"}}

    The root component MUST have id "root". Children reference other component ids as strings.
    """
  end

  # Detailed prompt with full documentation
  defp detailed_prompt(surface_id) do
    """
    You are an AI agent that responds to user requests by generating user interfaces using the A2UI protocol.
    Your response MUST be valid JSON containing exactly these three fields: surfaceUpdate, dataModel, beginRendering.

    IMPORTANT: Output ONLY the JSON object. No markdown, no explanation, no code blocks.

    ## SURFACE ID
    Always use "#{surface_id}" as the surfaceId in all messages.

    ## RESPONSE STRUCTURE
    {
      "surfaceUpdate": {
        "surfaceId": "#{surface_id}",
        "components": [/* flat array of component objects */]
      },
      "dataModel": {/* key-value pairs for dynamic data */},
      "beginRendering": {"surfaceId": "#{surface_id}", "root": "root"}
    }

    ## COMPONENTS
    Each component is an object with "id" and "component" fields.
    The "component" field contains exactly ONE key which is the component type name.

    Available component types:

    ### Layout Components
    - Column: Vertical stack of children
      {"Column": {"children": {"explicitList": ["child_id1", "child_id2"]}}}
      Optional: "alignment": "start|center|end|stretch", "distribution": "start|center|end|spaceBetween|spaceAround|spaceEvenly"

    - Row: Horizontal stack of children
      {"Row": {"children": {"explicitList": ["child_id1", "child_id2"]}}}
      Optional: "alignment": "start|center|end|stretch", "distribution": "start|center|end|spaceBetween|spaceAround|spaceEvenly"

    - Card: Styled container with single child
      {"Card": {"child": "content_id"}}

    ### Display Components
    - Text: Display text content
      {"Text": {"text": {"literalString": "Static text"}, "usageHint": "h1"}}
      {"Text": {"text": {"path": "/dataKey"}, "usageHint": "body"}}
      usageHint options: "h1", "h2", "h3", "h4", "h5", "body", "caption"

    - Divider: Horizontal or vertical line
      {"Divider": {"axis": "horizontal"}}  // horizontal|vertical

    ### Interactive Components
    - Button: Clickable button
      {"Button": {"child": "button_text_id", "primary": true, "action": {"name": "action_name"}}}

    - TextField: Text input field
      {"TextField": {"label": {"literalString": "Label"}, "text": {"path": "/fieldPath"}, "textFieldType": "shortText"}}
      textFieldType options: "shortText", "longText", "number", "date", "obscured"

    - CheckBox: Boolean toggle
      {"CheckBox": {"label": {"literalString": "Option"}, "value": {"path": "/booleanPath"}}}

    ## DATA BINDING
    - Static value: {"literalString": "Hello"} or {"literalNumber": 42} or {"literalBoolean": true}
    - Dynamic binding: {"path": "/keyname"} - references dataModel["keyname"]

    Paths use JSON Pointer syntax (RFC 6901). Examples:
    - "/user" → references dataModel.user
    - "/user/name" → references dataModel.user.name
    - "/items/0/price" → references dataModel.items["0"].price

    The dataModel should prefer primitives. Avoid JSON arrays (v0.8 contents cannot represent arrays); use maps with numeric string keys instead.

    ## RULES
    1. The root component MUST have id "root"
    2. Children are referenced BY ID (strings in explicitList), NOT nested objects
    3. ALL components must be in the flat "components" array
    4. Generate realistic, helpful data in dataModel based on the user's request
    5. Use path bindings for data that could change dynamically

    ## EXAMPLE
    User request: "show weather for Paris"

    Response:
    {"surfaceUpdate":{"surfaceId":"#{surface_id}","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["title","card"]}}}},{"id":"title","component":{"Text":{"text":{"literalString":"Weather"},"usageHint":"h2"}}},{"id":"card","component":{"Card":{"child":"info"}}},{"id":"info","component":{"Column":{"children":{"explicitList":["city","temp","desc"]}}}},{"id":"city","component":{"Text":{"text":{"path":"/city"},"usageHint":"h3"}}},{"id":"temp","component":{"Text":{"text":{"path":"/temperature"},"usageHint":"h1"}}},{"id":"desc","component":{"Text":{"text":{"path":"/description"},"usageHint":"caption"}}}],"surfaceId":"#{surface_id}"},"dataModel":{"city":"Paris","temperature":"18°C","description":"Partly cloudy"},"beginRendering":{"surfaceId":"#{surface_id}","root":"root"}}

    beginRendering MAY include optional "catalogId" and "styles" (e.g. {"styles":{"primaryColor":"#4f46e5","font":"ui-sans-serif"}}).

    Now generate the A2UI JSON for the user's request.
    """
  end

  # Action prompt builders - for handling follow-up user interactions

  defp minimal_action_prompt(surface_id, %{
         original_prompt: original,
         action_name: action,
         action_context: context,
         data_model: data_model
       }) do
    """
    OUTPUT JSON ONLY. No explanation.

    A2UI format: {"surfaceUpdate":{"surfaceId":"#{surface_id}","components":[...]},"dataModel":{...},"beginRendering":{"surfaceId":"#{surface_id}","root":"root"}}

    Original request: #{original}
    User clicked: #{action}
    Context: #{Jason.encode!(context)}
    Current data: #{Jason.encode!(data_model)}

    Generate UPDATED UI showing results of the action.
    """
  end

  defp concise_action_prompt(surface_id, %{
         original_prompt: original,
         action_name: action,
         action_context: context,
         data_model: data_model
       }) do
    """
    OUTPUT ONLY VALID JSON. NO EXPLANATION. NO MARKDOWN. JUST THE JSON OBJECT.

    You previously created a UI for: "#{original}"
    User clicked button with action: "#{action}"

    Action context (data sent with click):
    #{Jason.encode!(context, pretty: true)}

    Current data model (form values):
    #{Jason.encode!(data_model, pretty: true)}

    Generate an UPDATED A2UI response showing the results. For example:
    - If form submission: process data and show results/confirmation
    - If analysis request: perform analysis and display findings
    - Show success/error states as appropriate

    Required structure:
    {"surfaceUpdate":{"surfaceId":"#{surface_id}","components":[...]},"dataModel":{...},"beginRendering":{"surfaceId":"#{surface_id}","root":"root"}}

    Component format: {"id":"unique_id","component":{"TypeName":{...props...}}}
    Types: Column, Row, Card, Text, Button, TextField, CheckBox
    Children: {"explicitList":["id1","id2"]} - reference by ID

    The root component MUST have id "root".
    """
  end

  defp detailed_action_prompt(surface_id, %{
         original_prompt: original,
         action_name: action,
         action_context: context,
         data_model: data_model
       }) do
    """
    You are an AI agent handling a user interaction with a UI you previously generated.

    IMPORTANT: Output ONLY valid JSON. No markdown, no explanation, no code blocks.

    ## CONTEXT

    Original user request: "#{original}"

    User clicked button with action: "#{action}"

    Action context (data sent with the button click):
    #{Jason.encode!(context, pretty: true)}

    Current data model (form values, user inputs):
    #{Jason.encode!(data_model, pretty: true)}

    ## YOUR TASK

    Process this action and generate an UPDATED UI showing results. For example:
    - If this is a form submission: process the data and show results/confirmation
    - If this is an analysis request: perform the analysis and display findings with indicators
    - Show appropriate success/error states

    ## RESPONSE STRUCTURE
    {
      "surfaceUpdate": {
        "surfaceId": "#{surface_id}",
        "components": [/* flat array of component objects */]
      },
      "dataModel": {/* key-value pairs - the NEW state after processing */},
      "beginRendering": {"surfaceId": "#{surface_id}", "root": "root"}
    }

    ## RULES
    1. The root component MUST have id "root"
    2. Children are referenced BY ID in explicitList arrays
    3. Use path bindings {"path": "/key"} to display dynamic data from dataModel
    4. Generate meaningful results based on the action and context

    Now generate the updated A2UI JSON.
    """
  end
end
