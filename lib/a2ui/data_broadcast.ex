defmodule A2UI.DataBroadcast do
  @moduledoc """
  Builds A2UI data model broadcast payloads for A2A message metadata.

  Per the v0.9 spec, when `broadcastDataModel` is enabled on a surface,
  the full data model should be included in the metadata of every outgoing
  A2A message.

  ## Payload Format

  Per `a2ui_data_broadcast.json`:

      %{
        "surfaces" => %{
          "surfaceId1" => %{...data_model...},
          "surfaceId2" => %{...data_model...}
        }
      }

  This payload should be placed in the `a2uiDataBroadcast` field of
  A2A message metadata.

  ## Usage

      # Build broadcast payload from a map of surfaces
      payload = A2UI.DataBroadcast.build(surfaces)
      #=> %{"surfaces" => %{"main" => %{"user" => %{"name" => "Alice"}}}}

      # Check if any surfaces have broadcasting enabled
      A2UI.DataBroadcast.any_broadcasting?(surfaces)
      #=> true

  ## Transport Integration

  When sending events via A2A transport, include the broadcast payload:

      opts = [data_broadcast: A2UI.DataBroadcast.build(surfaces)]
      MyTransport.send_event(transport, event, opts)

  The A2A transport implementation would then include this in metadata:

      metadata = %{
        "a2uiDataBroadcast" => opts[:data_broadcast]
      }
  """

  alias A2UI.Surface

  @type surfaces :: %{String.t() => Surface.t()}
  @type broadcast_payload :: %{String.t() => %{String.t() => map()}}

  @doc """
  Builds a data broadcast payload from a map of surfaces.

  Only includes surfaces that have `broadcast_data_model?` set to `true`.
  Returns `nil` if no surfaces have broadcasting enabled.

  ## Examples

      iex> surfaces = %{
      ...>   "main" => %A2UI.Surface{id: "main", data_model: %{"x" => 1}, broadcast_data_model?: true},
      ...>   "other" => %A2UI.Surface{id: "other", data_model: %{"y" => 2}, broadcast_data_model?: false}
      ...> }
      iex> A2UI.DataBroadcast.build(surfaces)
      %{"surfaces" => %{"main" => %{"x" => 1}}}

      iex> surfaces = %{
      ...>   "main" => %A2UI.Surface{id: "main", data_model: %{}, broadcast_data_model?: false}
      ...> }
      iex> A2UI.DataBroadcast.build(surfaces)
      nil
  """
  @spec build(surfaces()) :: broadcast_payload() | nil
  def build(surfaces) when is_map(surfaces) do
    broadcasting_surfaces =
      surfaces
      |> Enum.filter(fn {_id, surface} ->
        surface.broadcast_data_model? == true
      end)
      |> Enum.map(fn {id, surface} ->
        {id, surface.data_model}
      end)
      |> Map.new()

    if map_size(broadcasting_surfaces) > 0 do
      %{"surfaces" => broadcasting_surfaces}
    else
      nil
    end
  end

  def build(_), do: nil

  @doc """
  Builds a data broadcast payload for a single surface.

  Returns `nil` if the surface doesn't have broadcasting enabled.

  ## Examples

      iex> surface = %A2UI.Surface{id: "main", data_model: %{"x" => 1}, broadcast_data_model?: true}
      iex> A2UI.DataBroadcast.build_for_surface(surface)
      %{"surfaces" => %{"main" => %{"x" => 1}}}

      iex> surface = %A2UI.Surface{id: "main", data_model: %{"x" => 1}, broadcast_data_model?: false}
      iex> A2UI.DataBroadcast.build_for_surface(surface)
      nil
  """
  @spec build_for_surface(Surface.t()) :: broadcast_payload() | nil
  def build_for_surface(%Surface{broadcast_data_model?: true} = surface) do
    %{"surfaces" => %{surface.id => surface.data_model}}
  end

  def build_for_surface(_), do: nil

  @doc """
  Returns true if any surface has broadcasting enabled.

  ## Examples

      iex> surfaces = %{
      ...>   "main" => %A2UI.Surface{broadcast_data_model?: true},
      ...>   "other" => %A2UI.Surface{broadcast_data_model?: false}
      ...> }
      iex> A2UI.DataBroadcast.any_broadcasting?(surfaces)
      true

      iex> surfaces = %{
      ...>   "main" => %A2UI.Surface{broadcast_data_model?: false}
      ...> }
      iex> A2UI.DataBroadcast.any_broadcasting?(surfaces)
      false
  """
  @spec any_broadcasting?(surfaces()) :: boolean()
  def any_broadcasting?(surfaces) when is_map(surfaces) do
    Enum.any?(surfaces, fn {_id, surface} ->
      surface.broadcast_data_model? == true
    end)
  end

  def any_broadcasting?(_), do: false

  @doc """
  Returns the list of surface IDs that have broadcasting enabled.

  ## Examples

      iex> surfaces = %{
      ...>   "main" => %A2UI.Surface{id: "main", broadcast_data_model?: true},
      ...>   "sidebar" => %A2UI.Surface{id: "sidebar", broadcast_data_model?: true},
      ...>   "other" => %A2UI.Surface{id: "other", broadcast_data_model?: false}
      ...> }
      iex> A2UI.DataBroadcast.broadcasting_surface_ids(surfaces) |> Enum.sort()
      ["main", "sidebar"]
  """
  @spec broadcasting_surface_ids(surfaces()) :: [String.t()]
  def broadcasting_surface_ids(surfaces) when is_map(surfaces) do
    surfaces
    |> Enum.filter(fn {_id, surface} -> surface.broadcast_data_model? == true end)
    |> Enum.map(fn {id, _surface} -> id end)
  end

  def broadcasting_surface_ids(_), do: []

  @doc """
  Merges multiple broadcast payloads into one.

  Useful when aggregating broadcasts from multiple sources.

  ## Examples

      iex> payload1 = %{"surfaces" => %{"a" => %{"x" => 1}}}
      iex> payload2 = %{"surfaces" => %{"b" => %{"y" => 2}}}
      iex> A2UI.DataBroadcast.merge(payload1, payload2)
      %{"surfaces" => %{"a" => %{"x" => 1}, "b" => %{"y" => 2}}}

      iex> A2UI.DataBroadcast.merge(nil, %{"surfaces" => %{"a" => %{}}})
      %{"surfaces" => %{"a" => %{}}}
  """
  @spec merge(broadcast_payload() | nil, broadcast_payload() | nil) :: broadcast_payload() | nil
  def merge(nil, nil), do: nil
  def merge(nil, payload), do: payload
  def merge(payload, nil), do: payload

  def merge(%{"surfaces" => surfaces1}, %{"surfaces" => surfaces2}) do
    %{"surfaces" => Map.merge(surfaces1, surfaces2)}
  end

  @doc """
  Validates a broadcast payload structure.

  Returns `:ok` if valid, `{:error, reason}` otherwise.

  ## Examples

      iex> A2UI.DataBroadcast.validate(%{"surfaces" => %{"main" => %{}}})
      :ok

      iex> A2UI.DataBroadcast.validate(%{"invalid" => %{}})
      {:error, :missing_surfaces_key}

      iex> A2UI.DataBroadcast.validate(%{"surfaces" => "not a map"})
      {:error, :surfaces_not_a_map}
  """
  @spec validate(term()) :: :ok | {:error, atom()}
  def validate(%{"surfaces" => surfaces}) when is_map(surfaces) do
    if Enum.all?(surfaces, fn {id, data} -> is_binary(id) and is_map(data) end) do
      :ok
    else
      {:error, :invalid_surface_entry}
    end
  end

  def validate(%{"surfaces" => _}), do: {:error, :surfaces_not_a_map}
  def validate(%{} = _map), do: {:error, :missing_surfaces_key}
  def validate(_), do: {:error, :not_a_map}
end
