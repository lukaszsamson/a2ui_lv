defmodule A2UI.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/lukaszsamson/a2ui_lv"

  def project do
    [
      app: :a2ui_lv,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "A2UI",
      source_url: @source_url
    ]
  end

  # Library has no OTP application - it's just modules
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    A2UI protocol renderer for Phoenix LiveView. Renders AI-generated user interfaces
    using the A2UI (Agent-to-UI) specification for LLM-friendly UI rendering.
    """
  end

  defp package do
    [
      maintainers: ["Łukasz Samson"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Library dependencies only - demo app has its own deps
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1"},
      {:jason, "~> 1.2"},
      {:earmark, "~> 1.4"},
      # Optional: HTTP transport (SSE client)
      {:req, "~> 0.5", optional: true},
      # Dev/test only
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end
end
