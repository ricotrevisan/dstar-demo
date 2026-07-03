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
    ~H"""
    <.demo_shell
      active="Scripts"
      title="Script helpers"
      eyebrow="Client actions"
      summary="Dstar can append safe script actions over SSE for one-off browser effects, console diagnostics, and redirects."
      signals={%{script_runs: @script_runs, last_script_action: @last_script_action}}
    >
      <:aside>
        <.demo_facts items={[
          "execute_script/3 appends a script tag through a patch.",
          "console_log/3 emits structured browser console output.",
          "redirect/3 performs a server-commanded navigation.",
          "The helper scripts stay inert after they execute."
        ]} />
      </:aside>

      <section class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_320px]">
        <div class="rounded-lg border border-zinc-800 bg-zinc-900 p-5">
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

          <.script_log script_runs={@script_runs} last_script_action={@last_script_action} />
        </div>

        <aside class="rounded-lg border border-zinc-800 bg-zinc-950 p-4">
          <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">
            Secondary helper lane
          </p>
          <p class="mt-3 text-sm leading-6 text-zinc-400">
            These helpers are useful for focused client effects. The main demos avoid them so the
            server-rendered patch flow stays easy to inspect.
          </p>
        </aside>
      </section>
    </.demo_shell>
    """
  end

  @impl Dstar.Page
  def handle_event(conn, "execute", signals) do
    runs = next_runs(signals)

    conn
    |> patch_signals(%{script_runs: runs, last_script_action: "execute_script"})
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
    |> redirect("/scripts?redirected=1",
      auto_remove: false,
      attributes: %{"data-demo-script" => "redirect"}
    )
  end

  attr :script_runs, :integer, required: true
  attr :last_script_action, :string, required: true

  def script_log(assigns) do
    ~H"""
    <div id="script-log" class="mt-5 rounded-lg border border-zinc-800 bg-zinc-950 p-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p class="text-sm font-semibold text-zinc-100">Helper log</p>
          <p class="mt-1 text-xs text-zinc-500">
            Last action:
            <span id="script-last-action" data-text="$last_script_action">
              {@last_script_action}
            </span>
          </p>
        </div>
        <span class="inline-flex items-center rounded-full bg-sky-300/15 px-2.5 py-1 text-xs font-semibold text-sky-200">
          runs <span id="script-run-count" class="ml-1" data-text="$script_runs">{@script_runs}</span>
        </span>
      </div>

      <div class="mt-4 grid gap-2 text-sm text-zinc-300">
        <div class="rounded-md border border-zinc-800 bg-zinc-900 px-3 py-2">
          execute_script mutates a data attribute through an appended script.
        </div>
        <div class="rounded-md border border-zinc-800 bg-zinc-900 px-3 py-2">
          console_log writes a structured object in the browser console.
        </div>
        <div class="rounded-md border border-zinc-800 bg-zinc-900 px-3 py-2">
          redirect navigates back to this page with a query flag.
        </div>
      </div>
    </div>
    """
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
