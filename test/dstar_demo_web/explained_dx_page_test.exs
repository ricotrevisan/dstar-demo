defmodule DstarDemoWeb.ExplainedDxPageTest do
  # DstarDemo.Inbox is one shared, named process.
  use DstarDemoWeb.ConnCase, async: false

  alias DstarDemo.Inbox

  setup do
    Inbox.reset()
    :ok
  end

  test "GET /explained/dx renders five scroll stages, the code and the live inbox", %{
    conn: conn
  } do
    document = conn |> get(~p"/explained/dx") |> html_response(200) |> LazyHTML.from_document()

    for n <- 1..5 do
      step = LazyHTML.query(document, "#dx-stage-#{n}")
      assert LazyHTML.attribute(step, "data-on-intersect__half") == ["$stage = #{n}"]
    end

    assert document |> LazyHTML.query("#dx-diagram") |> Enum.count() == 1
    assert document |> LazyHTML.query("#dx-sources") |> Enum.count() == 1
    assert document |> LazyHTML.query("#dx-sidebar") |> Enum.count() == 1
    assert document |> LazyHTML.query("#dx-list li") |> Enum.count() == length(Inbox.list())

    # The live inbox opens one stream through the page route.
    inbox = LazyHTML.query(document, "#dx-inbox")
    assert [init] = LazyHTML.attribute(inbox, "data-init")
    assert init =~ "@post("
  end

  test "the LiveView lane is the Phoenix 1.8 version: one process, a hook, no nested LiveView",
       %{conn: conn} do
    html = conn |> get(~p"/explained/dx") |> html_response(200)
    document = LazyHTML.from_document(html)

    # Code is server-rendered text, so crawlers and no-JS readers get it.
    code = document |> LazyHTML.query("#code pre") |> LazyHTML.text()
    assert code =~ "attach_hook(:unread, :handle_info"
    assert code =~ "MyAppWeb.Unread"
    refute html =~ "SidebarLive"
    refute html =~ "live_render"

    # Both lanes count the same three things.
    for lane <- ~w(lv ds), counter <- ~w(auth procs memory) do
      assert document |> LazyHTML.query("##{lane}-#{counter}") |> Enum.count() == 1
    end
  end

  test "the pull request toggle shows both diffs with their file counts", %{conn: conn} do
    document = conn |> get(~p"/explained/dx") |> html_response(200) |> LazyHTML.from_document()

    for {lane, files} <- [{"lv", 3}, {"ds", 2}] do
      panel = LazyHTML.query(document, "#payoff-#{lane}")
      assert LazyHTML.attribute(panel, "data-show") == ["$dxPr == '#{lane}'"]
      assert panel |> LazyHTML.query("figure") |> Enum.count() == files
      assert LazyHTML.text(panel) =~ "#{files} files"
    end
  end

  test "the stage-5 deploy button runs the lab's deploy and patches the counters in place", %{
    conn: conn
  } do
    DstarDemo.ChaosLab.Server.dispatch("reset")
    before = DstarDemo.ChaosLab.Server.get()

    body = conn |> post_event("lab_deploy") |> response(200)
    after_deploy = DstarDemo.ChaosLab.Server.get()

    assert after_deploy.lv.mounts > before.lv.mounts
    assert after_deploy.ds.mounts == before.ds.mounts
    assert body =~ ~s(id="dx-deploy")
    assert body =~ "Someone deployed"
  after
    DstarDemo.ChaosLab.Server.dispatch("reset")
  end

  test "the page ends with the install line, docs, source, the lab and an author", %{conn: conn} do
    document = conn |> get(~p"/explained/dx") |> html_response(200) |> LazyHTML.from_document()
    ending = LazyHTML.query(document, "#try-dstar")

    assert LazyHTML.text(ending) =~ ~s({:dstar, "~> 0.3.0"})
    hrefs = ending |> LazyHTML.query("a") |> LazyHTML.attribute("href")

    for {href, _title, _body} <- DstarDemoWeb.ExplainerComponents.try_links() do
      assert href in hrefs
    end

    assert "/explained/lab" in hrefs
    assert "https://rico.wtf" in hrefs

    dek = LazyHTML.query(document, "#dek a") |> LazyHTML.attribute("href")
    assert "https://data-star.dev" in dek
  end

  test "every internal link on the explainers resolves", %{conn: conn} do
    for page <- [~p"/explained", ~p"/explained/dx", ~p"/explained/lab"] do
      hrefs =
        conn
        |> get(page)
        |> html_response(200)
        |> LazyHTML.from_document()
        |> LazyHTML.query("a[href^='/']")
        |> LazyHTML.attribute("href")

      for href <- Enum.uniq(hrefs) do
        path = href |> String.split("#") |> hd()
        assert build_conn() |> get(path) |> response(200), "#{page} links to #{href}"
      end
    end
  end

  test "the home page links to the explainer", %{conn: conn} do
    link =
      conn
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()
      |> LazyHTML.query("#explainer-link")

    assert LazyHTML.attribute(link, "href") == ["/explained/dx"]
  end

  test "marking a message read changes the server's inbox and patches sidebar and list", %{
    conn: conn
  } do
    unread = Inbox.unread_count()
    [%{id: id} | _] = Enum.reject(Inbox.list(), & &1.read)

    body = conn |> post_event("read:#{id}") |> response(200)

    assert Inbox.unread_count() == unread - 1
    assert body =~ ~s(id="dx-sidebar")
    assert body =~ ~s(id="dx-list")
    refute body =~ ~s(id="dx-read-#{id}")
  end

  test "deliver, read_all and reset all go through the shared inbox", %{conn: conn} do
    count = length(Inbox.list())

    conn |> post_event("deliver") |> response(200)
    assert length(Inbox.list()) == count + 1

    build_conn() |> post_event("read_all") |> response(200)
    assert Inbox.unread_count() == 0

    build_conn() |> post_event("reset") |> response(200)
    assert length(Inbox.list()) == count
  end

  test "an open stream is told when another tab changes the inbox" do
    :ok = Inbox.subscribe()
    Inbox.deliver()
    assert_receive :inbox_changed
  end

  defp post_event(conn, event) do
    conn = Plug.Test.init_test_session(conn, %{})
    csrf = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_req_header("content-type", "application/json")
    |> post("/explained/dx/_event/" <> event, Jason.encode!(%{csrf: csrf}))
  end
end
