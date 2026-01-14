defmodule A2UI.Validator do
  @moduledoc """
  Safety limits validation for A2UI surfaces.

  Per DESIGN_V1.md, enforces limits to prevent runaway agent outputs:
  - Max depth: 30 (prevent infinite recursion)
  - Max components per surface: 1000 (memory/render performance)
  - Max template expansion: 200 items (prevent huge lists)
  - Max data model size: 100KB (memory bounds)
  """

  @max_components 1000
  @max_depth 30
  @max_template_items 200
  @max_data_model_bytes 100_000

  # All 18 standard catalog components (v0.8)
  @allowed_types ~w(
    Column Row Card Text Divider Button TextField CheckBox
    Icon Image AudioPlayer Video Slider DateTimeInput MultipleChoice List Tabs Modal
  )

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
  Returns the list of allowed component types.
  """
  @spec allowed_types() :: [String.t()]
  def allowed_types, do: @allowed_types

  @doc """
  Validates a surface update message.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.

  ## Examples

      iex> components = [%A2UI.Component{id: "a", type: "Text", props: %{}}]
      iex> A2UI.Validator.validate_surface_update(%{components: components})
      :ok

      iex> A2UI.Validator.validate_surface_update(%{components: Enum.map(1..1001, fn i -> %A2UI.Component{id: "\#{i}", type: "Text", props: %{}} end)})
      {:error, {:too_many_components, 1001, 1000}}
  """
  @spec validate_surface_update(%{components: [A2UI.Component.t()]}) ::
          :ok | {:error, term()}
  def validate_surface_update(%{components: components}) do
    with :ok <- validate_count(components),
         :ok <- validate_types(components) do
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
  Validates component types against allowlist.
  """
  @spec validate_types([A2UI.Component.t()]) :: :ok | {:error, term()}
  def validate_types(components) do
    unknown =
      components
      |> Enum.map(& &1.type)
      |> Enum.reject(&(&1 in @allowed_types))
      |> Enum.uniq()

    if unknown == [] do
      :ok
    else
      {:error, {:unknown_component_types, unknown}}
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
  @spec validate_data_model_size(map()) :: :ok | {:error, term()}
  def validate_data_model_size(data_model) do
    size = :erlang.external_size(data_model)

    if size <= @max_data_model_bytes do
      :ok
    else
      {:error, {:data_model_too_large, size, @max_data_model_bytes}}
    end
  end
end
