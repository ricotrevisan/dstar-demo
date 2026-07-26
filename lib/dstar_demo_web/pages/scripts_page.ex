defmodule DstarDemoWeb.ScriptsPage do
  use DstarDemoWeb, :dstar_page

  @impl Dstar.Page
  def mount(conn, params) do
    redirected? = Map.has_key?(params, "redirected")

    assign(conn,
      script_runs: 0,
      last_script_action: if(redirected?, do: "redirect complete", else: "idle")
    )
  end

  @impl Dstar.Page
  def render(assigns) do
    assigns = Map.put(assigns, :snippet, DstarDemoWeb.Snippets.fetch!(:scripts))

    ~H"""
    <.demo_shell
      active="Scripts"
      title="Script helpers"
      summary="Dstar can append safe script actions over SSE for one-off browser effects, console diagnostics, and redirects."
      signals={%{script_runs: @script_runs, last_script_action: @last_script_action}}
    >
      <:demo>
        <section class="border border-base-300 bg-base-200 p-5">
          <div class="flex flex-wrap gap-2">
            <.action_button
              id="script-execute"
              label="Execute"
              icon="hero-bolt-micro"
              click={event("execute")}
              active
            />
            <.action_button
              id="script-console"
              label="Console log"
              icon="hero-command-line-micro"
              click={event("console")}
            />
            <.action_button
              id="script-redirect"
              label="Redirect preview"
              icon="hero-arrow-turn-up-right-micro"
              click={event("redirect")}
            />
          </div>

          <.helper_log script_runs={@script_runs} last_script_action={@last_script_action} />
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
  def handle_event(conn, "execute", signals) do
    runs = next_runs(signals)

    conn
    |> patch_signals(%{script_runs: runs, last_script_action: "execute_script"})
    |> prepend_log(
      runs,
      "execute_script/3",
      "sets document.documentElement.dataset.dstarScriptPulse"
    )
    |> execute_script(
      "document.documentElement.dataset.dstarScriptPulse = #{Jason.encode!(Integer.to_string(runs))}",
      auto_remove: false,
      attributes: %{"data-demo-script" => "execute"}
    )
  end

  def handle_event(conn, "console", signals) do
    runs = next_runs(signals)

    conn
    |> patch_signals(%{script_runs: runs, last_script_action: "console_log"})
    |> prepend_log(
      runs,
      "console_log/3",
      ~s(level: info\n%{demo: "dstar", helper: "console_log", run: #{runs}})
    )
    |> console_log(%{demo: "dstar", helper: "console_log", run: runs},
      level: :info,
      auto_remove: false,
      attributes: %{"data-demo-script" => "console"}
    )
  end

  def handle_event(conn, "redirect", signals) do
    runs = next_runs(signals)

    conn
    |> patch_signals(%{script_runs: runs, last_script_action: "redirect"})
    |> prepend_log(runs, "redirect/3", "navigating to /scripts?redirected=1")
    |> redirect("/scripts?redirected=1",
      auto_remove: false,
      attributes: %{"data-demo-script" => "redirect"}
    )
  end

  def handle_event(conn, "clear", _signals) do
    conn
    |> patch_signals(%{script_runs: 0, last_script_action: "idle"})
    |> patch(&log_entries/1, [], selector: "#helper-log-entries", mode: :outer)
  end

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
            runs
            <span id="script-run-count" class="ml-1" data-text="$script_runs">{@script_runs}</span>
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
