defmodule A2UI.DataBroadcastTest do
  use ExUnit.Case, async: true

  alias A2UI.DataBroadcast
  alias A2UI.Surface

  describe "build/1" do
    test "builds broadcast payload for surfaces with broadcasting enabled" do
      surfaces = %{
        "main" => %Surface{id: "main", data_model: %{"x" => 1}, broadcast_data_model?: true},
        "other" => %Surface{id: "other", data_model: %{"y" => 2}, broadcast_data_model?: false}
      }

      assert DataBroadcast.build(surfaces) == %{"surfaces" => %{"main" => %{"x" => 1}}}
    end

    test "includes multiple broadcasting surfaces" do
      surfaces = %{
        "main" => %Surface{id: "main", data_model: %{"x" => 1}, broadcast_data_model?: true},
        "sidebar" => %Surface{id: "sidebar", data_model: %{"y" => 2}, broadcast_data_model?: true},
        "other" => %Surface{id: "other", data_model: %{"z" => 3}, broadcast_data_model?: false}
      }

      result = DataBroadcast.build(surfaces)
      assert result["surfaces"]["main"] == %{"x" => 1}
      assert result["surfaces"]["sidebar"] == %{"y" => 2}
      refute Map.has_key?(result["surfaces"], "other")
    end

    test "returns nil when no surfaces have broadcasting enabled" do
      surfaces = %{
        "main" => %Surface{id: "main", data_model: %{}, broadcast_data_model?: false}
      }

      assert DataBroadcast.build(surfaces) == nil
    end

    test "returns nil for empty surfaces map" do
      assert DataBroadcast.build(%{}) == nil
    end

    test "returns nil for non-map input" do
      assert DataBroadcast.build(nil) == nil
      assert DataBroadcast.build([]) == nil
    end

    test "includes empty data models when broadcasting is enabled" do
      surfaces = %{
        "main" => %Surface{id: "main", data_model: %{}, broadcast_data_model?: true}
      }

      assert DataBroadcast.build(surfaces) == %{"surfaces" => %{"main" => %{}}}
    end

    test "includes complex nested data models" do
      surfaces = %{
        "main" => %Surface{
          id: "main",
          data_model: %{
            "user" => %{
              "profile" => %{"name" => "Alice", "age" => 30},
              "settings" => %{"theme" => "dark"}
            },
            "items" => [1, 2, 3]
          },
          broadcast_data_model?: true
        }
      }

      result = DataBroadcast.build(surfaces)
      assert result["surfaces"]["main"]["user"]["profile"]["name"] == "Alice"
      assert result["surfaces"]["main"]["items"] == [1, 2, 3]
    end
  end

  describe "build_for_surface/1" do
    test "builds payload for surface with broadcasting enabled" do
      surface = %Surface{id: "main", data_model: %{"x" => 1}, broadcast_data_model?: true}
      assert DataBroadcast.build_for_surface(surface) == %{"surfaces" => %{"main" => %{"x" => 1}}}
    end

    test "returns nil for surface without broadcasting" do
      surface = %Surface{id: "main", data_model: %{"x" => 1}, broadcast_data_model?: false}
      assert DataBroadcast.build_for_surface(surface) == nil
    end

    test "returns nil for non-surface input" do
      assert DataBroadcast.build_for_surface(nil) == nil
      assert DataBroadcast.build_for_surface(%{}) == nil
    end
  end

  describe "any_broadcasting?/1" do
    test "returns true when at least one surface has broadcasting enabled" do
      surfaces = %{
        "main" => %Surface{broadcast_data_model?: true},
        "other" => %Surface{broadcast_data_model?: false}
      }

      assert DataBroadcast.any_broadcasting?(surfaces) == true
    end

    test "returns false when no surfaces have broadcasting enabled" do
      surfaces = %{
        "main" => %Surface{broadcast_data_model?: false}
      }

      assert DataBroadcast.any_broadcasting?(surfaces) == false
    end

    test "returns false for empty surfaces map" do
      assert DataBroadcast.any_broadcasting?(%{}) == false
    end

    test "returns false for non-map input" do
      assert DataBroadcast.any_broadcasting?(nil) == false
      assert DataBroadcast.any_broadcasting?([]) == false
    end
  end

  describe "broadcasting_surface_ids/1" do
    test "returns list of surface IDs with broadcasting enabled" do
      surfaces = %{
        "main" => %Surface{id: "main", broadcast_data_model?: true},
        "sidebar" => %Surface{id: "sidebar", broadcast_data_model?: true},
        "other" => %Surface{id: "other", broadcast_data_model?: false}
      }

      result = DataBroadcast.broadcasting_surface_ids(surfaces) |> Enum.sort()
      assert result == ["main", "sidebar"]
    end

    test "returns empty list when no surfaces have broadcasting enabled" do
      surfaces = %{
        "main" => %Surface{id: "main", broadcast_data_model?: false}
      }

      assert DataBroadcast.broadcasting_surface_ids(surfaces) == []
    end

    test "returns empty list for empty surfaces map" do
      assert DataBroadcast.broadcasting_surface_ids(%{}) == []
    end

    test "returns empty list for non-map input" do
      assert DataBroadcast.broadcasting_surface_ids(nil) == []
    end
  end

  describe "merge/2" do
    test "merges two broadcast payloads" do
      payload1 = %{"surfaces" => %{"a" => %{"x" => 1}}}
      payload2 = %{"surfaces" => %{"b" => %{"y" => 2}}}

      assert DataBroadcast.merge(payload1, payload2) == %{
               "surfaces" => %{"a" => %{"x" => 1}, "b" => %{"y" => 2}}
             }
    end

    test "returns other payload when one is nil" do
      payload = %{"surfaces" => %{"a" => %{}}}

      assert DataBroadcast.merge(nil, payload) == payload
      assert DataBroadcast.merge(payload, nil) == payload
    end

    test "returns nil when both are nil" do
      assert DataBroadcast.merge(nil, nil) == nil
    end

    test "later payload overwrites same surface ID" do
      payload1 = %{"surfaces" => %{"a" => %{"x" => 1}}}
      payload2 = %{"surfaces" => %{"a" => %{"x" => 2}}}

      assert DataBroadcast.merge(payload1, payload2) == %{"surfaces" => %{"a" => %{"x" => 2}}}
    end
  end

  describe "validate/1" do
    test "returns :ok for valid payload" do
      assert DataBroadcast.validate(%{"surfaces" => %{"main" => %{}}}) == :ok
    end

    test "returns :ok for payload with multiple surfaces" do
      payload = %{"surfaces" => %{"a" => %{"x" => 1}, "b" => %{"y" => 2}}}
      assert DataBroadcast.validate(payload) == :ok
    end

    test "returns error for missing surfaces key" do
      assert DataBroadcast.validate(%{"invalid" => %{}}) == {:error, :missing_surfaces_key}
    end

    test "returns error for surfaces not being a map" do
      assert DataBroadcast.validate(%{"surfaces" => "not a map"}) == {:error, :surfaces_not_a_map}
      assert DataBroadcast.validate(%{"surfaces" => []}) == {:error, :surfaces_not_a_map}
    end

    test "returns error for invalid surface entry" do
      assert DataBroadcast.validate(%{"surfaces" => %{123 => %{}}}) == {:error, :invalid_surface_entry}
      assert DataBroadcast.validate(%{"surfaces" => %{"main" => "not a map"}}) ==
               {:error, :invalid_surface_entry}
    end

    test "returns error for non-map input" do
      assert DataBroadcast.validate(nil) == {:error, :not_a_map}
      assert DataBroadcast.validate("string") == {:error, :not_a_map}
    end
  end
end
