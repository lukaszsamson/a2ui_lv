defmodule A2UI.Session do
  @moduledoc """
  Pure state container for A2UI surfaces.

  This module provides a Phoenix-free state machine for managing A2UI surfaces.
  It can be used directly by non-Phoenix applications or wrapped by Phoenix
  LiveView adapters like `A2UI.Phoenix.Live`.

  Per the renderer development guide:
  - Buffers `surfaceUpdate` and `dataModelUpdate` messages
  - Flips "ready" on `beginRendering` (root id + optional catalogId + optional styles)
  - Supports `deleteSurface`

  ## Example

      # Create a new session
      session = A2UI.Session.new()

      # Apply incoming JSONL messages
      {:ok, session} = A2UI.Session.apply_json_line(session, json_line)

      # Or apply parsed messages directly
      {:ok, session} = A2UI.Session.apply_message(session, surface_update_msg)

      # Get a specific surface
      {:ok, surface} = A2UI.Session.get_surface(session, "my-surface")

      # Delete a surface
      session = A2UI.Session.delete_surface(session, "my-surface")
  """

  alias A2UI.{Parser, Surface, Validator, Error}
  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}

  @type t :: %__MODULE__{
          surfaces: %{String.t() => Surface.t()},
          client_capabilities: map() | nil
        }

  defstruct surfaces: %{},
            client_capabilities: nil

  @doc """
  Creates a new empty session.

  ## Options

  - `:client_capabilities` - Optional client capabilities map
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      surfaces: %{},
      client_capabilities: opts[:client_capabilities]
    }
  end

  @doc """
  Applies a JSONL line to the session.

  Parses the JSON line and applies the resulting message to the session state.
  Returns `{:ok, session}` on success or `{:error, error_map}` on failure.

  ## Examples

      {:ok, session} = A2UI.Session.apply_json_line(session, ~s({"surfaceUpdate":...}))
      {:error, error} = A2UI.Session.apply_json_line(session, "invalid json")
  """
  @spec apply_json_line(t(), String.t()) :: {:ok, t()} | {:error, map()}
  def apply_json_line(session, json_line) do
    case Parser.parse_line(json_line) do
      {:surface_update, %SurfaceUpdate{} = msg} ->
        apply_message(session, msg)

      {:data_model_update, %DataModelUpdate{} = msg} ->
        apply_message(session, msg)

      {:begin_rendering, %BeginRendering{} = msg} ->
        apply_message(session, msg)

      {:delete_surface, %DeleteSurface{surface_id: sid}} ->
        {:ok, delete_surface(session, sid)}

      {:error, {:json_decode, reason}} ->
        {:error, Error.parse_error("JSON decode failed", reason)}

      {:error, :unknown_message_type} ->
        {:error, Error.parse_error("Unknown message type")}

      {:error, reason} ->
        {:error, Error.parse_error("Parse failed", reason)}
    end
  end

  @doc """
  Applies a parsed message to the session.

  Handles `SurfaceUpdate`, `DataModelUpdate`, `BeginRendering`, and `DeleteSurface` messages.
  Returns `{:ok, session}` on success or `{:error, error_map}` on failure.

  ## Examples

      {:ok, session} = A2UI.Session.apply_message(session, surface_update)
      {:error, error} = A2UI.Session.apply_message(session, invalid_update)
  """
  @spec apply_message(t(), SurfaceUpdate.t() | DataModelUpdate.t() | BeginRendering.t() | DeleteSurface.t()) ::
          {:ok, t()} | {:error, map()}
  def apply_message(session, %SurfaceUpdate{surface_id: sid} = msg) do
    case Validator.validate_surface_update(msg) do
      :ok ->
        {:ok, update_surface(session, sid, msg)}

      {:error, {:too_many_components, count, max}} ->
        error =
          Error.validation_error(
            "Too many components: #{count} exceeds limit #{max}",
            sid,
            %{"count" => count, "limit" => max}
          )

        {:error, error}

      {:error, {:unknown_component_types, types}} ->
        {:error, Error.unknown_component(types, sid)}

      {:error, reason} ->
        {:error, Error.validation_error("Validation failed: #{inspect(reason)}", sid)}
    end
  end

  def apply_message(session, %DataModelUpdate{surface_id: sid} = msg) do
    updated = update_surface(session, sid, msg)

    surface = updated.surfaces[sid]

    case Validator.validate_data_model_size(surface.data_model) do
      :ok ->
        {:ok, updated}

      {:error, {:data_model_too_large, size, max}} ->
        error =
          Error.validation_error(
            "Data model too large: #{size} bytes exceeds #{max}",
            sid,
            %{"size" => size, "limit" => max}
          )

        {:error, error}

      {:error, reason} ->
        {:error, Error.validation_error("Data model validation failed: #{inspect(reason)}", sid)}
    end
  end

  def apply_message(session, %BeginRendering{surface_id: sid} = msg) do
    {:ok, update_surface(session, sid, msg)}
  end

  def apply_message(session, %DeleteSurface{surface_id: sid}) do
    {:ok, delete_surface(session, sid)}
  end

  @doc """
  Gets a surface by ID.

  Returns `{:ok, surface}` if found, or `{:error, :not_found}` if the surface doesn't exist.
  """
  @spec get_surface(t(), String.t()) :: {:ok, Surface.t()} | {:error, :not_found}
  def get_surface(session, surface_id) do
    case Map.fetch(session.surfaces, surface_id) do
      {:ok, surface} -> {:ok, surface}
      :error -> {:error, :not_found}
    end
  end

  @doc """
  Lists all surface IDs in the session.
  """
  @spec list_surface_ids(t()) :: [String.t()]
  def list_surface_ids(session) do
    Map.keys(session.surfaces)
  end

  @doc """
  Deletes a surface by ID.

  Returns the updated session. If the surface doesn't exist, the session is returned unchanged.
  """
  @spec delete_surface(t(), String.t()) :: t()
  def delete_surface(session, surface_id) do
    %{session | surfaces: Map.delete(session.surfaces, surface_id)}
  end

  @doc """
  Updates a value at a specific path in a surface's data model.

  This is used for two-way binding when user input changes a value.
  Returns `{:ok, session}` on success or `{:error, error_map}` on failure.
  """
  @spec update_data_at_path(t(), String.t(), String.t(), term()) :: {:ok, t()} | {:error, map()}
  def update_data_at_path(session, surface_id, path, value) do
    case Map.fetch(session.surfaces, surface_id) do
      {:ok, surface} ->
        updated_surface = Surface.update_data_at_path(surface, path, value)

        case Validator.validate_data_model_size(updated_surface.data_model) do
          :ok ->
            {:ok, %{session | surfaces: Map.put(session.surfaces, surface_id, updated_surface)}}

          {:error, {:data_model_too_large, size, max}} ->
            error =
              Error.validation_error(
                "Data model too large: #{size} bytes exceeds #{max}",
                surface_id,
                %{"size" => size, "limit" => max}
              )

            {:error, error}

          {:error, reason} ->
            {:error, Error.validation_error("Data validation failed: #{inspect(reason)}", surface_id)}
        end

      :error ->
        # Surface doesn't exist, return session unchanged
        {:ok, session}
    end
  end

  @doc """
  Returns the number of surfaces in the session.
  """
  @spec surface_count(t()) :: non_neg_integer()
  def surface_count(session) do
    map_size(session.surfaces)
  end

  # Private helpers

  defp update_surface(session, surface_id, message) do
    surface = Map.get(session.surfaces, surface_id) || Surface.new(surface_id)
    updated = Surface.apply_message(surface, message)
    %{session | surfaces: Map.put(session.surfaces, surface_id, updated)}
  end
end
