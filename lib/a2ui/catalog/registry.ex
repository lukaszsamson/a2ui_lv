defmodule A2UI.Catalog.Registry do
  @moduledoc """
  Maps catalog IDs to renderer-specific catalog modules.

  Per the A2UI v0.8 protocol, `beginRendering.catalogId` selects which component
  catalog to use for rendering a surface. If omitted, the standard catalog ID
  is used by default.

  ## Usage

  The registry is typically started as part of your application supervision tree:

      children = [
        A2UI.Catalog.Registry,
        # ...
      ]

  Register catalog modules at startup:

      A2UI.Catalog.Registry.register(
        A2UI.V0_8.standard_catalog_id(),
        A2UI.Phoenix.Catalog.Standard
      )

  Look up a catalog module:

      case A2UI.Catalog.Registry.lookup(catalog_id) do
        {:ok, module} -> module.render_component(assigns)
        {:error, :not_found} -> render_fallback(assigns)
      end

  ## Catalog Module Interface

  Catalog modules are renderer-specific. For Phoenix, they should be function
  component modules with a `render_component/1` function that accepts assigns
  containing at least:

  - `:surface` - The `A2UI.Surface` struct
  - `:id` - The component ID to render
  - `:depth` - Current nesting depth (for safety limits)

  ## Default Catalog

  The standard catalog ID (`A2UI.V0_8.standard_catalog_id()`) is automatically
  registered when using `A2UI.Phoenix` with the `A2UI.Phoenix.Catalog.Standard`
  module.
  """

  use GenServer

  @table_name :a2ui_catalog_registry

  # ============================================
  # Client API
  # ============================================

  @doc """
  Starts the catalog registry.

  ## Options

  - `:name` - Optional process name (defaults to `A2UI.Catalog.Registry`)
  - `:catalogs` - Initial catalog registrations as a map of `%{catalog_id => module}`
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a catalog module for a catalog ID.

  ## Parameters

  - `catalog_id` - The catalog ID URI (e.g., the standard catalog ID)
  - `module` - The module implementing the catalog (must have `render_component/1`)

  ## Returns

  - `:ok` - Registration successful

  ## Examples

      iex> A2UI.Catalog.Registry.register(
      ...>   "https://example.com/my-catalog.json",
      ...>   MyApp.Catalog.Custom
      ...> )
      :ok
  """
  @spec register(String.t(), module()) :: :ok
  def register(catalog_id, module) when is_binary(catalog_id) and is_atom(module) do
    :ets.insert(@table_name, {catalog_id, module})
    :ok
  end

  @doc """
  Registers a module for all known v0.8 standard catalog ID aliases.

  The v0.8 specification uses different catalog IDs in different sources.
  This function registers the given module for all known aliases, ensuring
  compatibility with servers that may use any of the known forms.

  ## Parameters

  - `module` - The module implementing the standard catalog

  ## Returns

  - `:ok` - All registrations successful

  ## Known v0.8 Aliases

  - `"https://github.com/google/A2UI/blob/main/specification/v0_8/json/standard_catalog_definition.json"`
  - `"a2ui.org:standard_catalog_0_8_0"`

  ## Examples

      iex> A2UI.Catalog.Registry.register_v0_8_standard(A2UI.Phoenix.Catalog.Standard)
      :ok
  """
  @spec register_v0_8_standard(module()) :: :ok
  def register_v0_8_standard(module) when is_atom(module) do
    Enum.each(A2UI.V0_8.standard_catalog_ids(), fn catalog_id ->
      register(catalog_id, module)
    end)

    :ok
  end

  @doc """
  Looks up the catalog module for a catalog ID.

  ## Parameters

  - `catalog_id` - The catalog ID to look up (can be `nil` for default)

  ## Returns

  - `{:ok, module}` - The registered catalog module
  - `{:error, :not_found}` - No catalog registered for this ID

  ## Examples

      iex> A2UI.Catalog.Registry.lookup(A2UI.V0_8.standard_catalog_id())
      {:ok, A2UI.Phoenix.Catalog.Standard}

      iex> A2UI.Catalog.Registry.lookup("unknown-catalog")
      {:error, :not_found}
  """
  @spec lookup(String.t() | nil) :: {:ok, module()} | {:error, :not_found}
  def lookup(nil), do: lookup(default_catalog_id())

  def lookup(catalog_id) when is_binary(catalog_id) do
    case :ets.lookup(@table_name, catalog_id) do
      [{^catalog_id, module}] -> {:ok, module}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Looks up a catalog module, returning the module or a default.

  This is useful when you want to fall back to a default catalog module
  if the requested one is not registered.

  ## Parameters

  - `catalog_id` - The catalog ID to look up
  - `default` - The module to return if not found

  ## Returns

  The registered module or the default.

  ## Examples

      iex> A2UI.Catalog.Registry.lookup(nil, A2UI.Phoenix.Catalog.Standard)
      A2UI.Phoenix.Catalog.Standard
  """
  @spec lookup(String.t() | nil, module()) :: module()
  def lookup(catalog_id, default) when is_atom(default) do
    case lookup(catalog_id) do
      {:ok, module} -> module
      {:error, :not_found} -> default
    end
  end

  @doc """
  Unregisters a catalog.

  ## Parameters

  - `catalog_id` - The catalog ID to unregister

  ## Returns

  - `:ok` - Always succeeds (idempotent)
  """
  @spec unregister(String.t()) :: :ok
  def unregister(catalog_id) when is_binary(catalog_id) do
    case :ets.whereis(@table_name) do
      :undefined -> :ok
      _ref -> :ets.delete(@table_name, catalog_id)
    end

    :ok
  end

  @doc """
  Lists all registered catalog IDs.

  ## Returns

  A list of registered catalog ID strings.
  """
  @spec list() :: [String.t()]
  def list do
    case :ets.whereis(@table_name) do
      :undefined ->
        []

      _ref ->
        @table_name
        |> :ets.tab2list()
        |> Enum.map(fn {catalog_id, _module} -> catalog_id end)
    end
  end

  @doc """
  Returns all registered catalogs as a map.

  ## Returns

  A map of `%{catalog_id => module}`.
  """
  @spec all() :: %{String.t() => module()}
  def all do
    case :ets.whereis(@table_name) do
      :undefined ->
        %{}

      _ref ->
        @table_name
        |> :ets.tab2list()
        |> Map.new()
    end
  end

  @doc """
  Checks if a catalog is registered.

  ## Parameters

  - `catalog_id` - The catalog ID to check

  ## Returns

  `true` if registered, `false` otherwise.
  """
  @spec registered?(String.t()) :: boolean()
  def registered?(catalog_id) when is_binary(catalog_id) do
    :ets.member(@table_name, catalog_id)
  end

  @doc """
  Returns the default catalog ID (v0.8 standard catalog).
  """
  @spec default_catalog_id() :: String.t()
  def default_catalog_id, do: A2UI.V0_8.standard_catalog_id()

  # ============================================
  # GenServer Callbacks
  # ============================================

  @impl GenServer
  def init(opts) do
    # Create ETS table if it doesn't exist
    # Using :named_table and :public so it can be accessed without going through GenServer
    case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:named_table, :public, :set, read_concurrency: true])

      _ref ->
        # Table already exists (e.g., in tests), clear it
        :ets.delete_all_objects(@table_name)
    end

    # Register initial catalogs if provided
    initial_catalogs = Keyword.get(opts, :catalogs, %{})

    Enum.each(initial_catalogs, fn {catalog_id, module} ->
      register(catalog_id, module)
    end)

    {:ok, %{}}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    # Don't delete the table on terminate - let it persist for the application lifetime
    :ok
  end
end
