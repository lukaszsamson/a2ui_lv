# This file is responsible for configuring the A2UI Demo application
# and its dependencies.

import Config

config :a2ui_demo,
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :a2ui_demo, A2UIDemoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: A2UIDemoWeb.ErrorHTML, json: A2UIDemoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: A2UIDemo.PubSub,
  live_view: [signing_salt: "iqOjUdD0"]

# Configure the mailer
config :a2ui_demo, A2UIDemo.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  a2ui_demo: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  a2ui_demo: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
