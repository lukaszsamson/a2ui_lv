defmodule A2UI.Catalog.Components do
  @moduledoc """
  Component type definitions per catalog.

  Each catalog (v0.8, v0.9) defines its own set of valid component types.
  This module provides lookup functions for catalog-aware validation.
  """

  # v0.8 standard catalog components (18 components)
  @v0_8_components ~w(
    Column Row Card Text Divider Button TextField CheckBox
    Icon Image AudioPlayer Video Slider DateTimeInput MultipleChoice List Tabs Modal
  )

  # v0.9 standard catalog components
  # Changes from v0.8:
  # - MultipleChoice renamed to ChoicePicker
  @v0_9_components ~w(
    Column Row Card Text Divider Button TextField CheckBox
    Icon Image AudioPlayer Video Slider DateTimeInput ChoicePicker List Tabs Modal
  )

  @doc """
  Returns the allowed component types for a given catalog ID.

  Returns nil if the catalog is not recognized.
  """
  @spec allowed_types(String.t() | nil) :: [String.t()] | nil
  def allowed_types(nil), do: @v0_8_components

  def allowed_types(catalog_id) when is_binary(catalog_id) do
    cond do
      A2UI.V0_8.standard_catalog_id?(catalog_id) -> @v0_8_components
      A2UI.V0_9.standard_catalog_id?(catalog_id) -> @v0_9_components
      true -> nil
    end
  end

  @doc """
  Checks if a component type is valid for a given catalog.

  Returns true if the catalog is not recognized (permissive for custom catalogs).
  """
  @spec valid_type?(String.t(), String.t() | nil) :: boolean()
  def valid_type?(component_type, catalog_id) do
    case allowed_types(catalog_id) do
      nil -> true
      types -> component_type in types
    end
  end

  @doc """
  Returns component types that are not valid for the given catalog.
  """
  @spec invalid_types([String.t()], String.t() | nil) :: [String.t()]
  def invalid_types(component_types, catalog_id) do
    case allowed_types(catalog_id) do
      nil -> []
      allowed -> Enum.reject(component_types, &(&1 in allowed)) |> Enum.uniq()
    end
  end

  @doc """
  Returns all known component types across all catalogs.

  Useful for permissive validation when catalog is not yet known.
  """
  @spec all_known_types() :: [String.t()]
  def all_known_types do
    (@v0_8_components ++ @v0_9_components) |> Enum.uniq()
  end
end
