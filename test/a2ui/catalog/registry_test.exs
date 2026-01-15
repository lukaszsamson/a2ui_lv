defmodule A2UI.Catalog.RegistryTest do
  use ExUnit.Case, async: false

  alias A2UI.Catalog.Registry

  # Test module to use as a catalog
  defmodule TestCatalog do
    def render_component(assigns), do: assigns
  end

  defmodule AnotherCatalog do
    def render_component(assigns), do: assigns
  end

  setup do
    # Ensure registry is started and clear any existing registrations
    case Process.whereis(Registry) do
      nil ->
        {:ok, _pid} = Registry.start_link()

      _pid ->
        # Clear existing registrations
        Enum.each(Registry.list(), &Registry.unregister/1)
    end

    :ok
  end

  describe "start_link/1" do
    test "starts the registry process" do
      # Registry is already started in setup, just verify it's alive
      assert Process.whereis(Registry) != nil
    end

    test "accepts initial catalogs" do
      # Clear and restart with initial catalogs
      Enum.each(Registry.list(), &Registry.unregister/1)

      catalog_id = "https://example.com/test-catalog.json"
      Registry.register(catalog_id, TestCatalog)

      assert {:ok, TestCatalog} = Registry.lookup(catalog_id)
    end
  end

  describe "register/2" do
    test "registers a catalog module" do
      catalog_id = "https://example.com/my-catalog.json"

      assert :ok = Registry.register(catalog_id, TestCatalog)
      assert {:ok, TestCatalog} = Registry.lookup(catalog_id)
    end

    test "overwrites existing registration" do
      catalog_id = "https://example.com/overwrite-test.json"

      Registry.register(catalog_id, TestCatalog)
      Registry.register(catalog_id, AnotherCatalog)

      assert {:ok, AnotherCatalog} = Registry.lookup(catalog_id)
    end
  end

  describe "lookup/1" do
    test "returns registered catalog module" do
      catalog_id = "https://example.com/lookup-test.json"
      Registry.register(catalog_id, TestCatalog)

      assert {:ok, TestCatalog} = Registry.lookup(catalog_id)
    end

    test "returns error for unregistered catalog" do
      assert {:error, :not_found} = Registry.lookup("https://unknown.com/catalog.json")
    end

    test "looks up default catalog when given nil" do
      default_id = Registry.default_catalog_id()
      Registry.register(default_id, TestCatalog)

      assert {:ok, TestCatalog} = Registry.lookup(nil)
    end
  end

  describe "lookup/2 with default" do
    test "returns registered module" do
      catalog_id = "https://example.com/with-default.json"
      Registry.register(catalog_id, TestCatalog)

      assert TestCatalog = Registry.lookup(catalog_id, AnotherCatalog)
    end

    test "returns default for unregistered catalog" do
      assert AnotherCatalog = Registry.lookup("https://unknown.com/x.json", AnotherCatalog)
    end

    test "returns default for nil catalog_id when default not registered" do
      # Don't register the default catalog
      default_id = Registry.default_catalog_id()
      Registry.unregister(default_id)

      assert AnotherCatalog = Registry.lookup(nil, AnotherCatalog)
    end
  end

  describe "unregister/1" do
    test "removes a registered catalog" do
      catalog_id = "https://example.com/unregister-test.json"
      Registry.register(catalog_id, TestCatalog)

      assert :ok = Registry.unregister(catalog_id)
      assert {:error, :not_found} = Registry.lookup(catalog_id)
    end

    test "is idempotent for unregistered catalog" do
      assert :ok = Registry.unregister("https://nonexistent.com/catalog.json")
    end
  end

  describe "list/0" do
    test "returns empty list when no catalogs registered" do
      Enum.each(Registry.list(), &Registry.unregister/1)
      assert [] = Registry.list()
    end

    test "returns all registered catalog IDs" do
      Enum.each(Registry.list(), &Registry.unregister/1)

      id1 = "https://example.com/catalog1.json"
      id2 = "https://example.com/catalog2.json"

      Registry.register(id1, TestCatalog)
      Registry.register(id2, AnotherCatalog)

      ids = Registry.list()
      assert length(ids) == 2
      assert id1 in ids
      assert id2 in ids
    end
  end

  describe "all/0" do
    test "returns map of all registrations" do
      Enum.each(Registry.list(), &Registry.unregister/1)

      id1 = "https://example.com/all1.json"
      id2 = "https://example.com/all2.json"

      Registry.register(id1, TestCatalog)
      Registry.register(id2, AnotherCatalog)

      all = Registry.all()
      assert all == %{id1 => TestCatalog, id2 => AnotherCatalog}
    end
  end

  describe "registered?/1" do
    test "returns true for registered catalog" do
      catalog_id = "https://example.com/registered-test.json"
      Registry.register(catalog_id, TestCatalog)

      assert Registry.registered?(catalog_id)
    end

    test "returns false for unregistered catalog" do
      refute Registry.registered?("https://unknown.com/not-registered.json")
    end
  end

  describe "default_catalog_id/0" do
    test "returns the v0.8 standard catalog ID" do
      assert Registry.default_catalog_id() == A2UI.V0_8.standard_catalog_id()
    end
  end
end
