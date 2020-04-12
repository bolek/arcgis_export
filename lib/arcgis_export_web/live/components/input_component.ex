defmodule ArcgisExportWeb.InputComponent do
  use Phoenix.LiveComponent

  def status_class("error"), do: "uk-form-danger"
  def status_class("success"), do: "uk-form-success"
  def status_class(_), do: ""
end
