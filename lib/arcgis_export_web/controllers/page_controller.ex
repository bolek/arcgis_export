defmodule ArcgisExportWeb.PageController do
  use ArcgisExportWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
