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

defmodule DstarDemoWeb.PresencePageTest do
  use DstarDemoWeb.ConnCase, async: false

  test "GET /presence renders the collaborative presence demo", %{conn: conn} do
    conn = get(conn, ~p"/presence")

    html = html_response(conn, 200)
    assert html =~ "Presence room"
    assert html =~ "id=\"presence-room\""
    assert html =~ "id=\"presence-roster\""
    assert html =~ "id=\"presence-ping\""
    # No client auto-retry: duplicated tabs share the sessionStorage tabId,
    # and a killed-and-retried stream re-kills its sibling forever (the
    # client resets its retry counter on every 200, so any finite budget is
    # ineffective). online/pageshow handlers reconnect when it matters.
    # dstar main (unreleased, after 0.2.0) collapses leading slashes in
    # location.pathname so the request cannot become protocol-relative.
    assert html =~
             ~s[data-init="@post(location.pathname.replace(/^\\/+/, &#39;/&#39;), {retryMaxCount: 0})"]

    assert html =~
             ~s[data-on:online__window="@post(location.pathname.replace(/^\\/+/, &#39;/&#39;), {retryMaxCount: 0})"]

    assert html =~ "evt.persisted &amp;&amp; ($presenceInstance = crypto.randomUUID()"
    assert html =~ "el.dataset.presenceInstance = $presenceInstance"
    refute html =~ "$el.dataset.presenceInstance"
    assert html =~ "/_event/ping"
    assert html =~ "/_event/rename"
    # The visitor is a named character with a local portrait, not initials.
    assert html =~ ~s[id="presence-you-name"]
    # Kebab-case on purpose: HTML lowercases attribute names, so
    # `data-bind:visitorName` would bind a stray `visitorname` signal.
    assert html =~ "data-bind:visitor-name"
    assert html =~ ~r{src="/images/expanse/\w+\.webp}
    assert html =~ ~s[data-presence-leave-url="/presence/_event/leave"]
    assert html =~ ~s[data-presence-instance=]
  end

  test "POST /presence/_event/ping emits an SSE element patch", %{conn: conn} do
    conn =
      post_json(conn, ~p"/presence/_event/ping", %{
        "visitorName" => "Visitor Otter",
        "visitorColor" => "emerald"
      })

    Dstar.Test.assert_patched_element(conn, "#presence-activity")
    assert sse_response(conn) =~ "Ping sent"
  end

  test "POST /presence exits cleanly when the SSE client closes mid-loop", %{conn: conn} do
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

    assert %Plug.Conn{state: :chunked} =
             Dstar.Page.Plug.call(
               conn,
               Dstar.Page.Plug.init({:stream, DstarDemoWeb.PresencePage})
             )

    # The halted stream ran in this test process, which stays alive — like a
    # Bandit keep-alive connection process. The page must have cleaned up
    # everything scoped to the stream, or later requests on this process
    # inherit the subscription, registry key, and presence entry.
    assert Dstar.Utility.StreamRegistry.owner({{:dstar_demo, :presence}, "presence-closed-tab"}) ==
             :error

    refute DstarDemoWeb.Presence.list("presence:lobby")
           |> Map.has_key?("presence-closed-tab")

    Phoenix.PubSub.broadcast(DstarDemo.PubSub, "presence:lobby", :pubsub_probe)
    refute_receive :pubsub_probe
  end

  test "POST /presence registers the stream under its tabId signal", %{conn: conn} do
    Phoenix.PubSub.subscribe(DstarDemo.PubSub, "presence:lobby")

    task =
      Task.async(fn ->
        post_json(conn, ~p"/presence", %{
          "tabId" => "presence-test-tab",
          "visitorName" => "Visitor Otter",
          "visitorColor" => "emerald"
        })
      end)

    try do
      # Filter by tab_id: stray diffs from previous tests' killed streams
      # must not satisfy this before our own stream has registered.
      assert_presence_diff(:joins, "presence-test-tab")

      key = {{:dstar_demo, :presence}, "presence-test-tab"}
      assert {:ok, pid, _claim} = Dstar.Utility.StreamRegistry.owner(key)
      assert pid == task.pid
    after
      Task.shutdown(task, :brutal_kill)
    end
  end

  test "ping event sanitizes visitor identity before broadcasting", %{conn: conn} do
    Phoenix.PubSub.subscribe(DstarDemo.PubSub, "presence:lobby")
    long_name = String.duplicate("a", 500)

    post_json(conn, ~p"/presence/_event/ping", %{
      "visitorName" => long_name,
      "visitorColor" => "hotpink"
    })

    assert_receive %Phoenix.Socket.Broadcast{event: "presence_activity", payload: payload}
    refute payload.message =~ long_name
    assert String.length(payload.message) <= 60
    assert payload.color == "emerald"
  end

  test "stream connect sanitizes tracked visitor metadata", %{conn: conn} do
    Phoenix.PubSub.subscribe(DstarDemo.PubSub, "presence:lobby")
    tab_id = "presence-sanitize-tab"
    long_name = String.duplicate("b", 500)

    task =
      Task.async(fn ->
        post_json(conn, ~p"/presence", %{
          "tabId" => tab_id,
          "visitorName" => long_name,
          "visitorColor" => 42
        })
      end)

    try do
      assert_presence_diff(:joins, tab_id)

      assert %{metas: [meta | _]} =
               DstarDemoWeb.Presence.list("presence:lobby") |> Map.fetch!(tab_id)

      assert String.length(meta.name) == 40
      assert meta.color in ~w(emerald sky violet amber rose cyan lime fuchsia)
    after
      Task.shutdown(task, :brutal_kill)
      DstarDemoWeb.Presence.untrack(task.pid, "presence:lobby", tab_id)
    end
  end

  test "an oversized tabId streams without dedup but still tracks presence", %{conn: conn} do
    Phoenix.PubSub.subscribe(DstarDemo.PubSub, "presence:lobby")

    # Dstar rejects a tabId over 64 bytes rather than registering it,
    # so the stream runs undeduplicated and the leave beacon has nothing to
    # look up. Presence is keyed separately and must still work.
    raw_tab = String.duplicate("t", 100)
    presence_tab = String.duplicate("t", 64)

    supervisor =
      start_supervised!({Task.Supervisor, name: DstarDemoWeb.PresencePageTest.LongTabSupervisor})

    Task.Supervisor.async_nolink(supervisor, fn ->
      post_json(conn, ~p"/presence", %{
        "tabId" => raw_tab,
        "visitorName" => "Visitor Otter",
        "visitorColor" => "emerald",
        "presenceInstance" => "long-tab-instance"
      })
    end)

    assert_presence_diff(:joins, presence_tab)

    # No registry entry under either the raw or the truncated form — an
    # unusable tabId means no deduplication at all.
    assert Dstar.Utility.StreamRegistry.owner({{:dstar_demo, :presence}, raw_tab}) == :error

    assert Dstar.Utility.StreamRegistry.owner({{:dstar_demo, :presence}, presence_tab}) == :error

    # The beacon still answers, it just has no stream to notify.
    leave_conn =
      post_form(conn, ~p"/presence/_event/leave", %{
        "tabId" => raw_tab,
        "presenceInstance" => "long-tab-instance"
      })

    assert leave_conn.state == :chunked
    # start_supervised! tears the streaming task down at the end of the test.
  end

  @tag timeout: 5_000
  test "a takeover by a newer stream halts the old one and runs handle_disconnect", %{conn: conn} do
    # Dstar halts the library loop on the takeover signal, then calls
    # handle_disconnect/1. This drives the real path — a second claimant on the
    # same key — rather than seeding the mailbox with a stale replacement.
    Phoenix.PubSub.subscribe(DstarDemo.PubSub, "presence:lobby")

    tab_id = "presence-takeover-tab"
    key = {{:dstar_demo, :presence}, tab_id}

    supervisor =
      start_supervised!({Task.Supervisor, name: DstarDemoWeb.PresencePageTest.TakeoverSupervisor})

    Task.Supervisor.async_nolink(supervisor, fn ->
      post_json(conn, ~p"/presence", %{
        "tabId" => tab_id,
        "visitorName" => "Visitor Otter",
        "visitorColor" => "emerald",
        "presenceInstance" => "takeover-instance"
      })
    end)

    assert_presence_diff(:joins, tab_id)
    assert {:ok, _old_pid, _claim} = Dstar.Utility.StreamRegistry.owner(key)

    # Exactly what a second stream's Dstar.start_stream does.
    assert :ok = Dstar.Utility.StreamRegistry.replace_and_register(key)

    # The old stream halted, so handle_disconnect/1 untracked its presence.
    assert_presence_diff(:leaves, tab_id)
    assert {:ok, pid, _claim} = Dstar.Utility.StreamRegistry.owner(key)
    assert pid == self()
  after
    Dstar.Utility.StreamRegistry.unregister_self()
  end

  @tag timeout: 5_000
  test "leave-initiated halt cleans up registry, presence, and subscription", %{conn: conn} do
    tab_id = "presence-leave-halt-tab"

    signals = %{
      "tabId" => tab_id,
      "visitorName" => "Visitor Otter",
      "visitorColor" => "emerald",
      "presenceInstance" => "halt-instance"
    }

    conn = %{
      conn
      | method: "POST",
        body_params: signals,
        params: signals,
        adapter: {DstarDemoWeb.ClosingSSEAdapter, %{chunks_left: 50}}
    }

    send(self(), {:presence_leave, tab_id, "halt-instance"})

    assert %Plug.Conn{state: :chunked} =
             Dstar.Page.Plug.call(
               conn,
               Dstar.Page.Plug.init({:stream, DstarDemoWeb.PresencePage})
             )

    key = {{:dstar_demo, :presence}, tab_id}
    assert Dstar.Utility.StreamRegistry.owner(key) == :error

    refute DstarDemoWeb.Presence.list("presence:lobby") |> Map.has_key?(tab_id)

    Phoenix.PubSub.broadcast(DstarDemo.PubSub, "presence:lobby", :leave_halt_probe)
    refute_receive :leave_halt_probe
  end

  test "POST /presence/_event/leave asks the active stream for the tab to exit", %{conn: conn} do
    Phoenix.PubSub.subscribe(DstarDemo.PubSub, "presence:lobby")

    tab_id = "presence-leave-tab"

    signals = %{
      "tabId" => tab_id,
      "visitorName" => "Visitor Otter",
      "visitorColor" => "emerald",
      "presenceInstance" => "leave-instance"
    }

    supervisor =
      start_supervised!(
        {Task.Supervisor, name: DstarDemoWeb.PresencePageTest.LeaveTaskSupervisor}
      )

    task =
      Task.Supervisor.async_nolink(supervisor, fn ->
        post_json(conn, ~p"/presence", signals)
      end)

    assert_presence_diff(:joins, tab_id)

    key = {{:dstar_demo, :presence}, tab_id}
    assert {:ok, pid, _claim} = Dstar.Utility.StreamRegistry.owner(key)

    leave_conn =
      post_form(conn, ~p"/presence/_event/leave", %{
        "tabId" => tab_id,
        "presenceInstance" => "leave-instance"
      })

    # The leave beacon's reply is an SSE stream that closes without events.
    assert leave_conn.state == :chunked
    assert Dstar.Test.sse_events(leave_conn) == []

    assert_receive {ref, %Plug.Conn{state: :chunked}}, 1_000
    assert ref == task.ref
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000

    assert_presence_diff(:leaves, tab_id)
  end

  test "POST /presence/_event/leave ignores stale page instances after stream replacement",
       %{conn: conn} do
    Phoenix.PubSub.subscribe(DstarDemo.PubSub, "presence:lobby")

    tab_id = "presence-replaced-tab"
    old_instance = "old-page-instance"
    new_instance = "new-page-instance"

    supervisor =
      start_supervised!(
        {Task.Supervisor, name: DstarDemoWeb.PresencePageTest.ReplaceTaskSupervisor}
      )

    old_task =
      Task.Supervisor.async_nolink(supervisor, fn ->
        post_json(conn, ~p"/presence", %{
          "tabId" => tab_id,
          "visitorName" => "Visitor Otter",
          "visitorColor" => "emerald",
          "presenceInstance" => old_instance
        })
      end)

    assert_presence_diff(:joins, tab_id)

    key = {{:dstar_demo, :presence}, tab_id}
    assert {:ok, old_pid, _claim} = Dstar.Utility.StreamRegistry.owner(key)

    new_task =
      Task.Supervisor.async_nolink(supervisor, fn ->
        post_json(conn, ~p"/presence", %{
          "tabId" => tab_id,
          "visitorName" => "Visitor Otter",
          "visitorColor" => "emerald",
          "presenceInstance" => new_instance
        })
      end)

    try do
      assert_receive {:DOWN, old_ref, :process, ^old_pid, {:replaced, _claim}}, 1_000
      assert old_ref == old_task.ref

      assert_presence_diff(:joins, tab_id)

      assert {:ok, new_pid, _claim} = Dstar.Utility.StreamRegistry.owner(key)
      assert new_pid == new_task.pid
      new_ref = new_task.ref

      leave_conn =
        post_form(conn, ~p"/presence/_event/leave", %{
          "tabId" => tab_id,
          "presenceInstance" => old_instance
        })

      assert leave_conn.state == :chunked
      refute_receive {:DOWN, ^new_ref, :process, ^new_pid, :normal}, 100
    after
      Task.shutdown(new_task, :brutal_kill)
    end
  end

  test "presence leave client uses sendBeacon before keepalive fetch fallback" do
    app_js = File.read!("assets/js/app.js")

    assert app_js =~ "data-presence-leave-url"
    assert app_js =~ ~s[window.addEventListener("pagehide"]
    assert app_js =~ "presenceInstance: presenceRoom.dataset.presenceInstance"
    assert app_js =~ "navigator.sendBeacon(leaveUrl, payload)"
    assert app_js =~ "keepalive: true"
  end

  test "POST /presence/_event/rename retitles the tab's presence entry", %{conn: conn} do
    Phoenix.PubSub.subscribe(DstarDemo.PubSub, "presence:lobby")

    tab_id = "presence-rename-tab"

    supervisor =
      start_supervised!({Task.Supervisor, name: DstarDemoWeb.PresencePageTest.RenameSupervisor})

    Task.Supervisor.async_nolink(supervisor, fn ->
      post_json(conn, ~p"/presence", %{
        "tabId" => tab_id,
        "visitorName" => "James Holden",
        "visitorColor" => "sky",
        "presenceInstance" => "rename-instance"
      })
    end)

    assert_presence_diff(:joins, tab_id)

    rename_conn =
      post_json(conn, ~p"/presence/_event/rename", %{
        "tabId" => tab_id,
        "visitorName" => "Camina Drummer",
        "presenceInstance" => "rename-instance"
      })

    # The event hands the rename to the stream and answers with nothing; the
    # roster repaint arrives on the stream the tab already has open.
    assert Dstar.Test.sse_events(rename_conn) == []

    assert_receive %Phoenix.Socket.Broadcast{
                     event: "presence_activity",
                     payload: %{kind: "rename"} = payload
                   },
                   1_000

    assert payload.message == "James Holden is now Camina Drummer"

    assert %{metas: [%{name: "Camina Drummer", color: "sky"} | _]} =
             DstarDemoWeb.Presence.get_by_key("presence:lobby", tab_id)
  end

  test "presence_diff_summary counts joins and leaves" do
    diff = %{
      joins: %{"a" => %{metas: [%{}]}, "b" => %{metas: [%{}, %{}]}},
      leaves: %{"c" => %{metas: [%{}]}}
    }

    assert DstarDemoWeb.PresencePage.presence_diff_summary(diff) == {3, 1}
  end

  test "presence_diff_summary treats a key on both sides as an update, not churn" do
    diff = %{
      joins: %{"a" => %{metas: [%{}]}, "b" => %{metas: [%{}]}},
      leaves: %{"a" => %{metas: [%{}]}}
    }

    assert DstarDemoWeb.PresencePage.presence_diff_summary(diff) == {1, 0}
  end

  defp post_json(conn, path, signals) do
    conn = Plug.Test.init_test_session(conn, %{})
    csrf = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_req_header("content-type", "application/json")
    |> post(path, Jason.encode!(Map.put(signals, "csrf", csrf)))
  end

  defp post_form(conn, path, params) do
    conn = Plug.Test.init_test_session(conn, %{})
    csrf = Plug.CSRFProtection.get_csrf_token()

    post(conn, path, Map.put(params, "csrf", csrf))
  end

  defp assert_presence_diff(side, tab_id) do
    receive do
      %Phoenix.Socket.Broadcast{event: "presence_diff", payload: payload} ->
        if payload |> Map.fetch!(side) |> Map.has_key?(tab_id) do
          payload
        else
          assert_presence_diff(side, tab_id)
        end
    after
      1_000 -> flunk("expected presence #{side} diff for #{tab_id}")
    end
  end

  defp sse_response(conn) do
    assert conn.state == :chunked
    conn.resp_body
  end
end
