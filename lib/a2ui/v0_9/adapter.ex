defmodule A2UI.V0_9.Adapter do
  @moduledoc """
  v0.9 → v0.8 adapter stub.

  The renderer implementation in this repo ingests and applies v0.8 messages.
  This module exists to match the documented upgrade path in `DESIGN_V1.md`.

  If you decide to support v0.9 messages, implement a translation layer that:
  - Reads v0.9 envelopes (`updateComponents`, `updateDataModel`, `createSurface`, `deleteSurface`)
  - Produces the equivalent internal v0.8 structs (`A2UI.Messages.*`)
  - Preserves semantics (especially `updateDataModel.updates` and template scoping)
  """

  @spec translate_line(String.t()) :: {:ok, term()} | {:error, term()}
  def translate_line(_jsonl_line), do: {:error, :v0_9_not_implemented}
end
