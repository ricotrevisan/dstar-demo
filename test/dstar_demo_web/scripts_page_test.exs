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
