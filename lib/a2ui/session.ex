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

  alias A2UI.{Parser, Surface, Validator, Error, Event, ClientCapabilities}
  alias A2UI.Catalog.Resolver
  alias A2UI.Messages.{SurfaceUpdate, DataModelUpdate, BeginRendering, DeleteSurface}

  @type t :: %__MODULE__{
          surfaces: %{String.t() => Surface.t()},
          client_capabilities: ClientCapabilities.t(),
          retired_surface_ids: struct()
        }

  defstruct surfaces: %{},
            client_capabilities: nil,
            retired_surface_ids: MapSet.new()

  @doc """
  Creates a new empty session.

  ## Options

  - `:client_capabilities` - Optional `A2UI.ClientCapabilities` struct.
    If not provided, defaults to `ClientCapabilities.default()` which includes
    all v0.8 standard catalog aliases.

  ## Example

      # With default capabilities
      session = A2UI.Session.new()

      # With custom capabilities
      caps = A2UI.ClientCapabilities.new(supported_catalog_ids: ["custom.catalog"])
      session = A2UI.Session.new(client_capabilities: caps)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    capabilities =
      case Keyword.get(opts, :client_capabilities) do
        nil -> ClientCapabilities.default()
        %ClientCapabilities{} = capabilities -> capabilities
      end

    %__MODULE__{
      surfaces: %{},
      client_capabilities: capabilities,
      retired_surface_ids: MapSet.new()
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
  @spec apply_json_line(t(), String.t(), keyword()) :: {:ok, t()} | {:error, map()}
  def apply_json_line(session, json_line, opts \\ []) do
    parser_opts = [catalog_schema_resolver: &catalog_schema_for(session, &1, &2)]

    case Parser.parse_line(json_line, parser_opts) do
      {:surface_update, %SurfaceUpdate{} = msg} ->
        apply_message(session, msg)

      {:data_model_update, %DataModelUpdate{} = msg} ->
        apply_message(session, msg)

      {:begin_rendering, %BeginRendering{} = msg} ->
        apply_message(session, %{msg | creator_id: opts[:source]})

      {:delete_surface, %DeleteSurface{} = msg} ->
        apply_message(session, msg)

      {:error, {:json_decode, reason}} ->
        {:error, Error.parse_error("JSON decode failed", reason)}

      {:error, :unknown_message_type} ->
        {:error, Error.parse_error("Unknown message type")}

      {:error, {:validation_failed, path, message}} ->
        {:error, Event.validation_failed(extract_surface_id(json_line), path, message)}

      {:error, reason} ->
        {:error, Error.parse_error("Parse failed", reason)}
    end
  end

  @doc """
  Applies an ordered A2A DataPart message list sequentially.

  A failure is atomic to its individual message: it is collected and processing
  continues with the next message, as required by the v0.9 A2A extension.
  """
  @spec apply_envelopes(t(), [map()], keyword()) :: {t(), [map()]}
  def apply_envelopes(session, envelopes, opts \\ []) when is_list(envelopes) do
    Enum.reduce(envelopes, {session, []}, fn envelope, {current, errors} ->
      case apply_json_line(current, Jason.encode!(envelope), opts) do
        {:ok, updated} -> {updated, errors}
        {:error, error} -> {current, errors ++ [error]}
      end
    end)
  end

  @doc """
  Applies a parsed message to the session.

  Handles `SurfaceUpdate`, `DataModelUpdate`, `BeginRendering`, and `DeleteSurface` messages.
  Returns `{:ok, session}` on success or `{:error, error_map}` on failure.

  ## Examples

      {:ok, session} = A2UI.Session.apply_message(session, surface_update)
      {:error, error} = A2UI.Session.apply_message(session, invalid_update)
  """
  @spec apply_message(
          t(),
          SurfaceUpdate.t() | DataModelUpdate.t() | BeginRendering.t() | DeleteSurface.t()
        ) ::
          {:ok, t()} | {:error, map()}
  def apply_message(session, %SurfaceUpdate{surface_id: sid, components: components} = msg) do
    # Get the surface's catalog_id if it exists (set by prior createSurface/beginRendering)
    # If nil, validator uses permissive mode (all known types across catalogs)
    surface = Map.get(session.surfaces, sid)
    catalog_id = if surface, do: surface.catalog_id, else: nil

    with :ok <- ensure_active_surface(session, sid, msg.protocol_version),
         :ok <- Validator.validate_surface_update(%{components: components}, catalog_id) do
      {:ok, update_surface(session, sid, msg)}
    else
      {:error, {:too_many_components, count, max}} ->
        message = "Too many components: #{count} exceeds limit #{max}"

        error =
          validation_error_for(msg.protocol_version, sid, "/updateComponents/components", message)

        {:error, error}

      {:error, {:unknown_component_types, types}} ->
        {:error, Error.unknown_component(types, sid)}

      {:error, :surface_not_found} ->
        {:error,
         surface_lifecycle_error(
           sid,
           "surface must be created before it is updated",
           msg.protocol_version
         )}
    end
  end

  def apply_message(session, %DataModelUpdate{surface_id: sid} = msg) do
    with :ok <- ensure_active_surface(session, sid, msg.protocol_version),
         :ok <- validate_data_model_indices(session.surfaces[sid], msg) do
      updated = update_surface(session, sid, msg)

      surface = updated.surfaces[sid]

      case Validator.validate_data_model_size(surface.data_model) do
        :ok ->
          {:ok, updated}

        {:error, {:data_model_too_large, size, max}} ->
          error =
            validation_error_for(
              msg.protocol_version,
              sid,
              "/updateDataModel/value",
              "Data model too large: #{size} bytes exceeds #{max}"
            )

          {:error, error}
      end
    else
      {:error, :surface_not_found} ->
        {:error,
         surface_lifecycle_error(
           sid,
           "surface must be created before its data is updated",
           msg.protocol_version
         )}

      {:error, {:invalid_array_index, message}} ->
        {:error,
         validation_error_for(msg.protocol_version, sid, "/updateDataModel/path", message)}
    end
  end

  def apply_message(
        session,
        %BeginRendering{surface_id: sid, catalog_id: catalog_id, protocol_version: version} = msg
      ) do
    # Use the message's protocol version for catalog resolution
    # v0.8: nil catalogId defaults to standard, v0.9: catalogId is required
    version = version || :v0_8

    with :ok <- ensure_surface_id_available(session, sid, version),
         {:ok, resolved_catalog_id} <-
           Resolver.resolve(catalog_id, session.client_capabilities, version) do
      # Use the resolved catalog ID (canonical form)
      updated_msg = %{msg | catalog_id: resolved_catalog_id}
      updated = update_surface_with_catalog(session, sid, updated_msg, :ok)
      {:ok, updated}

      # Note: Root component validation is NOT done here because:
      # - v0.8: beginRendering can specify any root_id, doesn't require id="root"
      # - v0.9: createSurface comes BEFORE updateComponents, so components
      #   aren't present yet. Root validation happens at render time.
    else
      {:error, :duplicate_surface_id} ->
        {:error, surface_lifecycle_error(sid, "surfaceId is already active", version)}

      {:error, :retired_surface_id} ->
        {:error,
         surface_lifecycle_error(
           sid,
           "v0.9 surfaceId cannot be reused after deletion",
           version
         )}

      {:error, reason} ->
        error =
          if version in [:v0_9, :v0_9_1] do
            Event.validation_failed(
              sid,
              "/createSurface/catalogId",
              Resolver.format_error(reason)
            )
          else
            Error.catalog_error(
              Resolver.format_error(reason),
              sid,
              Resolver.error_details(catalog_id, reason, version)
            )
          end

        {:error, error}
    end
  end

  def apply_message(session, %DeleteSurface{surface_id: sid, protocol_version: version}) do
    case ensure_active_surface(session, sid, version) do
      :ok ->
        {:ok, delete_surface(session, sid, version)}

      {:error, :surface_not_found} ->
        {:error, surface_lifecycle_error(sid, "surface does not exist", version)}
    end
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

  @spec delete_surface(t(), String.t(), A2UI.Protocol.version() | nil) :: t()
  def delete_surface(session, surface_id, :v0_9) do
    %{
      session
      | surfaces: Map.delete(session.surfaces, surface_id),
        retired_surface_ids: MapSet.put(session.retired_surface_ids, surface_id)
    }
  end

  def delete_surface(session, surface_id, _version), do: delete_surface(session, surface_id)

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
              validation_error_for(
                surface.protocol_version,
                surface_id,
                path,
                "Data model too large: #{size} bytes exceeds #{max}"
              )

            {:error, error}
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

  @doc """
  Returns the client capabilities for this session.

  This is useful for A2A transport implementations that need to attach
  capabilities to every outgoing message.
  """
  @spec client_capabilities(t()) :: ClientCapabilities.t()
  def client_capabilities(session), do: session.client_capabilities

  @doc """
  Checks if the session supports a given catalog ID.

  Delegates to `ClientCapabilities.supports_catalog?/2`.
  """
  @spec supports_catalog?(t(), String.t()) :: boolean()
  def supports_catalog?(session, catalog_id) do
    ClientCapabilities.supports_catalog?(session.client_capabilities, catalog_id)
  end

  # Private helpers

  defp catalog_schema_for(session, decoded, version) do
    catalog_id =
      get_in(decoded, ["createSurface", "catalogId"]) ||
        case message_surface_id(decoded) do
          nil -> nil
          surface_id -> get_in(session.surfaces, [surface_id, Access.key(:catalog_id)])
        end

    cond do
      is_nil(catalog_id) ->
        nil

      A2UI.Protocol.standard_catalog_id?(version, catalog_id) ->
        nil

      true ->
        case A2UI.Schema.catalog_schema(catalog_id, version) do
          {:ok, schema} -> schema
          :error -> nil
        end
    end
  end

  defp message_surface_id(decoded) do
    Enum.find_value(~w(updateComponents updateDataModel deleteSurface), fn key ->
      get_in(decoded, [key, "surfaceId"])
    end)
  end

  defp validate_data_model_indices(_surface, %DataModelUpdate{protocol_version: version})
       when version in [nil, :v0_8],
       do: :ok

  defp validate_data_model_indices(surface, %DataModelUpdate{path: path}) do
    case A2UI.JsonPointer.validate_indices(surface.data_model, path) do
      :ok -> :ok
      {:error, message} -> {:error, {:invalid_array_index, message}}
    end
  end

  defp update_surface(session, surface_id, message) do
    surface = Map.get(session.surfaces, surface_id) || Surface.new(surface_id)
    updated = Surface.apply_message(surface, message)
    %{session | surfaces: Map.put(session.surfaces, surface_id, updated)}
  end

  defp update_surface_with_catalog(session, surface_id, %BeginRendering{} = msg, catalog_status) do
    surface = Map.get(session.surfaces, surface_id) || Surface.new(surface_id)
    updated = Surface.apply_begin_rendering(surface, msg, catalog_status)
    %{session | surfaces: Map.put(session.surfaces, surface_id, updated)}
  end

  defp ensure_active_surface(_session, _surface_id, version) when version in [nil, :v0_8], do: :ok

  defp ensure_active_surface(session, surface_id, _version) do
    if Map.has_key?(session.surfaces, surface_id), do: :ok, else: {:error, :surface_not_found}
  end

  defp ensure_surface_id_available(session, surface_id, version) do
    cond do
      version == :v0_8 ->
        :ok

      Map.has_key?(session.surfaces, surface_id) ->
        {:error, :duplicate_surface_id}

      version == :v0_9 and MapSet.member?(session.retired_surface_ids, surface_id) ->
        {:error, :retired_surface_id}

      true ->
        :ok
    end
  end

  defp surface_lifecycle_error(surface_id, message, version) do
    validation_error_for(version, surface_id, "/surfaceId", message)
  end

  defp validation_error_for(version, surface_id, path, message)
       when version in [:v0_9, :v0_9_1] do
    Event.validation_failed(surface_id, path, message)
  end

  defp validation_error_for(_version, surface_id, _path, message) do
    Error.validation_error(message, surface_id, %{"surfaceId" => surface_id})
  end

  defp extract_surface_id(json_line) do
    with {:ok, decoded} <- Jason.decode(json_line),
         envelope when is_map(envelope) <-
           Enum.find_value(
             ~w(createSurface updateComponents updateDataModel deleteSurface),
             fn key ->
               decoded[key]
             end
           ),
         surface_id when is_binary(surface_id) <- envelope["surfaceId"] do
      surface_id
    else
      _ -> ""
    end
  end
end
