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
    types = Enum.map(components, & &1.type)
    unknown = Components.invalid_types(types, catalog_id)

    if unknown == [] do
      :ok
    else
      {:error, {:unknown_component_types, unknown}}
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
  @spec validate_data_model_size(map()) :: :ok | {:error, term()}
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
