defmodule ArcgisExport.Repo do
  use Ecto.Repo,
    otp_app: :arcgis_export,
    adapter: Ecto.Adapters.Postgres
end
