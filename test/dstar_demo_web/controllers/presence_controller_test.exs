defmodule DstarDemoWeb.ClosingSSEAdapter do
  @moduledoc false

  def send_chunked(state, _status, _headers) do
    {:ok, "", Map.put_new(state, :chunks, "")}
  end

  def chunk(%{chunks_left: chunks_left, chunks: chunks} = state, body) when chunks_left > 0 do
    body = chunks <> IO.iodata_to_binary(body)
    {:ok, body, %{state | chunks: body, chunks_left: chunks_left - 1}}
  end

  def chunk(state, _body), do: {:error, Map.get(state, :error, :closed)}
end

defmodule DstarDemoWeb.PresenceControllerTest do
  use DstarDemoWeb.ConnCase, async: false

  test "GET /presence renders the collaborative presence demo", %{conn: conn} do
    conn = get(conn, ~p"/presence")

    html = html_response(conn, 200)
    assert html =~ "Presence room"
    assert html =~ "id=\"presence-room\""
    assert html =~ "id=\"presence-roster\""
    assert html =~ "id=\"presence-ping\""
    assert html =~ "/presence/join"
    assert html =~ ~s[data-init="@post('/presence/join']
    assert html =~ ~s[data-on:online__window="@post('/presence/join']
    assert html =~ "/presence/ping"
  end

  test "POST /presence/ping emits an SSE element patch", %{conn: conn} do
    response =
      conn
      |> post_json(~p"/presence/ping", %{
        "visitorName" => "Visitor Otter",
        "visitorColor" => "emerald"
      })
      |> sse_response()

    assert response =~ "event: datastar-patch-elements"
    assert response =~ "selector #presence-activity"
    assert response =~ "Ping sent"
  end

  test "POST /presence/join exits cleanly when the SSE client closes mid-loop", %{conn: conn} do
    signals = %{
      "tabId" => "presence-closed-tab",
      "visitorName" => "Visitor Otter",
      "visitorColor" => "emerald"
    }

    conn = %{
      conn
      | method: "POST",
        body_params: signals,
        params: signals,
        adapter: {DstarDemoWeb.ClosingSSEAdapter, %{chunks_left: 2}}
    }

    assert %Plug.Conn{state: :chunked} = DstarDemoWeb.PresenceController.join(conn, %{})
  end

  test "POST /presence/join deduplicates lower-case tabid signals", %{conn: conn} do
    Phoenix.PubSub.subscribe(DstarDemo.PubSub, "presence:lobby")

    task =
      Task.async(fn ->
        post_json(conn, ~p"/presence/join", %{
          "tabid" => "presence-test-tab",
          "visitorName" => "Visitor Otter",
          "visitorColor" => "emerald"
        })
      end)

    try do
      assert_receive %Phoenix.Socket.Broadcast{event: "presence_diff"}, 1_000

      assert [{pid, nil}] =
               Registry.lookup(
                 Dstar.Utility.StreamRegistry,
                 {{:dstar_demo, :presence}, "presence-test-tab"}
               )

      assert pid == task.pid
    after
      Task.shutdown(task, :brutal_kill)
    end
  end

  test "presence_diff_summary counts joins and leaves" do
    diff = %{
      joins: %{"a" => %{metas: [%{}]}, "b" => %{metas: [%{}, %{}]}},
      leaves: %{"c" => %{metas: [%{}]}}
    }

    assert DstarDemoWeb.PresenceController.presence_diff_summary(diff) == {3, 1}
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
