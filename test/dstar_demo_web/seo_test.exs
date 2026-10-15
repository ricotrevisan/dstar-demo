defmodule DstarDemoWeb.SeoTest do
  use DstarDemoWeb.ConnCase, async: true

  @articles [
    {"/", "/images/og/home.png"},
    {"/explained/lab", "/images/og/explained-lab.png"}
  ]

  describe "per-page meta" do
    for {path, image} <- @articles do
      @path path
      @image image

      test "#{path} has description, canonical, Open Graph, Twitter and article tags", %{
        conn: conn
      } do
        head = conn |> get(@path) |> html_response(200) |> LazyHTML.from_document()
        base = DstarDemoWeb.Endpoint.url()

        assert [description] = meta(head, "meta[name='description']")
        assert String.length(description) > 50
        assert meta(head, "meta[name='author']") == ["Rico Trevisan"]

        assert head |> LazyHTML.query("link[rel='canonical']") |> LazyHTML.attribute("href") ==
                 [base <> @path]

        assert meta(head, "meta[property='og:url']") == [base <> @path]
        assert meta(head, "meta[property='og:type']") == ["article"]
        assert meta(head, "meta[property='og:image']") == [base <> @image]
        assert [_] = meta(head, "meta[property='og:title']")
        assert [_] = meta(head, "meta[property='og:description']")
        assert meta(head, "meta[name='twitter:card']") == ["summary_large_image"]
        assert meta(head, "meta[property='article:published_time']") == ["2026-10-14"]

        assert File.exists?(Path.join("priv/static", @image))
      end
    end

    test "a page without its own meta still gets a description, canonical and default card", %{
      conn: conn
    } do
      head = conn |> get(~p"/showcase") |> html_response(200) |> LazyHTML.from_document()

      assert [_] = meta(head, "meta[name='description']")
      assert meta(head, "meta[property='og:type']") == ["website"]
      assert [image] = meta(head, "meta[property='og:image']")
      assert String.ends_with?(image, "/images/og/default.png")
      assert File.exists?("priv/static/images/og/default.png")
    end
  end

  describe "the flash group" do
    for path <- ["/", "/showcase", "/examples", "/explained", "/explained/lab"] do
      @path path

      test "comes after the H1 on #{path}", %{conn: conn} do
        html = conn |> get(@path) |> html_response(200)
        {h1, _} = :binary.match(html, "<h1")
        {flash, _} = :binary.match(html, ~s(id="flash-group"))

        assert h1 < flash
      end
    end
  end

  test "GET /explained lists every explainer", %{conn: conn} do
    document = conn |> get(~p"/explained") |> html_response(200) |> LazyHTML.from_document()
    hrefs = document |> LazyHTML.query("#explainers a") |> LazyHTML.attribute("href")

    assert hrefs == Enum.map(DstarDemoWeb.Explainers.all(), & &1.path)
  end

  test "GET /sitemap.xml lists every public page and nothing else", %{conn: conn} do
    conn = get(conn, "/sitemap.xml")
    body = response(conn, 200)
    base = DstarDemoWeb.Endpoint.url()

    assert ["application/xml" <> _] = get_resp_header(conn, "content-type")
    assert body =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)

    locs = Regex.scan(~r{<loc>([^<]+)</loc>}, body, capture: :all_but_first) |> List.flatten()

    for path <- ["/", "/showcase", "/explained", "/explained/lab", "/examples"] do
      assert (base <> path) in locs
    end

    paths = Enum.map(locs, &String.replace_prefix(&1, base, ""))
    refute Enum.any?(paths, &(&1 =~ "_event" or &1 =~ "/dev" or &1 =~ ":"))
    refute "/explained/dx" in paths
    assert body =~ "<lastmod>2026-10-14</lastmod>"

    for path <- paths do
      assert build_conn() |> get(path) |> response(200), "sitemap lists #{path}"
    end
  end

  test "robots.txt points at the sitemap" do
    robots = File.read!("priv/static/robots.txt")
    assert robots =~ "Sitemap: https://dstar.nocode-to-knowcode.com/sitemap.xml"
    refute robots =~ ~r/^Disallow: \/$/m
  end

  defp meta(document, selector) do
    document |> LazyHTML.query(selector) |> LazyHTML.attribute("content")
  end
end
