defmodule DstarDemoWeb.ScriptsPageTest do
  @moduledoc """
  The Scripts page is the only demo that ships user-authored code to the
  browser, so it carries its own coverage rather than riding along in
  pages_test.exs. execute_script/3 and redirect/3 are also the exact surfaces
  the dstar 0.1.2/0.1.3 security releases changed.
  """
  use DstarDemoWeb.ConnCase

  import Dstar.Test

  defp post_event(conn, event, signals) do
    post_json(conn, "/scripts/_event/" <> event, signals)
  end

  test "console ships the visitor's payload at the chosen level", %{conn: conn} do
    conn =
      post_event(conn, "console", %{
        "script_runs" => 0,
        "console_payload" => ~s({"who":"reader"}),
        "console_level" => "warn"
      })

    body = sse_body(conn)

    assert_patched_signals(conn, %{script_runs: 1, last_script_action: "console_log"})
    assert body =~ "console.warn"
    assert body =~ ~s({"who":"reader"})
    assert body =~ ~s(data-demo-script="console")
    refute body =~ "data-effect"
  end

  test "console rejects malformed JSON without calling the helper", %{conn: conn} do
    conn =
      post_event(conn, "console", %{"script_runs" => 0, "console_payload" => "{not json"})

    body = sse_body(conn)

    assert body =~ "not valid JSON"
    refute body =~ "console."
    refute body =~ ~s(data-demo-script="console")
  end

  test "console falls back to info for an unknown level", %{conn: conn} do
    conn =
      post_event(conn, "console", %{
        "script_runs" => 0,
        "console_payload" => ~s({"a":1}),
        "console_level" => "bogus"
      })

    assert sse_body(conn) =~ "console.info"
  end

  test "redirect helper emits a navigation script", %{conn: conn} do
    conn = post_event(conn, "redirect", %{"script_runs" => 0})

    assert_patched_signals(conn, %{script_runs: 1, last_script_action: "redirect"})
    assert sse_body(conn) =~ "/scripts?redirected=1"
    assert sse_body(conn) =~ ~s(data-demo-script="redirect")
  end

  test "the log starts empty and announces itself", %{conn: conn} do
    response = conn |> get("/scripts") |> html_response(200)

    assert response =~ ~s(id="helper-log-entries")
    assert response =~ "No helper has run yet."
  end

  test "each helper prepends a log row naming the helper", %{conn: conn} do
    conn = post_event(conn, "console", %{"script_runs" => 2})
    body = sse_body(conn)

    assert body =~ ~s(selector #helper-log-entries)
    assert body =~ "mode prepend"
    assert body =~ "console_log/3"
    assert body =~ "run 3"
  end

  test "clear empties the log and resets the run count", %{conn: conn} do
    conn = post_event(conn, "clear", %{"script_runs" => 7})

    assert_patched_signals(conn, %{script_runs: 0, last_script_action: "idle"})
    assert sse_body(conn) =~ ~s(id="helper-log-entries")
    refute sse_body(conn) =~ "console_log/3"
  end

  test "the editor is bound to the script_source signal", %{conn: conn} do
    response = conn |> get("/scripts") |> html_response(200)

    assert response =~ ~s(id="script-editor")
    assert response =~ "data-bind:script_source"
    assert response =~ ~s(id="script-run")
  end

  test "run ships the visitor's own source verbatim", %{conn: conn} do
    conn =
      post_event(conn, "run", %{"script_runs" => 0, "script_source" => "window.ran = 41 + 1"})

    body = sse_body(conn)

    assert_patched_signals(conn, %{script_runs: 1, last_script_action: "execute_script"})
    assert body =~ "window.ran = 41 + 1"
    assert body =~ ~s(data-demo-script="run")
    refute body =~ "data-effect"
  end

  test "run rejects an empty editor instead of shipping a blank script", %{conn: conn} do
    conn = post_event(conn, "run", %{"script_runs" => 0, "script_source" => "   "})
    body = sse_body(conn)

    assert body =~ "Nothing to run"
    refute body =~ ~s(data-demo-script="run")
  end

  defp post_json(conn, path, signals) do
    conn = Plug.Test.init_test_session(conn, %{})
    csrf = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_req_header("content-type", "application/json")
    |> post(path, Jason.encode!(Map.put(signals, "csrf", csrf)))
  end

  defp sse_body(conn) do
    assert conn.state == :chunked
    conn.resp_body
  end
end
