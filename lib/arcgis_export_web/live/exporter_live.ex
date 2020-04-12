defmodule ArcgisExportWeb.ExporterLive do
  use Phoenix.LiveView, layout: {ArcgisExportWeb.LayoutView, "live.html"}

  require Logger

  def mount(_params, %{}, socket) do
    # if connected?(socket), do: :timer.send_interval(5000, self(), :update)

    {:ok, assign(socket, url: '', status: '', service: nil, active_downloads: %{})}
  end

  def handle_params(%{"url" => url}, _uri, socket) do
    maybe_unsubscribe(socket.assigns)

    ArcgisExportWeb.Endpoint.subscribe(url)

    send(self(), {:validate, url})

    {:noreply, assign(socket, status: "checking service ...", url: url, service: nil)}
  end

  def handle_params(%{}, _uri, socket) do
    {:noreply, socket}
  end

  # def handle_info(:update, socket) do
  #   # temperature = :rand.uniform(1000)
  #   # {:noreply, assign(socket, :temperature, temperature)}
  # end

  def handle_event("validate", %{"url" => url}, socket) do
    {:noreply,
     push_redirect(
       socket,
       to:
         ArcgisExportWeb.Router.Helpers.live_path(
           socket,
           ArcgisExportWeb.ExporterLive,
           url: url
         )
     )}
  end

  def handle_event("build_csv", %{}, %{assigns: %{service: service}} = socket) do
    send(self(), {:build_csv, service})

    {:noreply, assign(socket, status: "preparing CSV")}
  end

  defp maybe_unsubscribe(%{service: %{url: url}}), do: ArcgisExportWeb.Endpoint.unsubscribe(url)
  defp maybe_unsubscribe(_), do: :ok

  def handle_info({:validate, url}, socket) do
    case HTTPoison.get(url, [], params: [f: "pjson"]) do
      {:ok, %{body: body}} ->
        service =
          ArcgisExport.Service.build(
            url,
            Jason.decode!(body) |> Recase.Enumerable.convert_keys(&Recase.to_snake/1)
          )

        send(self(), {:count, service})
        {:noreply, assign(socket, status: "", service: service)}

      {:error, _} ->
        {:noreply, assign(socket, status: "error")}
    end
  end

  def handle_info({:count, service}, socket) do
    with {:ok, service} <- ArcgisExport.Service.count(service) do
      {:noreply, assign(socket, service: service)}
    else
      {:error, error} ->
        Logger.info(error)
        {:noreply, assign(socket, service: service)}
    end
  end

  def handle_info(
        %{topic: _url, payload: payload},
        %{assigns: %{active_downloads: downloads}} = socket
      ) do
    IO.inspect(payload)
    {:noreply, assign(socket, active_downloads: Map.put(downloads, payload.pid, payload))}
  end

  def handle_info({:build_csv, service}, socket) do
    ArcgisExport.Service.to_file(service)

    {:noreply, socket}

    # with {:ok, service} <- ArcgisExport.Service.build_csv(service) do
    #   {:noreply, assign(socket, service: service)}
    # else
    #   {:error, _} -> {:noreply, assign(socket, service: service)}
    # end
  end
end
