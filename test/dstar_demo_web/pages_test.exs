defmodule DstarDemoWeb.PagesTest do
  use DstarDemoWeb.ConnCase

  import Dstar.Test

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Dstar server UI showcase"

    # Declared kebab-case so Datastar camelizes it to the exact "tabId"
    # signal the StreamRegistry reads — HTML lowercases attribute names,
    # so data-signals:tabId would silently create a "tabid" signal.
    assert response =~ ~s[data-signals:tab-id=]
    assert response =~ ~s[href="/commands"]
    assert response =~ ~s[href="/search"]
    assert response =~ ~s[href="/streaming"]
    assert response =~ ~s[href="/patch-lab"]
    assert response =~ ~s[href="/components"]
    assert response =~ ~s[href="/signals"]
    assert response =~ ~s[href="/scripts"]

    # Every demo is reachable from the home page, including presence, which the
    # original test omitted.
    assert response =~ ~s[href="/presence"]

    # Restyled onto theme tokens — no leftover hardcoded dark utilities.
    refute response =~ "bg-zinc-950"
    refute response =~ "text-zinc-100"
    refute response =~ "bg-emerald-300"
  end

  test "GET /commands", %{conn: conn} do
    conn = get(conn, ~p"/commands")

    response = html_response(conn, 200)
    assert response =~ "Form data validation"
    assert response =~ ~s[id="access-pass-form"]
    assert response =~ ~s[novalidate]
    assert response =~ ~s[name="_csrf_token"]
    assert response =~ ~s[name="email"]
    assert response =~ ~s[type="email"]
    assert response =~ ~s[required]
    refute response =~ "data-bind:email"
    refute response =~ "data-on-signal-patch"

    document = LazyHTML.from_document(response)
    form = LazyHTML.query(document, "#access-pass-form")
    email_input = LazyHTML.query(document, "#access-pass-email-input")
    first_name_input = LazyHTML.query(document, "#access-pass-first_name-input")

    [submit_action] = LazyHTML.attribute(form, "data-on:submit")
    assert submit_action =~ "/_event/validate"
    assert submit_action =~ "contentType: 'form'"

    assert LazyHTML.attribute(form, "novalidate") == [""]
    assert LazyHTML.attribute(email_input, "required") == [""]
    assert LazyHTML.attribute(first_name_input, "minlength") == ["2"]
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

      # Anchored on the preceding whitespace so this matches a real `id`
      # attribute and not the tail of another attribute's name. Makeup emits
      # `data-group-id="hl-1"` on both halves of a matching delimiter pair —
      # deliberately repeated, and not a DOM id at all.
      ids = Regex.scan(~r/\sid="([^"]+)"/, response, capture: :all_but_first) |> List.flatten()
      duplicate_ids = ids -- Enum.uniq(ids)

      assert duplicate_ids == [],
             "#{path} has duplicate ids: #{inspect(Enum.uniq(duplicate_ids))}"
    end
  end

  test "form validation submit accepts company email", %{conn: conn} do
    conn =
      post_form_event(conn, ~p"/commands", "validate", %{
        "email" => "ada@example.com",
        "first_name" => "Ada",
        "last_name" => "Lovelace"
      })

    conn
    |> assert_patched_element("#form-status")
    |> assert_patched_element("#access-pass-email-feedback")
    |> assert_patched_element("#access-pass-first_name-feedback")
    |> assert_patched_element("#access-pass-last_name-feedback")
    |> assert_patched_element("#validation-panel")
    |> assert_patched_element("#form-payload")

    assert sse_body(conn) =~ "accepted"
    refute sse_body(conn) =~ "datastar-patch-signals"
  end

  test "active search event patches only result panel", %{conn: conn} do
    conn = post_event(conn, ~p"/search", "search", %{"query" => "stream", "segment" => "all"})

    assert_patched_element(conn, "#search-results")
    assert sse_body(conn) =~ "Northstar Metrics"
    refute sse_body(conn) =~ "selector #search-query"

    # Echoing query/segment back would clobber whatever the user typed
    # while the response was in flight — the client owns those signals.
    refute sse_body(conn) =~ "datastar-patch-signals"
  end

  test "GET /search drives the pending banner from a client-local indicator", %{conn: conn} do
    response = conn |> get(~p"/search") |> html_response(200)

    assert response =~ ~s[data-indicator="_searchPending"]
    assert response =~ ~s[data-show="$_searchPending"]
    refute response =~ "$searchPending = true"
  end

  test "streaming page stream emits bounded dashboard stream", %{conn: conn} do
    conn = post_json(conn, ~p"/streaming", %{"tabId" => "test-tab"})

    assert_patched_signals(conn, %{streamStatus: "complete", progress: 100})
    assert sse_body(conn) =~ "selector #activity-log"
    assert sse_body(conn) =~ "mode prepend"
  end

  @tag timeout: 5_000
  test "streaming stream unregisters its tab key when the client drops mid-stream", %{
    conn: conn
  } do
    tab_id = "stream-error-tab"
    signals = %{"tabId" => tab_id}

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
               Dstar.Page.Plug.init({:stream, DstarDemoWeb.StreamingDashboardPage})
             )

    assert Registry.lookup(
             Dstar.Utility.StreamRegistry,
             {{:dstar_demo, :streaming_dashboard}, tab_id}
           ) == []
  end

  test "streaming stream unregisters its tab key on graceful completion", %{conn: conn} do
    conn = post_json(conn, ~p"/streaming", %{"tabId" => "stream-complete-tab"})

    assert_patched_signals(conn, %{streamStatus: "complete"})

    # The registered process (this test process, under keep-alive: the
    # connection process) outlives the completed stream; a stale entry
    # would let the next connect kill it mid-unrelated-request.
    assert Registry.lookup(
             Dstar.Utility.StreamRegistry,
             {{:dstar_demo, :streaming_dashboard}, "stream-complete-tab"}
           ) == []
  end

  test "patch lab events exercise every Datastar patch mode", %{conn: conn} do
    # outer is Datastar's default patch mode; dstar omits its mode line.
    cases = [
      {"outer", nil, "#lab-target", "Outer patch replaced this node"},
      {"inner", "mode inner", "#lab-target", "Inner patch 1"},
      {"append", "mode append", "#patch-list", "append patch #1"},
      {"prepend", "mode prepend", "#patch-list", "prepend patch #1"},
      {"before", "mode before", "#anchor-row", "before patch #1"},
      {"after", "mode after", "#anchor-row", "after patch #1"},
      {"remove", "mode remove", "#removable-note", nil}
    ]

    for {mode, mode_line, selector, marker} <- cases do
      event_conn =
        conn
        |> recycle()
        |> post_event(~p"/patch-lab", mode, %{"patch_count" => 0})

      body = sse_body(event_conn)
      if mode_line, do: assert(body =~ mode_line, "#{mode}: expected #{mode_line} in SSE body")
      assert body =~ "selector #{selector}", "#{mode}: expected selector #{selector}"
      if marker, do: assert(body =~ marker)
      assert_patched_signals(event_conn, %{selected_mode: mode, patch_count: 1})
    end
  end

  test "component stage events dispatch every kind to the Dstar.Component", %{conn: conn} do
    encoded = Dstar.Actions.encode_module(DstarDemoWeb.ComponentStage)

    for {kind, marker} <- [
          {"profile", "Ada Lovelace"},
          {"timeline", "Patch timeline"},
          {"deploy", "Deploy summary"}
        ] do
      event_conn =
        conn
        |> recycle()
        |> post_json("/ds/#{encoded}/#{kind}", %{"render_count" => 0})

      event_conn
      |> assert_patched_signals(%{component_kind: kind, render_count: 1})
      |> assert_patched_element("#component-stage")

      assert sse_body(event_conn) =~ marker
    end
  end

  test "form validation submit reports server errors", %{conn: conn} do
    conn =
      post_form_event(conn, ~p"/commands", "validate", %{
        "email" => "ada@personal.test",
        "first_name" => "Ada",
        "last_name" => "L"
      })

    conn
    |> assert_patched_element("#form-status")
    |> assert_patched_element("#access-pass-email-feedback")
    |> assert_patched_element("#access-pass-first_name-feedback")
    |> assert_patched_element("#access-pass-last_name-feedback")
    |> assert_patched_element("#validation-panel")
    |> assert_patched_element("#form-payload")

    assert sse_body(conn) =~ "server rejected"
    assert sse_body(conn) =~ "Use an @example.com email"
    assert sse_body(conn) =~ "Use at least 2 characters"
  end

  test "form reset event clears validation feedback", %{conn: conn} do
    conn =
      post_event(conn, ~p"/commands", "reset", %{
        "email" => "ada@example.com",
        "first_name" => "Ada",
        "last_name" => "Lovelace"
      })

    conn
    |> assert_patched_element("#form-status")
    |> assert_patched_element("#access-pass-email-feedback")
    |> assert_patched_element("#access-pass-first_name-feedback")
    |> assert_patched_element("#access-pass-last_name-feedback")
    |> assert_patched_element("#validation-panel")
    |> assert_patched_element("#form-payload")

    assert sse_body(conn) =~ "not submitted"
    assert sse_body(conn) =~ "Server feedback appears here"
    assert sse_body(conn) =~ "No form data has reached the server yet"
  end

  test "signals read event snapshots incoming signals into the inspector", %{conn: conn} do
    conn = post_event(conn, ~p"/signals", "read", %{"scope" => "beta", "server_tick" => 7})

    assert_patched_signals(conn, %{
      scope: "beta",
      server_tick: 7,
      audit_trail: "signals from handle_event/3"
    })

    assert_patched_element(conn, "#signals-inspector")
  end

  test "signals inspector can patch and remove signals", %{conn: conn} do
    patch_conn = post_event(conn, ~p"/signals", "patch", %{"server_tick" => 0})

    assert_patched_signals(patch_conn, %{
      server_tick: 1,
      audit_trail: "patch_signals tick 1"
    })

    remove_conn =
      conn
      |> recycle()
      |> post_event(~p"/signals", "remove", %{"ephemeral" => "client-note"})

    assert sse_body(remove_conn) =~ ~s("ephemeral":null)
    assert_patched_signals(remove_conn, %{audit_trail: "remove_signals ephemeral"})
  end

  test "GET /components binds the stage header and variant buttons to signals", %{conn: conn} do
    response = conn |> get(~p"/components") |> html_response(200)

    # Without these bindings the render counter, kind pill, and button
    # highlight are one-shot server renders that go stale after the first
    # component event.
    assert response =~ ~s[data-text="$render_count"]
    assert response =~ ~s[data-text="$component_kind"]
    assert response =~ ~s[$component_kind === &#39;profile&#39;]
  end

  test "GET /patch-lab binds the header and mode buttons to signals", %{conn: conn} do
    response = conn |> get(~p"/patch-lab") |> html_response(200)

    assert response =~ ~s[data-text="$patch_count"]
    assert response =~ ~s[data-text="$selected_mode"]
    assert response =~ ~s[$selected_mode === &#39;outer&#39;]
  end

  test "signals inspector snapshot does not re-embed itself", %{conn: conn} do
    conn =
      post_event(conn, ~p"/signals", "read", %{
        "server_tick" => 3,
        "last_read" => %{"previous" => "snapshot"}
      })

    # Round-tripping last_read inside itself nests one level per click.
    refute sse_body(conn) =~ "previous"
  end

  test "script helpers emit console script", %{conn: conn} do
    conn = post_event(conn, ~p"/scripts", "console", %{"script_runs" => 0})

    assert_patched_signals(conn, %{script_runs: 1, last_script_action: "console_log"})
    assert sse_body(conn) =~ "console.info"
    assert sse_body(conn) =~ ~s(data-demo-script="console")
    refute sse_body(conn) =~ "data-effect"
    refute sse_body(conn) =~ "selector #script-log"
  end

  # execute_script and redirect are the exact surfaces the dstar 0.1.2/0.1.3
  # security releases changed — keep regression coverage on their output.
  test "script helpers emit execute script with its marker attribute", %{conn: conn} do
    conn = post_event(conn, ~p"/scripts", "execute", %{"script_runs" => 0})

    assert_patched_signals(conn, %{script_runs: 1, last_script_action: "execute_script"})
    assert sse_body(conn) =~ "dstarScriptPulse"
    assert sse_body(conn) =~ ~s(data-demo-script="execute")
  end

  test "script helpers emit redirect script", %{conn: conn} do
    conn = post_event(conn, ~p"/scripts", "redirect", %{"script_runs" => 0})

    assert_patched_signals(conn, %{script_runs: 1, last_script_action: "redirect"})
    assert sse_body(conn) =~ "/scripts?redirected=1"
    assert sse_body(conn) =~ ~s(data-demo-script="redirect")
  end

  # /presence is not in demo_pages/0 — its marker is asserted by
  # presence_page_test.exs — but it is the largest page in the repo and the one
  # whose shell conversion carried the most risk, so the shell assertions run
  # against it too.
  test "demo pages render the documentation shell", %{conn: conn} do
    for {path, _marker} <- demo_pages() ++ [{~p"/presence", nil}] do
      response = conn |> recycle() |> get(path) |> html_response(200)

      # Persistent sidebar, listing every demo, on every page.
      assert response =~ ~s[aria-label="Demos"]
      assert response =~ ~s[href="/commands"]
      assert response =~ ~s[href="/presence"]

      # The three documentation sections, and the jump links to them.
      assert response =~ ~s[id="demo"]
      assert response =~ ~s[id="how-it-works"]
      assert response =~ ~s[href="#demo"]
      assert response =~ ~s[href="#how-it-works"]
      assert response =~ "How it works"

      # Sub-lg nav is a disclosure, not a drawer — no JavaScript involved.
      assert response =~ "<details"
    end
  end

  test "every demo page advertises and renders its LiveView comparison", %{conn: conn} do
    for {path, _marker} <- demo_pages() ++ [{~p"/presence", nil}] do
      response = conn |> recycle() |> get(path) |> html_response(200)

      assert response =~ ~s[href="#comparison"], "#{path} has no comparison jump link"
      assert response =~ ~s[id="comparison"], "#{path} renders no comparison section"
      assert response =~ "If this were LiveView"
      assert response =~ "illustrative, never compiled or run"
    end
  end

  # The notes are stored as plain text and rendered by rich_text/1. Before that
  # existed they were interpolated straight into HEEx, so readers saw literal
  # backticks and asterisks — twelve of them on one page.
  test "comparison notes render markup rather than showing its markers", %{conn: conn} do
    for {path, _marker} <- demo_pages() ++ [{~p"/presence", nil}] do
      response = conn |> recycle() |> get(path) |> html_response(200)

      comparison =
        response
        |> LazyHTML.from_document()
        |> LazyHTML.query("#comparison")

      text = LazyHTML.text(comparison)

      refute text =~ "`", "#{path} shows a literal backtick in its comparison"
      refute text =~ "**", "#{path} shows literal bold markers in its comparison"

      # …because the markers became elements, not because they were dropped.
      note = LazyHTML.query(comparison, "aside")
      assert LazyHTML.query(note, "code") |> Enum.count() > 0, "#{path}: note has no <code>"
      assert LazyHTML.query(note, "p") |> Enum.count() > 1, "#{path}: note is one paragraph"
    end
  end

  test "a comparison labels the LiveView side as illustrative", %{conn: conn} do
    response = conn |> recycle() |> get(~p"/search") |> html_response(200)

    assert response =~ "illustrative, never compiled or run"

    # The LiveView snippet is displayed as highlighted source, so its bindings
    # appear as escaped text rather than as live attributes on this page.
    assert response =~ "phx-debounce"
    assert response =~ "&quot;240&quot;"
  end

  # /components is deliberately absent: its dropped eyebrow was
  # "Dstar.Component", which is also a substring of the page's first key point
  # ("ComponentStage is a Dstar.Component: UI plus handle_event/3."). That
  # sentence is real page content the next test asserts, so the string cannot
  # double as a tombstone for the eyebrow.
  test "the dropped eyebrow no longer renders anywhere", %{conn: conn} do
    for {path, eyebrow} <- [
          {~p"/commands", "Form Data"},
          {~p"/search", "Signal search"},
          {~p"/streaming", "SSE stream"},
          {~p"/patch-lab", "DOM patch modes"},
          {~p"/signals", "Inspector"},
          {~p"/scripts", "Client actions"}
        ] do
      response = conn |> recycle() |> get(path) |> html_response(200)
      refute response =~ eyebrow
    end
  end

  test "each page's facts survive as key points inside How it works", %{conn: conn} do
    for {path, fact} <- [
          {~p"/commands", "novalidate keeps the browser from intercepting the demo."},
          {~p"/search", "data-bind keeps the query and segment on the client."},
          {~p"/streaming", "connect/1 posts to the page path and opens the stream."},
          {~p"/patch-lab", "outer replaces the target node."},
          {~p"/components", "ComponentStage is a Dstar.Component: UI plus handle_event/3."},
          {~p"/signals", "handle_event/3 receives the request signals already read."},
          {~p"/scripts", "execute_script/3 appends a script tag through a patch."},
          {~p"/presence", "Phoenix Presence tracks each browser tab as a visitor."}
        ] do
      response = conn |> recycle() |> get(path) |> html_response(200)
      assert response =~ fact
    end
  end

  test "each page renders a highlighted wiring snippet", %{conn: conn} do
    for {path, _marker} <- demo_pages() ++ [{~p"/presence", nil}] do
      response = conn |> recycle() |> get(path) |> html_response(200)
      # Makeup emits token spans; the .hl wrapper carries our token colours.
      assert response =~ ~s[class="hl min-w-0"]
      assert response =~ ~s[<span class="]
    end
  end

  defp demo_pages do
    [
      {~p"/commands", "Form data validation"},
      {~p"/search", "Active search"},
      {~p"/streaming", "Streaming dashboard"},
      {~p"/patch-lab", "Patch lab"},
      {~p"/components", "Server-rendered components"},
      {~p"/signals", "Signals lifecycle"},
      {~p"/scripts", "Script helpers"}
    ]
  end

  defp post_event(conn, page_path, event, signals) do
    post_json(conn, page_path <> "/_event/" <> event, signals)
  end

  defp post_form_event(conn, page_path, event, params) do
    conn = Plug.Test.init_test_session(conn, %{})
    csrf = Plug.CSRFProtection.get_csrf_token()

    post(conn, page_path <> "/_event/" <> event, Map.put(params, "_csrf_token", csrf))
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
