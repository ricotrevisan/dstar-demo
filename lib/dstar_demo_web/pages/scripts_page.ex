defmodule DstarDemoWeb.ScriptsPage do
  use DstarDemoWeb, :dstar_page

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
     ~s[document.documentElement.dataset.dstarScriptPulse = String(Date.now())]},
    {"Flash the page",
     """
     document.body.style.filter = "invert(1)"
     setTimeout(function () { document.body.style.filter = "" }, 600)\
     """},
    {"Throw an error", ~s[throw new Error("This ran in your browser, not on the server.")]}
  ]

  @impl Dstar.Page
  def mount(conn, params) do
    redirected? = Map.has_key?(params, "redirected")
    {_label, first_preset} = hd(@presets)

    assign(conn,
      script_runs: 0,
      script_source: first_preset,
      last_script_action: if(redirected?, do: "redirect complete", else: "idle"),
      console_payload: ~s({"demo": "dstar", "helper": "console_log"}),
      console_level: "info",
      redirect_path: "/scripts?redirected=1",
      redirected?: redirected?
    )
  end

  @impl Dstar.Page
  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:snippet, DstarDemoWeb.Snippets.fetch!(:scripts))
      |> Map.put(:presets, @presets)

    ~H"""
    <.demo_shell
      active="Scripts"
      title="Script helpers"
      summary="Dstar can append safe script actions over SSE for one-off browser effects, console diagnostics, and redirects."
      signals={
        %{
          script_runs: @script_runs,
          last_script_action: @last_script_action,
          script_source: @script_source,
          console_payload: @console_payload,
          console_level: @console_level,
          redirect_path: @redirect_path
        }
      }
    >
      <:demo>
        <section class="border border-base-300 bg-base-200 p-5">
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

          <div class="mt-6 border-t border-base-300 pt-5">
            <label for="console-payload" class="text-sm font-semibold text-base-content">
              console_log/3 payload
            </label>
            <p class="mt-1 text-xs text-base-content/60">
              JSON. It reaches the helper as a map, which
              <code class="font-mono">Jason.encode!/1</code>
              renders into the console call.
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

          <.helper_log
            script_runs={@script_runs}
            last_script_action={@last_script_action}
            redirected?={@redirected?}
          />
        </section>
      </:demo>

      <:how_it_works>
        <.key_points items={[
          "execute_script/3 appends a script tag through a patch.",
          "console_log/3 emits structured browser console output.",
          "redirect/3 performs a server-commanded navigation.",
          "The helper scripts stay inert after they execute."
        ]} />

        <.prose>
          These three helpers append a one-shot <code class="font-mono text-sm">&lt;script&gt;</code>
          through a patch: <code class="font-mono text-sm">execute_script/3</code>
          runs browser code, <code class="font-mono text-sm">console_log/3</code>
          emits a structured console entry, and <code class="font-mono text-sm">redirect/3</code>
          commands a navigation. <code class="font-mono text-sm">auto_remove: false</code>
          leaves the tag in the DOM after it has run, so you can go and look at it. The other demos
          avoid these helpers so the server-rendered patch flow stays easy to inspect.
        </.prose>

        <div class="mt-6">
          <.code_block
            language={@snippet.wiring_language}
            label={@snippet.source}
            code={@snippet.wiring}
          />
        </div>
      </:how_it_works>

      <:comparison>
        <.prose>
          Both sides run browser code from the server and both perform a
          server-commanded navigation; they disagree about what crosses the wire.
        </.prose>

        <.compare>
          <:dstar>
            <.code_block
              language={@snippet.wiring_language}
              label={@snippet.source}
              code={@snippet.wiring}
            />
          </:dstar>

          <:liveview>
            <.code_block language="elixir" label="illustrative" code={@snippet.liveview} />
          </:liveview>
        </.compare>
      </:comparison>
    </.demo_shell>
    """
  end

  @impl Dstar.Page
  def handle_event(conn, "run", signals) do
    runs = next_runs(signals)
    source = to_string(signals["script_source"] || "")

    if String.trim(source) == "" do
      conn
      |> patch_signals(%{script_runs: runs, last_script_action: "nothing to run"})
      |> prepend_log(runs, "execute_script/3", "Nothing to run — the editor is empty.",
        tone: "warn"
      )
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
      |> prepend_log(
        runs,
        "redirect/3",
        "Rejected — this demo stays in-app. Paths must start with /.",
        tone: "warn"
      )
    end
  end

  def handle_event(conn, "clear", _signals) do
    conn
    |> patch_signals(%{script_runs: 0, last_script_action: "idle"})
    |> patch(&log_entries/1, [redirected?: false], selector: "#helper-log-entries", mode: :outer)
  end

  attr :script_runs, :integer, required: true
  attr :last_script_action, :string, required: true
  attr :redirected?, :boolean, required: true

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
            runs
            <span id="script-run-count" class="ml-1" data-text="$script_runs">{@script_runs}</span>
          </span>
        </div>
      </div>

      <p
        :if={!@redirected?}
        class="mt-4 text-sm text-base-content/60"
        data-show="$script_runs === 0"
      >
        No helper has run yet.
      </p>

      <.log_entries redirected?={@redirected?} />
    </div>
    """
  end

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

  # A signal is untrusted input, so the level is matched rather than converted:
  # String.to_existing_atom/1 on an arbitrary signal is a way to crash a handler.
  defp console_level("warn"), do: :warn
  defp console_level("error"), do: :error
  defp console_level(_), do: :info

  defp next_runs(signals) do
    case signals["script_runs"] do
      runs when is_integer(runs) -> runs + 1
      runs when is_binary(runs) -> String.to_integer(runs) + 1
      _ -> 1
    end
  rescue
    ArgumentError -> 1
  end
end
