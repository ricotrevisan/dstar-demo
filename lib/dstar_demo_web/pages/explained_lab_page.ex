defmodule DstarDemoWeb.ExplainedLabPage do
  @moduledoc """
  Prototype 3 — the chaos lab. One shared simulation (`DstarDemo.ChaosLab`)
  of the same inbox app built twice, open in six tabs each. Every reader
  presses the same buttons and watches both worlds react.

  The lab is itself a Dstar page: the server holds the one copy of the lab,
  every button is a POST, and every open tab follows through one stream.
  """
  use DstarDemoWeb, :dstar_page

  import DstarDemoWeb.ExplainerComponents

  alias DstarDemo.ChaosLab
  alias DstarDemo.ChaosLab.Server

  @actions ~w(click deploy tunnel revoke reset)

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn, page_title: "The chaos lab — break LiveView and Dstar", lab: Server.get())
  end

  @impl Dstar.Page
  def stream_key(_conn), do: {:dstar_demo, :explained_lab}

  @impl Dstar.Page
  def handle_connect(conn, _params) do
    :ok = Server.subscribe()
    patch(conn, &lab/1, lab: Server.get())
  end

  @impl Dstar.Page
  def handle_info(:chaos_lab_changed, conn), do: patch(conn, &lab/1, lab: Server.get())

  @impl Dstar.Page
  def handle_disconnect(conn) do
    Server.unsubscribe()
    conn
  end

  @impl Dstar.Page
  def handle_event(conn, action, _signals) when action in @actions do
    patch(conn, &lab/1, lab: Server.dispatch(action))
  end

  @impl Dstar.Page
  def render(assigns) do
    assigns = Map.put(assigns, :snippet, DstarDemoWeb.Snippets.fetch!(:explained_lab))

    ~H"""
    <Layouts.flash_group flash={@flash} />

    <.article_shell>
      <.lede eyebrow="Explainer 3 · the chaos lab" title="Go ahead, break it">
        <p>
          Below are two copies of the same inbox app, one built with LiveView and one with
          Dstar. Each is open in six browser tabs, and every tab shows a live unread badge.
        </p>
        <p>
          Press the buttons: deploy, drive a tab into a tunnel, revoke a session. Watch what each
          model has to do. Nothing is measured, it's <em>counted</em>: a number only moves when
          the real callback would run.
        </p>
        <p>
          <strong>The lab is shared.</strong>
          Everyone reading this page right now is looking at the same lab. If someone else
          presses Deploy, you'll see it here.
        </p>
      </.lede>

      <section
        id="lab-section"
        class="mx-auto mt-12 max-w-[1040px]"
        data-init={connect()}
        data-on:online__window={connect()}
      >
        <.lab lab={@lab} />
      </section>

      <section class="mx-auto mt-20 max-w-[860px]">
        <.section_heading id="counters">How to read the counters</.section_heading>
        <dl class="mt-6 grid gap-x-8 gap-y-4 text-sm leading-6 sm:grid-cols-2">
          <.explain term="mount runs">
            <code>mount/3</code> or <code>mount/2</code> executions. LiveView runs it on the HTTP
            render and again on every socket (re)connect. Dstar runs it only on the GET.
          </.explain>
          <.explain term="auth checks">
            Times a session was checked, by the router plugs or by <code>on_mount</code>. Dstar
            checks on <em>every</em>
            request, so its number climbs faster. That's the point: there's one path, and it's
            always walked.
          </.explain>
          <.explain term="copies in memory">
            Page state held on the server between events. One per live LiveView tab. Zero for
            Dstar, which re-reads the database instead.
          </.explain>
          <.explain term="open connections">
            WebSockets or SSE streams. They're equal here on purpose: both pages have a live
            badge. A Dstar page with no stream would show zero.
          </.explain>
        </dl>
        <.para>
          Two honest results to look for. First, <strong>revoking a session needs a push in both
          models</strong>: a connection that's already open was authorized when it opened.
          Second, <strong>real-time costs the same</strong>
          in both: one PubSub message per open tab. What differs is what each tab does with it.
          A LiveView process updates its copy, and a Dstar stream re-reads the truth.
        </.para>
      </section>

      <section class="mx-auto mt-20 max-w-[860px]">
        <.section_heading id="made-of">This lab is a Dstar page</.section_heading>
        <.para>
          The server holds the only copy of the lab. Every button is a POST through the router.
          The reducer is a pure function, <code>DstarDemo.ChaosLab.apply_action/2</code>, and
          every open tab follows along through one stream. This is all the page code it takes:
        </.para>
        <div class="mt-6">
          <.code_block
            language={@snippet.wiring_language}
            label={@snippet.source}
            code={@snippet.wiring}
          />
        </div>
        <.para>
          Want the story behind the counters?
          <.xp_link href={~p"/explained/dx"}>Follow the arrows</.xp_link>
        </.para>
      </section>
    </.article_shell>
    """
  end

  # ── The lab ───────────────────────────────────────────────────────────

  attr :lab, :map, required: true

  def lab(assigns) do
    tunnel = Enum.find(assigns.lab.tabs, &(&1.id == ChaosLab.tunnel_tab()))
    assigns = assign(assigns, tunnel: tunnel, parity: rem(assigns.lab.seq, 2))

    ~H"""
    <div id="lab" class="border border-base-300">
      <div class="flex flex-wrap items-center gap-2 border-b border-base-300 bg-base-200 p-3">
        <.lab_button
          id="lab-click"
          action="click"
          icon="hero-cursor-arrow-rays-micro"
          label="A tab clicks"
          primary
        />
        <.lab_button id="lab-deploy" action="deploy" icon="hero-rocket-launch-micro" label="Deploy" />
        <.lab_button
          id="lab-tunnel"
          action="tunnel"
          icon="hero-signal-slash-micro"
          label={
            if(@tunnel.lv == :offline,
              do: "#{@tunnel.user} leaves the tunnel",
              else: "#{@tunnel.user} enters a tunnel"
            )
          }
        />
        <.lab_button
          id="lab-revoke"
          action="revoke"
          icon="hero-no-symbol-micro"
          label="Revoke Ada's session"
        />
        <span class="ml-auto"></span>
        <.lab_button id="lab-reset" action="reset" icon="hero-arrow-path-micro" label="Reset" />
      </div>

      <div class="grid md:grid-cols-2">
        <.world
          name="LiveView"
          tone="neutral"
          key={:lv}
          lab={@lab}
          parity={@parity}
          class="border-b border-base-300 md:border-r md:border-b-0"
        />
        <.world name="Dstar" tone="primary" key={:ds} lab={@lab} parity={@parity} />
      </div>

      <ol id="lab-log" class="border-t border-base-300">
        <li
          :for={{entry, i} <- Enum.with_index(@lab.log)}
          id={"lab-log-#{entry.seq}"}
          class={[
            "border-b border-base-300 px-4 py-3 last:border-b-0",
            i == 0 && "lab-log-enter bg-primary/5"
          ]}
        >
          <p class="text-sm font-semibold">{entry.title}</p>
          <div class="mt-2 grid gap-3 text-sm leading-6 md:grid-cols-2">
            <p class="flex gap-2 text-base-content/75">
              <span class="mt-2"><.swatch tone="neutral" /></span> {entry.lv}
            </p>
            <p class="flex gap-2 text-base-content/90">
              <span class="mt-2"><.swatch tone="primary" /></span> {entry.ds}
            </p>
          </div>
        </li>
      </ol>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :tone, :string, required: true
  attr :key, :atom, required: true
  attr :lab, :map, required: true
  attr :parity, :integer, required: true
  attr :class, :string, default: nil

  defp world(assigns) do
    counters = assigns.lab[assigns.key]
    flashed = assigns.lab.flash[assigns.key]
    assigns = assign(assigns, counters: counters, flashed: flashed)

    ~H"""
    <div id={"lab-#{@key}"} class={["p-4", @class]}>
      <p class="flex items-center gap-2 text-sm font-semibold"><.swatch tone={@tone} /> {@name}</p>

      <div class="mt-3 grid grid-cols-3 gap-2">
        <div
          :for={tab <- @lab.tabs}
          id={"lab-#{@key}-tab-#{tab.id}"}
          class={[
            "border px-2.5 py-2 transition",
            tab[@key] == :live && "border-base-300 bg-base-100",
            tab[@key] == :offline && "border-dashed border-warning bg-warning/10",
            tab[@key] == :out && "border-base-300 bg-base-200 opacity-50",
            tab.id in @flashed && "lab-ping-#{@parity}"
          ]}
        >
          <p class="flex items-center justify-between gap-1 text-xs font-semibold">
            <span class="truncate">{tab.user}</span>
            <span class={[
              "min-w-5 px-1 text-center font-mono text-[10px] tabular-nums",
              tab[@key] == :out && "bg-base-300 text-base-content/60",
              tab[@key] != :out && "bg-primary text-primary-content"
            ]}>
              {if(tab[@key] == :out, do: "–", else: badge(tab, @key))}
            </span>
          </p>
          <p class="mt-1 font-mono text-[10px] text-base-content/60">
            tab {tab.id} · {status_label(tab[@key], @key)}
          </p>
        </div>
      </div>

      <div class="mt-4 border border-base-300 bg-base-200 p-3">
        <p class="flex items-center justify-between text-xs font-semibold">
          <span class="flex items-center gap-1.5">
            <.icon name="hero-server-micro" class="size-3.5 opacity-60" /> server memory
          </span>
          <span class="font-mono font-normal text-base-content/65">
            {@counters.copies} {if(@counters.copies == 1, do: "copy", else: "copies")} of page state
          </span>
        </p>
        <div class="mt-2 flex h-4 gap-1">
          <span :for={_ <- List.duplicate(nil, @counters.copies)} class="w-4 bg-base-content/40">
          </span>
          <span :if={@counters.copies == 0} class="font-mono text-[10px] text-base-content/60">
            nothing held, the database is the copy
          </span>
        </div>
      </div>

      <dl class="mt-3 grid grid-cols-2 gap-2">
        <.counter label="mount runs" value={@counters.mounts} />
        <.counter label="auth checks" value={@counters.auth} />
        <.counter label="open connections" value={@counters.conns} />
        <.counter label="messages between processes" value={@counters.msgs} />
      </dl>
    </div>
    """
  end

  defp badge(tab, :lv), do: tab.lv_badge
  defp badge(tab, :ds), do: tab.ds_badge

  defp status_label(:live, :lv), do: "socket"
  defp status_label(:live, :ds), do: "stream"
  defp status_label(:offline, _), do: "in a tunnel"
  defp status_label(:out, _), do: "logged out"

  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp counter(assigns) do
    ~H"""
    <div class="border border-base-300 px-2.5 py-1.5">
      <dt class="text-[11px] text-base-content/65">{@label}</dt>
      <dd class="font-mono text-lg font-semibold tabular-nums">{@value}</dd>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :action, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :primary, :boolean, default: false

  defp lab_button(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      data-on:click={event(@action)}
      class={[
        "inline-flex items-center gap-1.5 rounded-md border px-3 py-1.5 text-sm font-medium transition",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary",
        @primary && "border-primary bg-primary text-primary-content",
        !@primary && "border-base-300 bg-base-100 hover:border-base-content/40"
      ]}
    >
      <.icon name={@icon} class="size-4" /> {@label}
    </button>
    """
  end

  attr :term, :string, required: true
  slot :inner_block, required: true

  defp explain(assigns) do
    ~H"""
    <div>
      <dt class="font-semibold">{@term}</dt>
      <dd class="mt-1 text-base-content/75 [&_code]:font-mono">{render_slot(@inner_block)}</dd>
    </div>
    """
  end
end
