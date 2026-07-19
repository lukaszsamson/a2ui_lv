defmodule A2UI.V0_9_1 do
  @moduledoc "Protocol constants and explicit parsing entrypoints for A2UI v0.9.1."

  alias A2UI.{JSON, Protocol}

  def standard_catalog_id, do: Protocol.standard_catalog_id(:v0_9_1)
  def standard_catalog_ids, do: Protocol.standard_catalog_ids(:v0_9_1)
  def standard_catalog_id?(catalog_id), do: Protocol.standard_catalog_id?(:v0_9_1, catalog_id)
  def extension_uri, do: Protocol.extension_uri(:v0_9_1)

  def parse_line(jsonl_line) do
    with {:ok, decoded} <- JSON.decode_line(jsonl_line),
         :ok <- A2UI.Validator.validate_server_message(decoded, :v0_9_1) do
      A2UI.Parser.V0_9.parse_map(Map.delete(decoded, "version"), :v0_9_1)
    end
  rescue
    exception -> {:error, {:parse_exception, exception}}
  end

  def parse_map(decoded) do
    with :ok <- A2UI.Validator.validate_server_message(decoded, :v0_9_1) do
      A2UI.Parser.V0_9.parse_map(Map.delete(decoded, "version"), :v0_9_1)
    end
  end
end
