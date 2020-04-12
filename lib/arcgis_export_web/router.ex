defmodule ArcgisExportWeb.Router do
  use ArcgisExportWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_root_layout, {ArcgisExportWeb.LayoutView, :root}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ArcgisExportWeb do
    pipe_through :browser

    get "/download", PageController, :download

    live "/export", ExporterLive

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", ArcgisExportWeb do
  #   pipe_through :api
  # end
end
