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

  test "console helper emits a console script", %{conn: conn} do
    conn = post_event(conn, "console", %{"script_runs" => 0})

    assert_patched_signals(conn, %{script_runs: 1, last_script_action: "console_log"})
    assert sse_body(conn) =~ "console.info"
    assert sse_body(conn) =~ ~s(data-demo-script="console")
    refute sse_body(conn) =~ "data-effect"
  end

  test "execute helper emits its marker attribute", %{conn: conn} do
    conn = post_event(conn, "execute", %{"script_runs" => 0})

    assert_patched_signals(conn, %{script_runs: 1, last_script_action: "execute_script"})
    assert sse_body(conn) =~ "dstarScriptPulse"
    assert sse_body(conn) =~ ~s(data-demo-script="execute")
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
