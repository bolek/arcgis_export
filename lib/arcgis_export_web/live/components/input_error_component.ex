defmodule ArcgisExportWeb.InputErrorComponent do
  use Phoenix.LiveComponent

  def error(%HTTPoison.Error{id: nil, reason: :nxdomain}) do
    "Invalid url. Domain does not exist."
  end

  def error(:inexistent) do
    "Resource not found. Check URL and permissions."
  end

  def error(:invalid_url) do
    """
    This does not look like a valid ArcGIS REST Service URL. It should follow this pattern:
    https://<host>/<site>/rest/services/<folder>/<serviceName>/<serviceType>/<serviceId>
    """
  end

  def error(%Jason.DecodeError{}) do
    "This URL does not behave like a ArcGIS REST endpoint. Check your URL and permissions"
  end

  def error(_), do: "Unknown error. Check your URL."
end
