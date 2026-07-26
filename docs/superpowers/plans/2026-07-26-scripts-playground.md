# Scripts Playground Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `/scripts` from three buttons with no visible effect into a playground where the visitor writes the JavaScript, watches it cross the wire, and sees three independent proofs that it ran.

**Architecture:** `DstarDemoWeb.ScriptsPage` grows three input surfaces — a JS editor bound to `$script_source`, a JSON payload field for `console_log/3`, a path field for `redirect/3`. Each handler prepends a server-rendered row into `#helper-log-entries` with `mode: :prepend`, so the log is itself a patch demo. One inline page script mirrors the browser console and observes which `<script data-demo-script>` tags survive `auto_remove: false`.

**Tech Stack:** Elixir 1.20, Phoenix 1.8.9, Dstar 0.1.4, Datastar, DaisyUI/Tailwind, ExUnit + LazyHTML.

**Spec:** `docs/superpowers/specs/2026-07-26-scripts-playground-design.md`

## Global Constraints

- **Never prefill `$script_source` from a URL param.** Typed JS is self-XSS (harmless). A `?code=` param makes a shareable link that runs attacker JS in a victim's browser. This rule must appear as a code comment beside the editor.
- **`snippet_drift_test.exs` enforces that `Snippets.all()[:scripts].wiring` appears verbatim (modulo leading whitespace) in `lib/dstar_demo_web/pages/scripts_page.ex`.** Any task that changes the quoted handler must update the snippet in the same commit.
- **`snippet_drift_test.exs` also enforces that a demo with a `liveview` side has a `note`.** `:scripts` already satisfies this. Do not delete `note`.
- HEEx does **not** interpolate `{...}` or `${...}` inside `<script>` tags — verified. Write plain JS.
- Do not write a literal `</script>` inside the inline page script; it terminates the element. `<script` alone is safe, but this plan avoids angle brackets in the residue output entirely.
- Colours come from theme tokens (`base-100/200/300`, `base-content`, `primary`, `warning`). No hardcoded `zinc-*`/`emerald-*` — `pages_test.exs` refutes those.
- Every interactive control needs `focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary`, matching `action_button/1`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/dstar_demo_web/pages/scripts_page.ex` | Modify. The whole page: mount, render, four handlers, log row + panel components, the inline page script. |
| `lib/dstar_demo_web/snippets.ex` | Modify `:scripts` entry only — `wiring` must quote the new `run` handler; `note` is reused by the new `<:note>` slot. |
| `test/dstar_demo_web/scripts_page_test.exs` | Create. All `/scripts` coverage, moved out of `pages_test.exs`. Follows the `presence_page_test.exs` precedent for a page with its own behaviour. |
| `test/dstar_demo_web/pages_test.exs` | Modify. Remove the three script tests (Task 1); update the key-point assertion (Task 7). |

`scripts_page.ex` stays one file. It ends around 320 lines — comparable to `patch_lab_page.ex` (391) and well under `presence_page.ex`. The page's markup, handlers, and log components change together and belong together.

---

### Task 1: Turn the static "Helper log" into a real append-only log

The current `script_log/1` renders three fixed sentences that never change. Replace it with a log that accumulates one row per helper call via `mode: :prepend`, plus a Clear button. The three existing handlers keep working; only the log changes.

**Files:**
- Modify: `lib/dstar_demo_web/pages/scripts_page.ex:49` (call site), `:143-174` (`script_log/1`), `:104-138` (handlers)
- Create: `test/dstar_demo_web/scripts_page_test.exs`
- Modify: `test/dstar_demo_web/pages_test.exs:336-363` (delete the three script tests)

**Interfaces:**
- Produces: `log_row/1` (public component, assigns `:id`, `:run`, `:helper`, `:detail`, `:tone`), `log_entries/1` (public component rendering `#helper-log-entries`), and `prepend_log(conn, run, helper, detail, opts \\ [])`. Tasks 2–4 all call `prepend_log/5`.

- [ ] **Step 1: Move the existing script tests into their own file**

Delete these three tests from `test/dstar_demo_web/pages_test.exs` (lines 336-363): `"script helpers emit console script"`, `"script helpers emit execute script with its marker attribute"`, `"script helpers emit redirect script"`. Also delete the comment block above the second one.

Create `test/dstar_demo_web/scripts_page_test.exs`:

```elixir
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
end
```

- [ ] **Step 2: Run the moved tests to confirm they still pass**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs test/dstar_demo_web/pages_test.exs`
Expected: PASS. This is a pure move — nothing has changed behaviourally yet.

- [ ] **Step 3: Commit the test move**

```bash
git add test/dstar_demo_web/scripts_page_test.exs test/dstar_demo_web/pages_test.exs
git commit -m "test: move scripts coverage into its own file"
```

- [ ] **Step 4: Write the failing tests for the real log**

Append to `test/dstar_demo_web/scripts_page_test.exs`:

```elixir
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
```

- [ ] **Step 5: Run them to verify they fail**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs`
Expected: FAIL — no `#helper-log-entries` in the markup, and no `"clear"` handler (a `Dstar.Page` with no matching `handle_event/3` clause raises `FunctionClauseError`).

- [ ] **Step 6: Replace `script_log/1` with the real log**

In `lib/dstar_demo_web/pages/scripts_page.ex`, delete `script_log/1` (lines 140-174) and add in its place:

```elixir
  attr :script_runs, :integer, required: true
  attr :last_script_action, :string, required: true

  def helper_log(assigns) do
    ~H"""
    <div id="helper-log" class="mt-5 border border-base-300 bg-base-100 p-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p class="text-sm font-semibold text-base-content">Helper log</p>
          <p class="mt-1 font-mono text-xs text-base-content/65">
            Last action:
            <span id="script-last-action" data-text="$last_script_action">
              {@last_script_action}
            </span>
          </p>
        </div>
        <div class="flex items-center gap-3">
          <button
            id="clear-log"
            data-on:click={event("clear")}
            class="flex items-center gap-1.5 rounded-md border border-base-300 px-2.5 py-1.5 text-xs font-medium text-base-content/80 transition hover:border-base-content/40 hover:bg-base-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
          >
            <.icon name="hero-arrow-path-micro" class="size-3.5" /> Clear
          </button>
          <span class="inline-flex items-center bg-info/20 px-2 py-0.5 font-mono text-xs text-base-content">
            runs <span id="script-run-count" class="ml-1" data-text="$script_runs">{@script_runs}</span>
          </span>
        </div>
      </div>

      <p
        class="mt-4 text-sm text-base-content/60"
        data-show="$script_runs === 0"
      >
        No helper has run yet.
      </p>

      <.log_entries />
    </div>
    """
  end

  # Rendered standalone by the clear handler with mode: :outer, which is why it
  # is its own component rather than markup inlined above.
  def log_entries(assigns) do
    ~H"""
    <div id="helper-log-entries" class="mt-4 grid gap-2"></div>
    """
  end

  attr :id, :string, required: true
  attr :run, :integer, required: true
  attr :helper, :string, required: true
  attr :detail, :string, required: true
  attr :tone, :string, default: "info"

  def log_row(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "border px-3 py-2",
        @tone == "info" && "border-base-300 bg-base-200",
        @tone == "warn" && "border-warning/40 bg-warning/10"
      ]}
    >
      <div class="flex items-baseline justify-between gap-3">
        <span class="font-mono text-xs font-semibold text-base-content">{@helper}</span>
        <span class="shrink-0 font-mono text-[11px] text-base-content/50">run {@run}</span>
      </div>
      <pre class="mt-1 overflow-x-auto font-mono text-xs leading-5 text-base-content/75">{@detail}</pre>
    </div>
    """
  end

  # Every handler logs the same way, and the row id is derived from the run
  # count so a re-run never collides with a row already on the page.
  defp prepend_log(conn, run, helper, detail, opts \\ []) do
    patch(
      conn,
      &log_row/1,
      [
        id: "log-row-#{run}",
        run: run,
        helper: helper,
        detail: detail,
        tone: Keyword.get(opts, :tone, "info")
      ],
      selector: "#helper-log-entries",
      mode: :prepend
    )
  end
```

- [ ] **Step 7: Update the call site and add logging to the three handlers**

At `lib/dstar_demo_web/pages/scripts_page.ex:49`, change:

```elixir
          <.script_log script_runs={@script_runs} last_script_action={@last_script_action} />
```

to:

```elixir
          <.helper_log script_runs={@script_runs} last_script_action={@last_script_action} />
```

Then add a `prepend_log/5` call to each of the three existing handlers. The `execute` handler becomes:

```elixir
  def handle_event(conn, "execute", signals) do
    runs = next_runs(signals)

    conn
    |> patch_signals(%{script_runs: runs, last_script_action: "execute_script"})
    |> prepend_log(runs, "execute_script/3", "sets document.documentElement.dataset.dstarScriptPulse")
    |> execute_script(
      "document.documentElement.dataset.dstarScriptPulse = #{Jason.encode!(Integer.to_string(runs))}",
      auto_remove: false,
      attributes: %{"data-demo-script" => "execute"}
    )
  end
```

The `console` handler gains, after its `patch_signals/2` line:

```elixir
    |> prepend_log(runs, "console_log/3", ~s(level: info\n%{demo: "dstar", helper: "console_log", run: #{runs}}))
```

The `redirect` handler gains, after its `patch_signals/2` line:

```elixir
    |> prepend_log(runs, "redirect/3", "navigating to /scripts?redirected=1")
```

- [ ] **Step 8: Add the clear handler**

Add after the `redirect` handler:

```elixir
  def handle_event(conn, "clear", _signals) do
    conn
    |> patch_signals(%{script_runs: 0, last_script_action: "idle"})
    |> patch(&log_entries/1, [], selector: "#helper-log-entries", mode: :outer)
  end
```

- [ ] **Step 9: Run the tests**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs`
Expected: PASS (6 tests).

- [ ] **Step 10: Update the wiring snippet, which Step 7 just broke**

`Snippets.all()[:scripts].wiring` quotes a contiguous block of the `execute` handler, and Step 7 inserted `prepend_log` into the middle of it. `snippet_drift_test` will fail. In `lib/dstar_demo_web/snippets.ex`, add the new line to the `:scripts` `wiring` value so it matches the handler again:

```elixir
        conn
        |> patch_signals(%{script_runs: runs, last_script_action: "execute_script"})
        |> prepend_log(runs, "execute_script/3", "sets document.documentElement.dataset.dstarScriptPulse")
        |> execute_script(
```

- [ ] **Step 10b: Run the full suite**

Run: `mix test`
Expected: PASS, including `snippet_drift_test`.

- [ ] **Step 11: Commit**

```bash
git add lib/dstar_demo_web/pages/scripts_page.ex lib/dstar_demo_web/snippets.ex test/dstar_demo_web/scripts_page_test.exs
git commit -m "feat: make the scripts helper log a real append-only log"
```

---

### Task 2: The JS editor

Add the hero editor: a textarea bound to `$script_source`, three presets that load starter snippets client-side, and a Run button that ships whatever is in the box.

**Files:**
- Modify: `lib/dstar_demo_web/pages/scripts_page.ex` (mount, render `:demo` slot, handlers)
- Modify: `lib/dstar_demo_web/snippets.ex` (`:scripts` `wiring` — the drift test requires this in the same commit)
- Modify: `test/dstar_demo_web/scripts_page_test.exs`

**Interfaces:**
- Consumes: `prepend_log/5` from Task 1.
- Produces: the `"run"` event, the `$script_source` signal, and `@presets` (a list of `{label, source}` tuples).

- [ ] **Step 1: Write the failing tests**

Append to `test/dstar_demo_web/scripts_page_test.exs`:

```elixir
  test "the editor is bound to the script_source signal", %{conn: conn} do
    response = conn |> get("/scripts") |> html_response(200)

    assert response =~ ~s(id="script-editor")
    assert response =~ "data-bind:script_source"
    assert response =~ ~s(id="script-run")
  end

  test "run ships the visitor's own source verbatim", %{conn: conn} do
    conn = post_event(conn, "run", %{"script_runs" => 0, "script_source" => "window.ran = 41 + 1"})
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
```

- [ ] **Step 2: Run them to verify they fail**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs`
Expected: FAIL — no `script-editor` in markup, and `"run"` has no `handle_event/3` clause.

- [ ] **Step 3: Add the presets and seed the signal in mount**

At the top of `lib/dstar_demo_web/pages/scripts_page.ex`, after `use DstarDemoWeb, :dstar_page`:

```elixir
  # Starter snippets. They are written into $script_source client-side, so
  # picking one costs no round trip — only Run ships anything.
  #
  # SECURITY: these are the ONLY source of prefilled editor content. Never seed
  # $script_source from a URL param. Typed JS reaches only the tab that typed it
  # (signals are per-connection), so this page is self-XSS, which is not a
  # vulnerability. A ?code= param would turn it into a real one: a shareable
  # link that runs attacker-authored JS in a victim's browser.
  @presets [
    {"Pulse the page",
     ~s(document.documentElement.dataset.dstarScriptPulse = String(Date.now()))},
    {"Flash the page",
     """
     document.body.style.filter = "invert(1)"
     setTimeout(function () { document.body.style.filter = "" }, 600)\
     """},
    {"Throw an error", ~s(throw new Error("This ran in your browser, not on the server."))}
  ]
```

Replace `mount/2` with:

```elixir
  @impl Dstar.Page
  def mount(conn, params) do
    redirected? = Map.has_key?(params, "redirected")
    {_label, first_preset} = hd(@presets)

    assign(conn,
      script_runs: 0,
      script_source: first_preset,
      last_script_action: if(redirected?, do: "redirect complete", else: "idle")
    )
  end
```

- [ ] **Step 4: Render the editor**

In `render/2`, add `@presets` to the assigns line:

```elixir
    assigns =
      assigns
      |> Map.put(:snippet, DstarDemoWeb.Snippets.fetch!(:scripts))
      |> Map.put(:presets, @presets)
```

Add `script_source: @script_source` to the `signals` map on `<.demo_shell>`.

Replace the `<div class="flex flex-wrap gap-2">` block of three `action_button`s (lines 27-47) with the editor:

```elixir
          <div class="flex flex-wrap items-center gap-2">
            <span class="font-mono text-xs tracking-wide text-base-content/65 uppercase">
              Presets
            </span>
            <button
              :for={{label, source} <- @presets}
              id={"preset-" <> (label |> String.downcase() |> String.replace(" ", "-"))}
              data-on:click={"$script_source = #{Jason.encode!(source)}"}
              class="rounded-md border border-base-300 px-2.5 py-1.5 text-xs font-medium text-base-content/80 transition hover:border-base-content/40 hover:bg-base-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            >
              {label}
            </button>
          </div>

          <textarea
            id="script-editor"
            data-bind:script_source
            rows="5"
            spellcheck="false"
            aria-label="JavaScript to run in your browser"
            class="mt-3 w-full resize-y border border-base-300 bg-base-100 p-3 font-mono text-[13px] leading-6 text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
          >{@script_source}</textarea>

          <div class="mt-3 flex flex-wrap items-center justify-between gap-3">
            <.action_button
              id="script-run"
              label="Run"
              icon="hero-bolt-micro"
              click={event("run")}
              active
            />
            <p class="max-w-[52ch] text-xs leading-5 text-base-content/60">
              This runs in your browser only. Signals are per-connection, so nothing you
              type here can reach anyone else's tab.
            </p>
          </div>
```

- [ ] **Step 5: Add the run handler**

Replace the `"execute"` handler with:

```elixir
  def handle_event(conn, "run", signals) do
    runs = next_runs(signals)
    source = to_string(signals["script_source"] || "")

    if String.trim(source) == "" do
      conn
      |> patch_signals(%{script_runs: runs, last_script_action: "nothing to run"})
      |> prepend_log(runs, "execute_script/3", "Nothing to run — the editor is empty.", tone: "warn")
    else
      conn
      |> patch_signals(%{script_runs: runs, last_script_action: "execute_script"})
      |> prepend_log(runs, "execute_script/3", source)
      |> execute_script(source,
        auto_remove: false,
        attributes: %{"data-demo-script" => "run"}
      )
    end
  end
```

- [ ] **Step 6: Update the wiring snippet**

The `"execute"` handler no longer exists, so `snippet_drift_test` will fail. In `lib/dstar_demo_web/snippets.ex`, replace the `:scripts` `wiring` value (lines 454-466) with the `else` branch above, copied verbatim:

```elixir
      wiring: """
      conn
      |> patch_signals(%{script_runs: runs, last_script_action: "execute_script"})
      |> prepend_log(runs, "execute_script/3", source)
      |> execute_script(source,
        auto_remove: false,
        attributes: %{"data-demo-script" => "run"}
      )
      """,
```

- [ ] **Step 7: Delete the now-dead execute test**

In `test/dstar_demo_web/scripts_page_test.exs`, delete `"execute helper emits its marker attribute"` — the `"run"` tests replace it.

- [ ] **Step 8: Run the tests**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs test/dstar_demo_web/snippet_drift_test.exs`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/dstar_demo_web/pages/scripts_page.ex lib/dstar_demo_web/snippets.ex test/dstar_demo_web/scripts_page_test.exs
git commit -m "feat: let the visitor write the JavaScript execute_script ships"
```

---

### Task 3: The console_log payload input

`console_log/3` takes a map, not JS source, so it gets its own compact input rather than sharing the editor.

**Files:**
- Modify: `lib/dstar_demo_web/pages/scripts_page.ex` (mount, `:demo` slot, `console` handler)
- Modify: `test/dstar_demo_web/scripts_page_test.exs`

**Interfaces:**
- Consumes: `prepend_log/5` (Task 1).
- Produces: `$console_payload` and `$console_level` signals; `console_level/1` private helper returning `:info | :warn | :error`.

- [ ] **Step 1: Write the failing tests**

Replace the existing `"console helper emits a console script"` test in `test/dstar_demo_web/scripts_page_test.exs` with:

```elixir
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
```

- [ ] **Step 2: Run them to verify they fail**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs`
Expected: FAIL — the handler ignores `console_payload` and hardcodes `level: :info`.

- [ ] **Step 3: Seed the new signals in mount**

Add to the `assign/2` call in `mount/2`:

```elixir
      console_payload: ~s({"demo": "dstar", "helper": "console_log"}),
      console_level: "info",
```

Add `console_payload: @console_payload, console_level: @console_level` to the `signals` map on `<.demo_shell>`.

- [ ] **Step 4: Render the input**

Add inside the `<section>`, after the editor's Run row:

```elixir
          <div class="mt-6 border-t border-base-300 pt-5">
            <label for="console-payload" class="text-sm font-semibold text-base-content">
              console_log/3 payload
            </label>
            <p class="mt-1 text-xs text-base-content/60">
              JSON. It reaches the helper as a map, which
              <code class="font-mono">Jason.encode!/1</code> renders into the console call.
            </p>
            <div class="mt-2 flex flex-wrap items-end gap-2">
              <input
                id="console-payload"
                type="text"
                data-bind:console_payload
                value={@console_payload}
                class="min-w-0 flex-1 border border-base-300 bg-base-100 px-3 py-2 font-mono text-[13px] text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
              />
              <select
                id="console-level"
                data-bind:console_level
                aria-label="Console level"
                class="border border-base-300 bg-base-100 px-3 py-2 font-mono text-[13px] text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
              >
                <option value="info" selected={@console_level == "info"}>info</option>
                <option value="warn" selected={@console_level == "warn"}>warn</option>
                <option value="error" selected={@console_level == "error"}>error</option>
              </select>
              <.action_button
                id="script-console"
                label="Log it"
                icon="hero-command-line-micro"
                click={event("console")}
              />
            </div>
          </div>
```

- [ ] **Step 5: Rewrite the console handler**

```elixir
  def handle_event(conn, "console", signals) do
    runs = next_runs(signals)
    level = console_level(signals["console_level"])
    payload = to_string(signals["console_payload"] || "")

    case Jason.decode(payload) do
      {:ok, decoded} ->
        conn
        |> patch_signals(%{script_runs: runs, last_script_action: "console_log"})
        |> prepend_log(runs, "console_log/3", "level: #{level}\n#{payload}")
        |> console_log(decoded,
          level: level,
          auto_remove: false,
          attributes: %{"data-demo-script" => "console"}
        )

      {:error, _reason} ->
        conn
        |> patch_signals(%{script_runs: runs, last_script_action: "console_log rejected"})
        |> prepend_log(runs, "console_log/3", "Rejected — #{payload} is not valid JSON.",
          tone: "warn"
        )
    end
  end
```

Add beside `next_runs/1`:

```elixir
  # A signal is untrusted input, so the level is matched rather than converted:
  # String.to_existing_atom/1 on an arbitrary signal is a way to crash a handler.
  defp console_level("warn"), do: :warn
  defp console_level("error"), do: :error
  defp console_level(_), do: :info
```

- [ ] **Step 6: Run the tests**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/dstar_demo_web/pages/scripts_page.ex test/dstar_demo_web/scripts_page_test.exs
git commit -m "feat: take the console_log payload and level from the visitor"
```

---

### Task 4: The redirect path input and the seeded post-redirect row

`redirect/3` is a full page load, so it wipes the log. Turn that into the lesson: seed one row on arrival explaining why the log is empty.

**Files:**
- Modify: `lib/dstar_demo_web/pages/scripts_page.ex` (mount, `:demo` slot, `redirect` handler, `log_entries/1`)
- Modify: `test/dstar_demo_web/scripts_page_test.exs`

**Interfaces:**
- Consumes: `prepend_log/5` (Task 1), `log_row/1` (Task 1).
- Produces: `$redirect_path` signal; `log_entries/1` gains a required `:redirected?` boolean assign. **Task 1's `patch(&log_entries/1, [], ...)` call in the clear handler must be updated to pass it.**

- [ ] **Step 1: Write the failing tests**

Replace `"redirect helper emits a navigation script"` in `test/dstar_demo_web/scripts_page_test.exs` with:

```elixir
  test "redirect navigates to the visitor's path", %{conn: conn} do
    conn =
      post_event(conn, "redirect", %{"script_runs" => 0, "redirect_path" => "/scripts?redirected=1"})

    assert_patched_signals(conn, %{script_runs: 1, last_script_action: "redirect"})
    assert sse_body(conn) =~ "/scripts?redirected=1"
    assert sse_body(conn) =~ ~s(data-demo-script="redirect")
  end

  test "redirect refuses to leave the demo", %{conn: conn} do
    conn =
      post_event(conn, "redirect", %{"script_runs" => 0, "redirect_path" => "https://example.com"})

    body = sse_body(conn)

    assert body =~ "stays in-app"
    refute body =~ "example.com\""
    refute body =~ ~s(data-demo-script="redirect")
  end

  test "arriving after a redirect explains the empty log", %{conn: conn} do
    response = conn |> get("/scripts?redirected=1") |> html_response(200)

    assert response =~ "redirect/3"
    assert response =~ "full page load"
    refute conn |> recycle() |> get("/scripts") |> html_response(200) =~ "full page load"
  end
```

- [ ] **Step 2: Run them to verify they fail**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs`
Expected: FAIL — the handler hardcodes the path, and nothing renders a seeded row.

- [ ] **Step 3: Seed the signal and keep `redirected?` in assigns**

In `mount/2`, add `redirect_path: "/scripts?redirected=1"` and `redirected?: redirected?` to the `assign/2` call. Add `redirect_path: @redirect_path` to the `signals` map on `<.demo_shell>` — **but not `redirected?`**, which is server-side state, not a client signal.

- [ ] **Step 4: Render the input**

Add after the console_log block:

```elixir
          <div class="mt-6 border-t border-base-300 pt-5">
            <label for="redirect-path" class="text-sm font-semibold text-base-content">
              redirect/3 path
            </label>
            <p class="mt-1 text-xs text-base-content/60">
              A full page load, so it clears everything below. That is the point.
            </p>
            <div class="mt-2 flex flex-wrap items-end gap-2">
              <input
                id="redirect-path"
                type="text"
                data-bind:redirect_path
                value={@redirect_path}
                class="min-w-0 flex-1 border border-base-300 bg-base-100 px-3 py-2 font-mono text-[13px] text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
              />
              <.action_button
                id="script-redirect"
                label="Go"
                icon="hero-arrow-turn-up-right-micro"
                click={event("redirect")}
              />
            </div>
          </div>
```

- [ ] **Step 5: Rewrite the redirect handler**

```elixir
  def handle_event(conn, "redirect", signals) do
    runs = next_runs(signals)
    path = to_string(signals["redirect_path"] || "")

    # Dstar.Scripts.redirect/3 already runs the URL through Jason.encode!/1, so
    # this guard is not a security control — it keeps the demo from wandering
    # off to a page that cannot explain what just happened.
    if String.starts_with?(path, "/") do
      conn
      |> patch_signals(%{script_runs: runs, last_script_action: "redirect"})
      |> redirect(path,
        auto_remove: false,
        attributes: %{"data-demo-script" => "redirect"}
      )
    else
      conn
      |> patch_signals(%{script_runs: runs, last_script_action: "redirect rejected"})
      |> prepend_log(runs, "redirect/3", "Rejected — this demo stays in-app. Paths must start with /.",
        tone: "warn"
      )
    end
  end
```

- [ ] **Step 6: Seed the arrival row**

Change `log_entries/1` to:

```elixir
  attr :redirected?, :boolean, required: true

  # Rendered standalone by the clear handler with mode: :outer, which is why it
  # is its own component rather than markup inlined above.
  def log_entries(assigns) do
    ~H"""
    <div id="helper-log-entries" class="mt-4 grid gap-2">
      <.log_row
        :if={@redirected?}
        id="log-row-redirected"
        run={0}
        helper="redirect/3"
        detail="Navigated the browser here. A full page load, which is why this log starts empty."
      />
    </div>
    """
  end
```

Update `helper_log/1` to take and forward the flag: add `attr :redirected?, :boolean, required: true` and change `<.log_entries />` to `<.log_entries redirected?={@redirected?} />`. Update the call site in `render/2` to `<.helper_log script_runs={@script_runs} last_script_action={@last_script_action} redirected?={@redirected?} />`.

Update the clear handler — clearing should not resurrect the arrival row:

```elixir
    |> patch(&log_entries/1, [redirected?: false], selector: "#helper-log-entries", mode: :outer)
```

Also change the "No helper has run yet." paragraph's `data-show` so it does not sit under the seeded row on arrival:

```elixir
      <p
        :if={!@redirected?}
        class="mt-4 text-sm text-base-content/60"
        data-show="$script_runs === 0"
      >
```

- [ ] **Step 7: Run the tests**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/dstar_demo_web/pages/scripts_page.ex test/dstar_demo_web/scripts_page_test.exs
git commit -m "feat: take the redirect path from the visitor and explain the wiped log"
```

---

### Task 5: The console mirror and script residue panels

One inline page script does both jobs: wrap `console.*` into an in-page panel, and observe which `<script data-demo-script>` tags survive `auto_remove: false`.

**Files:**
- Modify: `lib/dstar_demo_web/pages/scripts_page.ex` (`:demo` slot)
- Modify: `test/dstar_demo_web/scripts_page_test.exs`

**Interfaces:**
- Produces: `observability_panels/1` (private component). No server-side interface — the panels are filled entirely by the browser.

- [ ] **Step 1: Write the failing test**

Append to `test/dstar_demo_web/scripts_page_test.exs`:

```elixir
  test "the page carries the console mirror and residue panels", %{conn: conn} do
    response = conn |> get("/scripts") |> html_response(200)

    assert response =~ ~s(id="console-mirror")
    assert response =~ ~s(id="script-residue")
    assert response =~ "MutationObserver"
    assert response =~ "Open your DevTools console"
  end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs`
Expected: FAIL — none of those ids exist.

- [ ] **Step 3: Add the panels and the page script**

Add `<.observability_panels />` inside the `<section>`, immediately after `<.helper_log ... />`. Then add the component. Note the JS uses plain string concatenation and a `script[data-demo-script=…]` selector rather than angle brackets — a literal `</script>` would close the element, and `<script` inside it is needless risk.

```elixir
  # The panels are inert markup; this one script fills both. It lives here
  # rather than in app.js because app.js is shared by all eight demos and
  # nothing outside this page needs a console wrapper.
  #
  # HEEx does not interpolate {...} or ${...} inside <script>, so this is plain
  # JavaScript, not a template.
  defp observability_panels(assigns) do
    ~H"""
    <div class="mt-5 grid gap-5 lg:grid-cols-2">
      <div class="border border-base-300 bg-base-100 p-4">
        <p class="text-sm font-semibold text-base-content">Console mirror</p>
        <p class="mt-1 text-xs leading-5 text-base-content/60">
          Open your DevTools console (⌘⌥J) — those are the real entries. This panel is a
          copy, and it mirrors everything the page logs, framework noise included.
        </p>
        <div id="console-mirror" class="mt-3 grid max-h-56 gap-1 overflow-y-auto"></div>
      </div>

      <div class="border border-base-300 bg-base-100 p-4">
        <p class="text-sm font-semibold text-base-content">Script residue</p>
        <p class="mt-1 text-xs leading-5 text-base-content/60">
          <code class="font-mono">auto_remove: false</code>
          leaves the tag in the DOM. These are the ones still there.
        </p>
        <pre
          id="script-residue"
          class="mt-3 max-h-56 overflow-auto font-mono text-xs leading-5 text-base-content/75"
        ></pre>
      </div>
    </div>

    <script>
      (function () {
        var mirror = document.getElementById("console-mirror")
        var residue = document.getElementById("script-residue")
        if (!mirror || !residue) return

        function append(level, text) {
          var row = document.createElement("div")
          row.className = "border-l-2 border-base-300 pl-2 font-mono text-xs text-base-content/80"
          row.textContent = level + ": " + text
          mirror.prepend(row)
          while (mirror.children.length > 20) mirror.lastChild.remove()
        }

        ;["log", "info", "warn", "error"].forEach(function (level) {
          var original = console[level].bind(console)
          console[level] = function () {
            var args = Array.prototype.slice.call(arguments)
            original.apply(console, args)
            append(
              level,
              args
                .map(function (a) {
                  return typeof a === "string" ? a : JSON.stringify(a)
                })
                .join(" ")
            )
          }
        })

        window.addEventListener("error", function (e) {
          append("uncaught", e.message)
        })

        function paint() {
          var tags = document.querySelectorAll("script[data-demo-script]")
          if (tags.length === 0) {
            residue.textContent = "No script tags left in the DOM yet."
            return
          }
          residue.textContent = Array.prototype.map
            .call(tags, function (t) {
              return "script[data-demo-script=" + t.dataset.demoScript + "]"
            })
            .join("\n")
        }

        new MutationObserver(paint).observe(document.body, {childList: true, subtree: true})
        paint()
      })()
    </script>
    """
  end
```

- [ ] **Step 4: Run the test**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs`
Expected: PASS.

- [ ] **Step 5: Verify in the browser**

Using `browser_eval`, load `/scripts`, click **Run** with the default preset, then confirm:
- a row appears in `#helper-log-entries`
- `#script-residue` lists `script[data-demo-script=run]`
- clicking **Log it** puts an entry in `#console-mirror`
- selecting the *Throw an error* preset and running it produces an `uncaught:` row

- [ ] **Step 6: Commit**

```bash
git add lib/dstar_demo_web/pages/scripts_page.ex test/dstar_demo_web/scripts_page_test.exs
git commit -m "feat: mirror the console and show which script tags survive"
```

---

### Task 6: Render the `<:note>` slot

`compare/1` has a `:note` slot built to carry the concession to LiveView. `snippet_drift_test` proves every demo *has* a note; no page in the repo *renders* one. Fix it for `/scripts` and add the test that would have caught it.

**Files:**
- Modify: `lib/dstar_demo_web/pages/scripts_page.ex` (`:comparison` slot)
- Modify: `test/dstar_demo_web/scripts_page_test.exs`

**Interfaces:**
- Consumes: `DstarDemoWeb.Snippets.fetch!(:scripts).note` — a Markdown-ish string with `**bold**` and backticked code, written as prose.

- [ ] **Step 1: Write the failing test**

Append to `test/dstar_demo_web/scripts_page_test.exs`:

```elixir
  test "the comparison concedes where LiveView wins", %{conn: conn} do
    response = conn |> get("/scripts") |> html_response(200)

    # The note in Snippets is the sharpest writing on this page and went
    # unrendered for its whole life. Assert the words, not just the slot.
    assert response =~ "push_event/3"
    assert response =~ "execute_script/3"
    assert response =~ "one mistake away from running in the browser"
  end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs`
Expected: FAIL on `"one mistake away from running in the browser"` — the note is never rendered.

- [ ] **Step 3: Pass the note slot**

The note in `snippets.ex` is prose with `**` and backticks. Render its paragraphs as plain text inside `<.prose>`; do not add a Markdown dependency. In the `<:comparison>` slot of `render/2`, add inside `<.compare>` after `<:liveview>`:

```elixir
          <:note>
            <p :for={para <- note_paragraphs(@snippet.note)} class="mt-3 first:mt-0">
              {para}
            </p>
          </:note>
```

Add the helper beside `next_runs/1`:

```elixir
  # The note is written as prose in Snippets, with `**` and backticks for a
  # reader of the source. Strip the markers rather than pull in a Markdown
  # dependency for one paragraph — the emphasis is a nicety, the words are not.
  defp note_paragraphs(note) do
    note
    |> String.replace("**", "")
    |> String.replace("`", "")
    |> String.split("\n\n", trim: true)
    |> Enum.map(&(&1 |> String.split("\n") |> Enum.join(" ") |> String.trim()))
  end
```

- [ ] **Step 4: Run the test**

Run: `mix test test/dstar_demo_web/scripts_page_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/dstar_demo_web/pages/scripts_page.ex test/dstar_demo_web/scripts_page_test.exs
git commit -m "feat: render the LiveView concession the scripts page always had"
```

---

### Task 7: Rewrite the page's prose

The summary and key points still describe three buttons. Bring the writing in line with what the page now is.

**Files:**
- Modify: `lib/dstar_demo_web/pages/scripts_page.ex` (`summary`, `key_points`, `:how_it_works` prose)
- Modify: `test/dstar_demo_web/pages_test.exs:467` (the key-point assertion)

- [ ] **Step 1: Update the key-point assertion in `pages_test.exs`**

At line 467, change:

```elixir
          {~p"/scripts", "execute_script/3 appends a script tag through a patch."},
```

to:

```elixir
          {~p"/scripts", "execute_script/3 ships the source you type, as a patched script tag."},
```

- [ ] **Step 2: Run it to verify it fails**

Run: `mix test test/dstar_demo_web/pages_test.exs`
Expected: FAIL — the page still renders the old bullet.

- [ ] **Step 3: Rewrite the summary**

In `render/2`, change the `summary` attribute on `<.demo_shell>` to:

```elixir
      summary="Write JavaScript here and the server ships it to your browser over SSE. Three panels prove it ran: a log of every helper call, a mirror of the browser console, and the script tags auto_remove: false leaves behind."
```

- [ ] **Step 4: Rewrite the key points**

Replace the `<.key_points>` items list with:

```elixir
        <.key_points items={[
          "execute_script/3 ships the source you type, as a patched script tag.",
          "console_log/3 takes a map, not code, and renders it through Jason.encode!/1.",
          "redirect/3 is a full page load, which is why it clears the log.",
          "auto_remove: false omits data-effect=\"el.remove()\", so the tag stays in the DOM.",
          "Signals are per-connection, so the code you type reaches only your own tab."
        ]} />
```

- [ ] **Step 5: Rewrite the how-it-works prose**

Replace the `<.prose>` block in `:how_it_works` with:

```elixir
        <.prose>
          All three helpers do the same thing underneath: append a one-shot
          <code class="font-mono text-sm">&lt;script&gt;</code>
          to the body through a patch. They differ in what they put inside it.
          <code class="font-mono text-sm">execute_script/3</code>
          takes source and passes it through untouched, which is why the editor above is
          the honest version of this demo. <code class="font-mono text-sm">console_log/3</code>
          takes a term and encodes it, so a map cannot become code by accident.
          <code class="font-mono text-sm">redirect/3</code>
          builds the navigation itself and runs the URL through
          <code class="font-mono text-sm">Jason.encode!/1</code>.
          With <code class="font-mono text-sm">auto_remove: false</code>
          the tag is left in the DOM — the residue panel lists the ones still there.
          The other demos avoid these helpers so the server-rendered patch flow stays
          easy to inspect.
        </.prose>
```

- [ ] **Step 6: Run the full suite**

Run: `mix test`
Expected: PASS.

- [ ] **Step 7: Format and check**

Run: `mix format && mix compile --warnings-as-errors`
Expected: no warnings.

- [ ] **Step 8: Verify the whole page in the browser**

Using `browser_eval`, load `/scripts` and walk the full path: pick each preset and Run it, log a payload at `warn`, submit malformed JSON, try an off-site redirect, then redirect in-app and confirm the seeded row explains the empty log.

- [ ] **Step 9: Commit**

```bash
git add lib/dstar_demo_web/pages/scripts_page.ex test/dstar_demo_web/pages_test.exs
git commit -m "docs: rewrite the scripts page prose around the playground"
```

---

## Self-Review Notes

**Spec coverage:** Editor + presets → Task 2. Console input → Task 3. Redirect input + seeded row → Task 4. Real log + Clear → Task 1. Console mirror → Task 5. Script residue → Task 5. `<:note>` slot → Task 6. Inline self-XSS note → Task 2 Step 4. No-URL-prefill comment → Task 2 Step 3. Handler input guards → Tasks 3 and 4. Writing → Task 7.

**Snippet drift:** enforced by `snippet_drift_test.exs`, not an open risk. Task 1 Step 10 and Task 2 Step 6 are the two required snippet updates; both are mandatory, not conditional. The spec was corrected to say so.

**Known wart:** `prepend_log/5` derives row ids from the run count, so clearing the log and re-running produces `log-row-1` again. That is safe only because Clear also removes the earlier rows. If a future change makes Clear reset the count without emptying the list, the ids collide.
