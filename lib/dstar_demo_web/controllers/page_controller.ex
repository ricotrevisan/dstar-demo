defmodule DstarDemoWeb.PageController do
  use DstarDemoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
