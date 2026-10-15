defmodule DstarDemoWeb.RedirectController do
  @moduledoc """
  Permanent redirects for pages that moved. The target comes from the
  route's `assigns: %{to: path}`, so old links and shared cards keep working.
  """
  use DstarDemoWeb, :controller

  def permanent(conn, _params) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: conn.assigns.to)
  end
end
