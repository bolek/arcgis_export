defmodule ArcgisExportWeb.ExporterLive do
  use Phoenix.LiveView, layout: {ArcgisExportWeb.LayoutView, "live.html"}

  require Logger

  def mount(_params, %{}, socket) do
    # if connected?(socket), do: :timer.send_interval(5000, self(), :update)

    {:ok, assign(socket, error: nil, url: '', status: '', service: nil, active_downloads: %{})}
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
    case ArcgisExport.Service.new(url) do
      {:ok, service} ->
        send(self(), {:count, service})
        {:noreply, assign(socket, service: service)}

      {:error, error} ->
        {:noreply, assign(socket, error: error, service: nil)}
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

  def status(%{error: error}) when not is_nil(error), do: "error"
  def status(%{service: service}) when not is_nil(service), do: "success"
  def status(_), do: nil
end
