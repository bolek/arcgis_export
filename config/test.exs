use Mix.Config

# Configure your database
config :arcgis_export, ArcgisExport.Repo,
  username: "postgres",
  password: "postgres",
  database: "arcgis_export_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :arcgis_export, ArcgisExportWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
