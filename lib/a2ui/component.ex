defmodule A2UI.Component do
  @moduledoc """
  Represents a component in the adjacency list.

  From the Components Concepts doc:
  "Components are stored as a flat list with ID-based references"

  Each component has:
  - id: Unique identifier
  - type: Component category from catalog (e.g., "Text", "Button")
  - props: Type-specific configuration
  """

  defstruct [:id, :type, :props]

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          props: map()
        }

  @doc """
  Parses v0.8 component format.

  v0.8: `{"id": "x", "component": {"Text": {"text": {...}}}}`

  ## Example

      iex> data = %{"id" => "title", "component" => %{"Text" => %{"text" => %{"literalString" => "Hello"}}}}
      iex> A2UI.Component.from_map(data)
      %A2UI.Component{id: "title", type: "Text", props: %{"text" => %{"literalString" => "Hello"}}}
  """
  @spec from_map(map()) :: t()
  def from_map(%{"id" => id, "component" => component_def}) do
    [{type, props}] = Map.to_list(component_def)
    %__MODULE__{id: id, type: type, props: props}
  end

  @doc """
  Parses v0.9 component format.

  v0.9: `{"id": "x", "component": "Text", "text": {...}}`

  ## Example

      iex> data = %{"id" => "title", "component" => "Text", "text" => %{"literalString" => "Hello"}}
      iex> A2UI.Component.from_map_v09(data)
      %A2UI.Component{id: "title", type: "Text", props: %{"text" => %{"literalString" => "Hello"}}}
  """
  @spec from_map_v09(map()) :: t()
  def from_map_v09(%{"id" => id, "component" => type} = data) do
    props = Map.drop(data, ["id", "component"])
    %__MODULE__{id: id, type: type, props: props}
  end
end
