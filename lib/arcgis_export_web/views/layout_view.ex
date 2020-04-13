defmodule ArcgisExportWeb.LayoutView do
  use ArcgisExportWeb, :view

  def links(conn) do
    current_path = Phoenix.Controller.current_path(conn)

    [
      %{label: "Home", path: "/", active?: false},
      %{label: "FAQ", path: "/faq", active?: false},
      %{label: "Report Issue", path: "/report", active?: false}
    ]
    |> Enum.map(fn
      %{path: ^current_path} = link -> %{link | active?: true}
      link -> link
    end)
  end
end
