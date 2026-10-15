defmodule DstarDemoWeb.SitemapController do
  @moduledoc """
  `/sitemap.xml`: every public GET page in the router. Pages are read from
  the routes themselves, so a new `dstar` route shows up without an edit
  here. Event, stream and dev routes are left out.
  """
  use DstarDemoWeb, :controller

  def index(conn, _params) do
    base = DstarDemoWeb.Endpoint.url()
    published = Map.new(DstarDemoWeb.Explainers.all(), &{&1.path, &1.published})

    urls =
      for path <- public_paths() do
        {base <> path, Map.get(published, path)}
      end

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, render_xml(urls))
  end

  @doc "Paths of every public page, in router order."
  def public_paths do
    DstarDemoWeb.Router
    |> Phoenix.Router.routes()
    |> Enum.filter(&public_page?/1)
    |> Enum.map(& &1.path)
    |> Enum.uniq()
  end

  defp public_page?(%{verb: :get, path: path, plug: plug}) do
    plug == Dstar.Page.Plug and not String.contains?(path, ":") and
      not String.starts_with?(path, "/dev")
  end

  defp public_page?(_route), do: false

  defp render_xml(urls) do
    entries =
      Enum.map(urls, fn {loc, lastmod} ->
        [
          "  <url>\n    <loc>",
          Plug.HTML.html_escape(loc),
          "</loc>\n",
          if(lastmod, do: ["    <lastmod>", Date.to_iso8601(lastmod), "</lastmod>\n"], else: []),
          "  </url>\n"
        ]
      end)

    IO.iodata_to_binary([
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n),
      entries,
      "</urlset>\n"
    ])
  end
end
