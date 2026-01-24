defmodule A2UI.Surface do
  @moduledoc """
  Manages state for a single A2UI surface.

  Per Renderer Development Guide, maintains:
  - Component Buffer: Map keyed by ID (adjacency list model)
  - Data Model Store: Separate data model for binding
  - Interpreter State: Readiness flag

  ## Data Model Updates

  Data model changes are handled through `A2UI.DataPatch`, which provides
  a version-agnostic internal representation. This allows the surface to
  work with both v0.8 and v0.9 wire formats.

  ## Protocol Version

  The `protocol_version` field tracks which wire format this surface was created with.
  This affects:
  - Catalog resolution: v0.8 allows nil catalogId, v0.9 requires it
  - Template binding: v0.8 scopes `/path` in templates, v0.9 treats `/path` as absolute

  ## Data Model Broadcasting (v0.9)

  The `broadcast_data_model?` field (from `createSurface.broadcastDataModel`) controls
  whether the full data model should be included in A2A message metadata. When true,
  transport implementations should attach the surface data model to outgoing messages.
  """

  @type protocol_version :: :v0_8 | :v0_9

  defstruct [
    :id,
    :root_id,
    :catalog_id,
    :styles,
    :catalog_status,
    :protocol_version,
    components: %{},
    data_model: %{},
    ready?: false,
    broadcast_data_model?: false
  ]

  @typedoc """
  Catalog resolution status.

  - `:ok` - Catalog resolved successfully
  - `{:error, reason}` - Catalog resolution failed
  """
  @type catalog_status :: :ok | {:error, A2UI.Catalog.Resolver.error_reason()}

  @type t :: %__MODULE__{
          id: String.t(),
          root_id: String.t() | nil,
          catalog_id: String.t() | nil,
          styles: map() | nil,
          catalog_status: catalog_status() | nil,
          protocol_version: protocol_version() | nil,
          components: %{String.t() => A2UI.Component.t()},
          data_model: map(),
          ready?: boolean(),
          broadcast_data_model?: boolean()
        }

  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering}
  alias A2UI.{Binding, DataPatch, Initializers, JsonPointer}

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
    # Convert to internal patch representation and apply.
    patches =
      case update.patches do
        patches when is_list(patches) and patches != [] -> patches
        _ -> [DataPatch.from_update(update.path, update.value)]
      end

    new_data = DataPatch.apply_all(surface.data_model, patches)
    %{surface | data_model: new_data}
  end

  def apply_message(%__MODULE__{} = surface, %BeginRendering{} = msg) do
    apply_begin_rendering(surface, msg, :ok)
  end

  @doc """
  Applies a BeginRendering message with catalog resolution status.

  This variant is called from Session after catalog resolution.
  The catalog_status indicates whether the catalog was successfully resolved.
  The surface is only marked ready if catalog resolution succeeded.

  ## Parameters

  - `surface` - The surface to update
  - `msg` - The BeginRendering message
  - `catalog_status` - `:ok` or `{:error, reason}` from Catalog.Resolver

  ## Example

      # Successful resolution
      surface = Surface.apply_begin_rendering(surface, msg, :ok)
      surface.ready? # => true

      # Failed resolution
      surface = Surface.apply_begin_rendering(surface, msg, {:error, :unsupported_catalog})
      surface.ready? # => false
  """
  @spec apply_begin_rendering(t(), BeginRendering.t(), catalog_status()) :: t()
  def apply_begin_rendering(%__MODULE__{} = surface, %BeginRendering{} = msg, catalog_status) do
    # Only mark ready if catalog resolution succeeded
    ready = catalog_status == :ok

    %{
      surface
      | root_id: msg.root_id,
        catalog_id: msg.catalog_id,
        styles: msg.styles,
        catalog_status: catalog_status,
        protocol_version: msg.protocol_version,
        ready?: ready,
        broadcast_data_model?: msg.broadcast_data_model? || false
    }
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
    # Use v0.9-native container creation semantics (lists for numeric segments).
    new_data = JsonPointer.upsert(surface.data_model, pointer, value)
    %{surface | data_model: new_data}
  end

  @doc """
  Applies a data patch directly to the surface.

  This is the version-agnostic way to update the data model. Both v0.8 and v0.9
  wire format updates are first converted to patches, then applied here.

  ## Example

      iex> surface = A2UI.Surface.new("main")
      iex> patch = {:set_at, "/user/name", "Alice"}
      iex> surface = A2UI.Surface.apply_patch(surface, patch)
      iex> surface.data_model
      %{"user" => %{"name" => "Alice"}}
  """
  @spec apply_patch(t(), DataPatch.patch()) :: t()
  def apply_patch(%__MODULE__{} = surface, patch) do
    new_data = DataPatch.apply_patch(surface.data_model, patch)
    %{surface | data_model: new_data}
  end

  @doc """
  Applies multiple data patches in order.

  ## Example

      iex> surface = A2UI.Surface.new("main")
      iex> patches = [
      ...>   {:set_at, "/user/name", "Alice"},
      ...>   {:set_at, "/user/age", 30}
      ...> ]
      iex> surface = A2UI.Surface.apply_patches(surface, patches)
      iex> surface.data_model
      %{"user" => %{"name" => "Alice", "age" => 30}}
  """
  @spec apply_patches(t(), [DataPatch.patch()]) :: t()
  def apply_patches(%__MODULE__{} = surface, patches) when is_list(patches) do
    new_data = DataPatch.apply_all(surface.data_model, patches)
    %{surface | data_model: new_data}
  end
end
