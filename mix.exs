defmodule A2UI.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/lukaszsamson/a2ui_lv"

  def project do
    [
      app: :a2ui_lv,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
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

  def cli do
    [preferred_envs: [precommit: :test]]
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
      # OTP 26 predates the built-in :json module used by digital_token. Keep the
      # dependency locked on every toolchain, but compile and start it only there.
      {:json_polyfill, "~> 0.2.2", json_polyfill_opts()},
      {:jsonschex, "~> 0.8"},
      {:earmark, "~> 1.4"},
      {:ex_cldr_numbers, "~> 2.38"},
      {:ex_cldr_dates_times, "~> 2.25"},
      # Optional: HTTP transport (SSE client)
      {:req, "~> 0.5", optional: true},
      # A2A protocol library
      {:a2a_ex, optional: true},
      # Dev/test only
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:lazy_html, ">= 0.1.0", only: :test}
    ] ++ spec_lint_deps()
  end

  # spec_lint needs Elixir >= 1.18; older CI matrix entries skip it.
  defp spec_lint_deps do
    if Version.match?(System.version(), ">= 1.18.0") do
      [{:spec_lint, "~> 0.1", only: [:dev, :test], runtime: false}]
    else
      []
    end
  end

  defp aliases do
    [
      precommit: ["compile", "deps.unlock --unused", "format --check-formatted", "test"]
    ]
  end

  defp otp_26? do
    System.otp_release()
    |> String.to_integer()
    |> Kernel.==(26)
  end

  defp json_polyfill_opts do
    if otp_26?(), do: [], else: [app: false, compile: false, runtime: false]
  end
end
