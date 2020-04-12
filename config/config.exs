# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :arcgis_export,
  ecto_repos: [ArcgisExport.Repo]

# Configures the endpoint
config :arcgis_export, ArcgisExportWeb.Endpoint,
  http: [
    protocol_options: [idle_timeout: 10 * 60 * 1000]
  ],
  url: [host: "localhost"],
  secret_key_base: "SKLUf0yK/ACfzpm0AH/NfG4Zyw/B1ze24RqZZnTQrbcpkiW+y+5Y9CMIDwZhm6b0",
  render_errors: [view: ArcgisExportWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: ArcgisExport.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "ybrfAJHX"],
  live_view: [
    signing_salt: "L5FgPS8tfWf0c0bLW1LndEyKWO3NdF7d"
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
