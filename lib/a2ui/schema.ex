defmodule A2UI.Schema do
  @moduledoc """
  Draft 2020-12 validation for the released A2UI protocol schemas.

  Official schemas are loaded from `priv/a2ui/spec` and compiled with the
  catalog selected by the surface. No network access is performed at runtime.
  """

  @type released_version :: :v0_9 | :v0_9_1

  @spec validate_server_message(map(), released_version(), map() | nil) ::
          :ok | {:error, {String.t(), String.t()}} | {:error, term()}
  def validate_server_message(message, version, catalog_schema \\ nil)
      when is_map(message) and version in [:v0_9, :v0_9_1] do
    with {:ok, compiled} <- compiled_server_schema(version, catalog_schema),
         :ok <- JSONSchex.validate(compiled, message) do
      :ok
    else
      {:error, [%JSONSchex.Types.Error{} | _] = errors} ->
        error = best_error(errors)
        formatted = JSONSchex.format_error(error)
        {path, message} = split_formatted_error(formatted, error.path)
        {:error, {path, message}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compiled_server_schema(version, nil) do
    key = {__MODULE__, :server, version}

    case :persistent_term.get(key, nil) do
      nil ->
        with {:ok, compiled} <- compile_server_schema(version, basic_catalog(version)) do
          :persistent_term.put(key, compiled)
          {:ok, compiled}
        end

      compiled ->
        {:ok, compiled}
    end
  end

  defp compiled_server_schema(version, catalog_schema),
    do: compile_server_schema(version, catalog_schema)

  @doc "Returns the released Basic Catalog schema for a protocol version."
  @spec basic_catalog(released_version()) :: map()
  def basic_catalog(version) when version in [:v0_9, :v0_9_1] do
    read_schema!(schema_path(version, "catalogs/basic/catalog.json"))
  end

  @doc "Returns a registered or built-in catalog schema."
  @spec catalog_schema(String.t(), released_version()) :: {:ok, map()} | :error
  def catalog_schema(catalog_id, version) do
    cond do
      A2UI.Protocol.standard_catalog_id?(version, catalog_id) ->
        {:ok, basic_catalog(version)}

      true ->
        A2UI.Catalog.Registry.schema(catalog_id)
    end
  end

  defp compile_server_schema(version, catalog_schema) do
    server_schema = read_schema!(schema_path(version, "json/server_to_client.json"))

    JSONSchex.compile(server_schema,
      loader: loader(version, catalog_schema),
      format_assertion: true
    )
  end

  defp loader(version, catalog_schema) do
    fn uri ->
      uri = uri |> URI.parse() |> Map.put(:fragment, nil) |> URI.to_string()

      cond do
        String.ends_with?(uri, "/catalog.json") ->
          {:ok, catalog_schema}

        String.ends_with?(uri, "/common_types.json") ->
          {:ok, read_schema!(schema_path(version, "json/common_types.json"))}

        true ->
          {:error, {:unknown_a2ui_schema, uri}}
      end
    end
  end

  # Prefer a concrete leaf error over the surrounding oneOf error.
  defp best_error(errors) do
    Enum.max_by(errors, fn error -> length(error.path || []) end)
  end

  defp pointer([]), do: "/"

  defp pointer(path) do
    "/" <> Enum.map_join(path, "/", &escape_segment/1)
  end

  defp split_formatted_error(formatted, fallback_path) do
    case Regex.run(~r/^At (\/[^:]*):\s*(.*)$/s, formatted) do
      [_, path, message] -> {normalize_control_indices(path), message}
      _ -> {pointer(fallback_path), formatted}
    end
  end

  defp normalize_control_indices(path) do
    Regex.replace(~r/[\x00-\x1F]/, path, fn <<index>> -> Integer.to_string(index) end)
  end

  defp escape_segment(segment) do
    segment
    |> to_string()
    |> String.replace("~", "~0")
    |> String.replace("/", "~1")
  end

  defp schema_path(:v0_9, relative), do: Path.join(spec_root(), "v0_9/#{relative}")
  defp schema_path(:v0_9_1, relative), do: Path.join(spec_root(), "v0_9_1/#{relative}")

  defp spec_root do
    :a2ui_lv
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("a2ui/spec")
  end

  defp read_schema!(path) do
    path
    |> File.read!()
    |> Jason.decode!()
  end
end
