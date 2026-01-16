defmodule A2UI.ValidatorTest do
  use ExUnit.Case, async: true

  alias A2UI.Validator
  alias A2UI.Component

  describe "validate_surface_update/1" do
    test "accepts valid update with few components" do
      components = [
        %Component{id: "a", type: "Text", props: %{}},
        %Component{id: "b", type: "Button", props: %{}}
      ]

      assert :ok = Validator.validate_surface_update(%{components: components})
    end

    test "accepts all allowed component types" do
      types = Validator.allowed_types()

      components =
        Enum.with_index(types)
        |> Enum.map(fn {type, idx} ->
          %Component{id: "comp_#{idx}", type: type, props: %{}}
        end)

      assert :ok = Validator.validate_surface_update(%{components: components})
    end
  end

  describe "validate_count/1" do
    test "accepts components under limit" do
      components =
        Enum.map(1..100, fn i ->
          %Component{id: "#{i}", type: "Text", props: %{}}
        end)

      assert :ok = Validator.validate_count(components)
    end

    test "accepts exactly max components" do
      components =
        Enum.map(1..Validator.max_components(), fn i ->
          %Component{id: "#{i}", type: "Text", props: %{}}
        end)

      assert :ok = Validator.validate_count(components)
    end

    test "rejects components over limit" do
      components =
        Enum.map(1..(Validator.max_components() + 1), fn i ->
          %Component{id: "#{i}", type: "Text", props: %{}}
        end)

      assert {:error, {:too_many_components, count, max}} = Validator.validate_count(components)
      assert count == Validator.max_components() + 1
      assert max == Validator.max_components()
    end
  end

  describe "validate_types/1" do
    test "accepts all allowed types" do
      for type <- Validator.allowed_types() do
        components = [%Component{id: "test", type: type, props: %{}}]
        assert :ok = Validator.validate_types(components)
      end
    end

    test "rejects unknown types" do
      components = [
        %Component{id: "a", type: "Text", props: %{}},
        %Component{id: "b", type: "UnknownWidget", props: %{}},
        %Component{id: "c", type: "CustomThing", props: %{}}
      ]

      assert {:error, {:unknown_component_types, types}} = Validator.validate_types(components)
      assert "UnknownWidget" in types
      assert "CustomThing" in types
      assert length(types) == 2
    end
  end

  describe "validate_depth/1" do
    test "accepts depth under limit" do
      assert :ok = Validator.validate_depth(10)
      assert :ok = Validator.validate_depth(0)
    end

    test "accepts exactly max depth" do
      assert :ok = Validator.validate_depth(Validator.max_depth())
    end

    test "rejects depth over limit" do
      over_limit = Validator.max_depth() + 1

      assert {:error, {:max_depth_exceeded, ^over_limit, max}} =
               Validator.validate_depth(over_limit)

      assert max == Validator.max_depth()
    end
  end

  describe "validate_template_items/1" do
    test "accepts items under limit" do
      assert :ok = Validator.validate_template_items(50)
    end

    test "accepts exactly max items" do
      assert :ok = Validator.validate_template_items(Validator.max_template_items())
    end

    test "rejects items over limit" do
      over_limit = Validator.max_template_items() + 1

      assert {:error, {:too_many_template_items, ^over_limit, max}} =
               Validator.validate_template_items(over_limit)

      assert max == Validator.max_template_items()
    end
  end

  describe "validate_data_model_size/1" do
    test "accepts small data model" do
      data = %{"name" => "Alice", "items" => [1, 2, 3]}
      assert :ok = Validator.validate_data_model_size(data)
    end

    test "accepts empty data model" do
      assert :ok = Validator.validate_data_model_size(%{})
    end
  end

  describe "cycle detection" do
    test "check_cycle/2 returns :ok when component not visited" do
      visited = MapSet.new(["a", "b", "c"])
      assert :ok = Validator.check_cycle("d", visited)
    end

    test "check_cycle/2 returns error when cycle detected" do
      visited = MapSet.new(["a", "b", "c"])
      assert {:error, {:cycle_detected, "b"}} = Validator.check_cycle("b", visited)
    end

    test "check_cycle/2 works with empty visited set" do
      visited = Validator.new_visited()
      assert :ok = Validator.check_cycle("any", visited)
    end

    test "track_visited/2 adds component to visited set" do
      visited = Validator.new_visited()
      visited = Validator.track_visited("a", visited)
      visited = Validator.track_visited("b", visited)

      assert MapSet.member?(visited, "a")
      assert MapSet.member?(visited, "b")
      refute MapSet.member?(visited, "c")
    end

    test "new_visited/0 returns empty MapSet" do
      visited = Validator.new_visited()
      assert visited == MapSet.new()
    end
  end

  describe "URL scheme validation" do
    test "validate_media_url/1 accepts https URLs" do
      assert {:ok, "https://example.com/image.png"} =
               Validator.validate_media_url("https://example.com/image.png")
    end

    test "validate_media_url/1 accepts http URLs" do
      assert {:ok, "http://example.com/image.png"} =
               Validator.validate_media_url("http://example.com/image.png")
    end

    test "validate_media_url/1 accepts data URLs" do
      data_url = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
      assert {:ok, ^data_url} = Validator.validate_media_url(data_url)
    end

    test "validate_media_url/1 accepts blob URLs" do
      blob_url = "blob:https://example.com/550e8400-e29b-41d4-a716-446655440000"
      assert {:ok, ^blob_url} = Validator.validate_media_url(blob_url)
    end

    test "validate_media_url/1 accepts relative URLs" do
      assert {:ok, "/images/photo.jpg"} = Validator.validate_media_url("/images/photo.jpg")
      assert {:ok, "images/photo.jpg"} = Validator.validate_media_url("images/photo.jpg")
      assert {:ok, "../photo.jpg"} = Validator.validate_media_url("../photo.jpg")
    end

    test "validate_media_url/1 rejects javascript URLs" do
      assert {:error, {:unsafe_scheme, "javascript"}} =
               Validator.validate_media_url("javascript:alert(1)")
    end

    test "validate_media_url/1 rejects vbscript URLs" do
      assert {:error, {:unsafe_scheme, "vbscript"}} =
               Validator.validate_media_url("vbscript:msgbox(1)")
    end

    test "validate_media_url/1 rejects file URLs" do
      assert {:error, {:unsafe_scheme, "file"}} =
               Validator.validate_media_url("file:///etc/passwd")
    end

    test "validate_media_url/1 rejects ftp URLs" do
      assert {:error, {:unsafe_scheme, "ftp"}} =
               Validator.validate_media_url("ftp://example.com/file.txt")
    end

    test "validate_media_url/1 rejects nil" do
      assert {:error, :invalid_url} = Validator.validate_media_url(nil)
    end

    test "validate_media_url/1 rejects empty string" do
      assert {:error, :invalid_url} = Validator.validate_media_url("")
    end

    test "validate_media_url/1 rejects non-string values" do
      assert {:error, :invalid_url} = Validator.validate_media_url(123)
      assert {:error, :invalid_url} = Validator.validate_media_url(%{})
      assert {:error, :invalid_url} = Validator.validate_media_url(["https://example.com"])
    end

    test "validate_media_url/1 is case-insensitive for schemes" do
      assert {:ok, "HTTPS://example.com/image.png"} =
               Validator.validate_media_url("HTTPS://example.com/image.png")

      assert {:error, {:unsafe_scheme, "javascript"}} =
               Validator.validate_media_url("JAVASCRIPT:alert(1)")
    end

    test "sanitize_media_url/1 returns URL for valid URLs" do
      assert "https://example.com/img.png" =
               Validator.sanitize_media_url("https://example.com/img.png")

      assert "/images/photo.jpg" = Validator.sanitize_media_url("/images/photo.jpg")
    end

    test "sanitize_media_url/1 returns nil for invalid URLs" do
      assert nil == Validator.sanitize_media_url("javascript:alert(1)")
      assert nil == Validator.sanitize_media_url(nil)
      assert nil == Validator.sanitize_media_url("")
    end

    test "allowed_url_schemes/0 returns expected schemes" do
      schemes = Validator.allowed_url_schemes()
      assert "https" in schemes
      assert "http" in schemes
      assert "data" in schemes
      assert "blob" in schemes
      refute "javascript" in schemes
      refute "file" in schemes
    end
  end
end
