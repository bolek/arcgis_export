defmodule ArcgisExportWeb.PageController do
  use ArcgisExportWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def download(conn, %{"url" => url}) do
    broadcast(url, 0, "initializing download")

    {:ok, %{name: name, max_record_count: max} = service} = ArcgisExport.Service.new(url)

    file_name =
      name
      |> String.downcase()
      |> String.trim()
      |> String.replace(~r(\s+), "_")

    conn =
      conn
      |> put_resp_header(
        "content-disposition",
        ~s(attachment; filename="#{file_name}.csv")
      )
      |> Plug.Conn.send_chunked(200)

    {conn, _} =
      service
      |> ArcgisExport.Service.stream!()
      |> Stream.chunk_every(max)
      |> Enum.reduce_while({conn, -1}, fn chunk, {conn, total} ->
        case Plug.Conn.chunk(conn, chunk) do
          {:ok, conn} ->
            new_total = total + length(chunk)
            broadcast(url, new_total, "downloading")
            {:cont, {conn, new_total}}

          {:error, :closed} ->
            {:halt, {conn, total}}
        end
      end)

    broadcast(url, nil, "completed")

    conn
  end

  defp broadcast(url, count, message),
    do:
      ArcgisExportWeb.Endpoint.broadcast(url, "download", %{
        pid: self(),
        count: count,
        message: message
      })
end
