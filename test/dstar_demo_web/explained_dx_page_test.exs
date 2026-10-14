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
