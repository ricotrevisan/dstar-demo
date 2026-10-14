defmodule DstarDemoWeb.ExplainedLabPageTest do
  # DstarDemo.ChaosLab.Server is one shared, named process.
  use DstarDemoWeb.ConnCase, async: false

  alias DstarDemo.ChaosLab.Server

  setup do
    Server.dispatch("reset")
    :ok
  end

  test "GET /explained/lab renders both worlds, six tabs each, and opens a stream", %{conn: conn} do
    document = conn |> get(~p"/explained/lab") |> html_response(200) |> LazyHTML.from_document()

    for world <- ~w(lv ds) do
      assert document |> LazyHTML.query("#lab-#{world} [id^='lab-#{world}-tab-']") |> Enum.count() ==
               6
    end

    section = LazyHTML.query(document, "#lab-section")
    assert [init] = LazyHTML.attribute(section, "data-init")
    assert init =~ "@post("
  end

  test "a lab action updates the shared lab and patches it back", %{conn: conn} do
    body = conn |> post_event("deploy") |> response(200)

    assert Server.get().log |> hd() |> Map.fetch!(:title) == "Someone deployed"
    assert body =~ ~s(id="lab")
    assert body =~ "Someone deployed"
  end

  test "every reader's stream is told about another reader's action" do
    :ok = Server.subscribe()
    Server.dispatch("click")
    assert_receive :chaos_lab_changed
  end

  test "an unknown action never reaches the simulation", %{conn: conn} do
    try do
      post_event(conn, "explode")
    rescue
      _ -> :ok
    end

    assert Server.get().seq == 0
  end

  defp post_event(conn, event) do
    conn = Plug.Test.init_test_session(conn, %{})
    csrf = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_req_header("content-type", "application/json")
    |> post("/explained/lab/_event/" <> event, Jason.encode!(%{csrf: csrf}))
  end
end
