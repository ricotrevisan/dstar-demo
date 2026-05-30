defmodule DstarDemoWeb.PageControllerTest do
  use DstarDemoWeb.ConnCase

  alias Dstar.Actions
  alias DstarDemoWeb.ActiveSearchController
  alias DstarDemoWeb.CommandController
  alias DstarDemoWeb.PatchLabController
  alias DstarDemoWeb.ScriptHelpersController
  alias DstarDemoWeb.ServerComponentsController
  alias DstarDemoWeb.SignalsController

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Dstar server UI showcase"
    assert response =~ ~s[href="/commands"]
    assert response =~ ~s[href="/search"]
    assert response =~ ~s[href="/streaming"]
    assert response =~ ~s[href="/patch-lab"]
    assert response =~ ~s[href="/components"]
    assert response =~ ~s[href="/signals"]
    assert response =~ ~s[href="/scripts"]
  end

  test "GET /commands", %{conn: conn} do
    conn = get(conn, ~p"/commands")

    response = html_response(conn, 200)
    assert response =~ "Validation is a command"
    assert response =~ "data-bind:email"
    assert response =~ "Dstar.Dispatch"
    refute response =~ "<form"
  end

  test "GET demo pages", %{conn: conn} do
    for {path, marker} <- demo_pages() do
      response =
        conn
        |> recycle()
        |> get(path)
        |> html_response(200)

      assert response =~ marker
    end
  end

  test "demo pages render unique DOM ids for stable Datastar patch targets", %{conn: conn} do
    for {path, _marker} <- demo_pages() do
      response =
        conn
        |> recycle()
        |> get(path)
        |> html_response(200)

      ids = Regex.scan(~r/id="([^"]+)"/, response, capture: :all_but_first) |> List.flatten()
      duplicate_ids = ids -- Enum.uniq(ids)

      assert duplicate_ids == [],
             "#{path} has duplicate ids: #{inspect(Enum.uniq(duplicate_ids))}"
    end
  end

  test "command validation ready command patches validation UI", %{conn: conn} do
    response =
      conn
      |> post_event(CommandController, "ready", %{
        "email" => "ada@example.com",
        "first_name" => "Ada",
        "last_name" => "Lovelace"
      })
      |> sse_response()

    assert response =~ "event: datastar-patch-signals"
    assert response =~ ~s("intent":"ready")
    assert response =~ "id=\"validation-panel\""
  end

  test "active search command patches only result panel", %{conn: conn} do
    response =
      conn
      |> post_event(ActiveSearchController, "search", %{"query" => "stream", "segment" => "all"})
      |> sse_response()

    assert response =~ "event: datastar-patch-elements"
    assert response =~ "selector #search-results"
    assert response =~ "Northstar Metrics"
    refute response =~ "selector #search-query"
  end

  test "streaming endpoint emits bounded dashboard stream", %{conn: conn} do
    response =
      conn
      |> post_json(~p"/streaming/stream", %{"tabid" => "test-tab"})
      |> sse_response()

    assert response =~ ~s("streamStatus":"complete")
    assert response =~ "selector #activity-log"
    assert response =~ "mode prepend"
  end

  test "patch lab append command uses append mode", %{conn: conn} do
    response =
      conn
      |> post_event(PatchLabController, "append", %{"patch_count" => 0})
      |> sse_response()

    assert response =~ "mode append"
    assert response =~ "selector #patch-list"
    assert response =~ "append patch #1"
  end

  test "server component command patches rendered HEEx component", %{conn: conn} do
    response =
      conn
      |> post_event(ServerComponentsController, "timeline", %{"render_count" => 0})
      |> sse_response()

    assert response =~ "selector #component-stage"
    assert response =~ "Patch timeline"
    assert response =~ ~s("component_kind":"timeline")
  end

  test "signals inspector can patch and remove signals", %{conn: conn} do
    patch_response =
      conn
      |> post_event(SignalsController, "patch", %{"server_tick" => 0})
      |> sse_response()

    assert patch_response =~ ~s("server_tick":1)
    assert patch_response =~ "patch_signals tick 1"

    remove_response =
      conn
      |> recycle()
      |> post_event(SignalsController, "remove", %{"ephemeral" => "client-note"})
      |> sse_response()

    assert remove_response =~ ~s("ephemeral":null)
    assert remove_response =~ "remove_signals ephemeral"
  end

  test "script helpers emit console script", %{conn: conn} do
    response =
      conn
      |> post_event(ScriptHelpersController, "console", %{"script_runs" => 0})
      |> sse_response()

    assert response =~ "console.info"
    assert response =~ ~s("last_script_action":"console_log")
    assert response =~ ~s("script_runs":1)
    assert response =~ ~s(data-demo-script="console")
    refute response =~ "data-effect"
    refute response =~ "selector #script-log"
  end

  defp demo_pages do
    [
      {~p"/commands", "Validation is a command"},
      {~p"/search", "Active search"},
      {~p"/streaming", "Streaming dashboard"},
      {~p"/patch-lab", "Patch lab"},
      {~p"/components", "Server-rendered components"},
      {~p"/signals", "Signals lifecycle"},
      {~p"/scripts", "Script helpers"}
    ]
  end

  defp post_event(conn, module, event, signals) do
    encoded = Actions.encode_module(module)
    post_json(conn, "/ds/#{encoded}/#{event}", signals)
  end

  defp post_json(conn, path, signals) do
    conn = Plug.Test.init_test_session(conn, %{})
    csrf = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_req_header("content-type", "application/json")
    |> post(path, Jason.encode!(Map.put(signals, "csrf", csrf)))
  end

  defp sse_response(conn) do
    assert conn.state == :chunked
    {_adapter, state} = conn.adapter
    IO.iodata_to_binary(state.chunks)
  end
end
