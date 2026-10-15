defmodule DstarDemoWeb.Meta do
  @moduledoc """
  Per-page `<head>` metadata for crawlers and link unfurlers.

  A page opts in by assigning `:meta` in `mount/2`; the root layout renders
  whatever is there. Pages that assign nothing still get a description, a
  canonical URL and the default card, so every public page unfurls.

      assign(conn,
        page_title: "An inbox grows up",
        meta: %{
          description: "…",
          image: "/images/og/explained-dx.png",
          type: "article",
          published: ~D[2026-10-14]
        }
      )
  """
  use Phoenix.Component

  @site "Dstar Demo"
  @author "Rico Trevisan"
  @default_description "Dstar renders Phoenix pages over Datastar: the browser sends signals, the server answers with HTML patches over SSE, and there's no client-side app."
  @default_image "/images/og/default.png"

  def site, do: @site
  def author, do: @author

  attr :conn, Plug.Conn, required: true
  attr :page_title, :string, default: nil
  attr :meta, :map, default: %{}

  def tags(assigns) do
    meta = assigns.meta || %{}
    base = DstarDemoWeb.Endpoint.url()

    assigns =
      assign(assigns,
        title: assigns.page_title || @site,
        description: Map.get(meta, :description, @default_description),
        canonical: base <> Map.get(meta, :path, assigns.conn.request_path),
        image: base <> Map.get(meta, :image, @default_image),
        image_alt: Map.get(meta, :image_alt, @site),
        type: Map.get(meta, :type, "website"),
        published: Map.get(meta, :published)
      )

    ~H"""
    <meta name="description" content={@description} />
    <meta name="author" content={author()} />
    <link rel="canonical" href={@canonical} />
    <meta property="og:site_name" content={site()} />
    <meta property="og:title" content={@title} />
    <meta property="og:description" content={@description} />
    <meta property="og:type" content={@type} />
    <meta property="og:url" content={@canonical} />
    <meta property="og:image" content={@image} />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />
    <meta property="og:image:alt" content={@image_alt} />
    <meta :if={@published} property="article:published_time" content={Date.to_iso8601(@published)} />
    <meta :if={@type == "article"} property="article:author" content={author()} />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content={@title} />
    <meta name="twitter:description" content={@description} />
    <meta name="twitter:image" content={@image} />
    """
  end
end
