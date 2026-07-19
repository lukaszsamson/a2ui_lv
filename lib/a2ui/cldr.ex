defmodule A2UI.Cldr do
  @moduledoc false

  use Cldr,
    default_locale: "en",
    locales: Application.compile_env(:a2ui_lv, :locales, ["en"]),
    providers: [Cldr.Number, Cldr.Calendar, Cldr.DateTime]
end
