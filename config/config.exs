# This file is responsible for configuring the A2UI library.
# For demo app configuration, see demo/config/config.exs

import Config

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config if it exists
# (library typically doesn't need env-specific config)
if File.exists?("#{__DIR__}/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
