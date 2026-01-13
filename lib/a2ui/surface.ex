defmodule A2UI.Surface do
  @moduledoc """
  Manages state for a single A2UI surface.

  Per Renderer Development Guide, maintains:
  - Component Buffer: Map keyed by ID (adjacency list model)
  - Data Model Store: Separate data model for binding
  - Interpreter State: Readiness flag
  """

  defstruct [
    :id,
    :root_id,
    :catalog_id,
    components: %{},
    data_model: %{},
    ready?: false
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          root_id: String.t() | nil,
          catalog_id: String.t() | nil,
          components: %{String.t() => A2UI.Component.t()},
          data_model: map(),
          ready?: boolean()
        }

  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering}
  alias A2UI.{Binding, Initializers}

  @doc """
  Creates a new surface with the given ID.

  ## Example

      iex> A2UI.Surface.new("main")
      %A2UI.Surface{id: "main", components: %{}, data_model: %{}, ready?: false}
  """
  @spec new(String.t()) :: t()
  def new(surface_id), do: %__MODULE__{id: surface_id}

  @doc """
  Applies a message to the surface state.

  Handles:
  - SurfaceUpdate: Merges components by ID
  - DataModelUpdate: Updates data model at path
  - BeginRendering: Sets root_id and ready? flag
  """
  @spec apply_message(t(), SurfaceUpdate.t() | DataModelUpdate.t() | BeginRendering.t()) :: t()
  def apply_message(%__MODULE__{} = surface, %SurfaceUpdate{components: components}) do
    # Merge components by ID (duplicates update existing)
    new_components =
      Enum.reduce(components, surface.components, fn comp, acc ->
        Map.put(acc, comp.id, comp)
      end)

    new_data_model = Initializers.apply(surface.data_model, components)
    %{surface | components: new_components, data_model: new_data_model}
  end

  def apply_message(%__MODULE__{} = surface, %DataModelUpdate{} = update) do
    new_data = apply_data_update(surface.data_model, update.path, update.contents)
    %{surface | data_model: new_data}
  end

  def apply_message(%__MODULE__{} = surface, %BeginRendering{root_id: root, catalog_id: catalog}) do
    %{surface | root_id: root, catalog_id: catalog, ready?: true}
  end

  @doc """
  Updates a single path in the data model (for two-way binding).

  Uses RFC6901 JSON Pointer for path resolution.

  ## Example

      iex> surface = %A2UI.Surface{id: "main", data_model: %{"form" => %{"name" => ""}}}
      iex> A2UI.Surface.update_data_at_path(surface, "/form/name", "Alice")
      %A2UI.Surface{..., data_model: %{"form" => %{"name" => "Alice"}}}
  """
  @spec update_data_at_path(t(), String.t(), term()) :: t()
  def update_data_at_path(%__MODULE__{} = surface, path, value) do
    # Two-way binding uses RFC6901 pointers (same resolver as reads).
    pointer = Binding.expand_path(path, nil)
    new_data = Binding.set_at_pointer(surface.data_model, pointer, value)
    %{surface | data_model: new_data}
  end

  # Private helpers for data model manipulation

  defp apply_data_update(data_model, nil, contents) do
    merge_contents(data_model, contents)
  end

  defp apply_data_update(data_model, path, contents) do
    pointer = Binding.expand_path(path, nil)

    cond do
      pointer in ["", "/"] ->
        merge_contents(data_model, contents)

      true ->
        existing = Binding.get_at_pointer(data_model, pointer)
        existing_map = if is_map(existing), do: existing, else: %{}
        merged = merge_contents(existing_map, contents)
        Binding.set_at_pointer(data_model, pointer, merged)
    end
  end

  # v0.8 format: array of {key, valueType} entries
  defp merge_contents(existing, contents) when is_list(contents) do
    Enum.reduce(contents, existing, fn entry, acc ->
      key = entry["key"]
      value = extract_typed_value(entry)
      Map.put(acc, key, value)
    end)
  end

  defp merge_contents(existing, _contents), do: existing

  defp extract_typed_value(%{"valueString" => v}), do: v
  defp extract_typed_value(%{"valueNumber" => v}), do: v
  defp extract_typed_value(%{"valueBoolean" => v}), do: v
  defp extract_typed_value(%{"valueArray" => v}), do: Enum.map(v, &extract_typed_value/1)
  defp extract_typed_value(%{"valueMap" => v}), do: merge_contents(%{}, v)
  defp extract_typed_value(v) when is_binary(v) or is_number(v) or is_boolean(v), do: v
  defp extract_typed_value(_), do: nil
end
