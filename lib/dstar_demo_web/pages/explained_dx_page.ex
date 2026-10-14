defmodule DstarDemoWeb.ExplainedDxPage do
  @moduledoc """
  Prototype 2 — the developer-experience story, in the shape of Ash's
  "Introducing Signals": an inbox grows feature by feature while a sticky
  diagram redraws its arrows, then the same feature as code, then a real
  shared inbox streamed to every open tab.

  The diagram is SVG whose groups are shown by the `stage` signal; the
  inbox at the bottom is real Dstar backed by `DstarDemo.Inbox`.
  """
  use DstarDemoWeb, :dstar_page

  import DstarDemoWeb.ExplainerComponents

  alias DstarDemo.Inbox

  @stages [
    {1, "One page"},
    {2, "Log in, please"},
    {3, "The sidebar wants to know"},
    {4, "Other tabs want to know"},
    {5, "Then you deploy"}
  ]

  @lv_files [
    {"router.ex",
     ~S'''
     scope "/", MyAppWeb do
       pipe_through [:browser, :require_authenticated_user]

       live_session :require_authenticated_user,
         on_mount: [{MyAppWeb.UserAuth, :require_authenticated}] do
         live "/inbox", InboxLive
       end
     end
     '''},
    {"user_auth.ex",
     ~S'''
     # The socket skips the router pipeline, so the rule is written twice.
     def on_mount(:require_authenticated, _params, session, socket) do
       socket = mount_current_scope(socket, session)

       if socket.assigns.current_scope && socket.assigns.current_scope.user do
         {:cont, socket}
       else
         {:halt, redirect(socket, to: ~p"/users/log-in")}
       end
     end
     '''},
    {"layouts.ex",
     ~S'''
     <aside>
       {live_render(@socket, MyAppWeb.SidebarLive, id: "sidebar", sticky: true)}
     </aside>
     <main>{@inner_content}</main>
     '''},
    {"sidebar_live.ex",
     ~S'''
     defmodule MyAppWeb.SidebarLive do
       use MyAppWeb, :live_view

       # Rendered with live_render, not routed: declare the guard again.
       on_mount {MyAppWeb.UserAuth, :require_authenticated}

       def mount(_params, _session, socket) do
         scope = socket.assigns.current_scope
         if connected?(socket), do: Inbox.subscribe(scope)
         {:ok, assign(socket, unread: Inbox.unread_count(scope)), layout: false}
       end

       def handle_info({:inbox_changed, _message}, socket) do
         {:noreply, assign(socket, unread: Inbox.unread_count(socket.assigns.current_scope))}
       end

       def render(assigns) do
         ~H"""
         <a href={~p"/inbox"}>Inbox <span>{@unread}</span></a>
         """
       end
     end
     '''},
    {"inbox_live.ex",
     ~S'''
     def mount(_params, _session, socket) do
       scope = socket.assigns.current_scope
       if connected?(socket), do: Inbox.subscribe(scope)
       {:ok, stream(socket, :messages, Inbox.list(scope))}
     end

     # Inbox.mark_read!/2 broadcasts, so the sidebar's process hears about it.
     def handle_event("read", %{"id" => id}, socket) do
       message = Inbox.mark_read!(socket.assigns.current_scope, id)
       {:noreply, stream_insert(socket, :messages, message)}
     end

     def handle_info({:inbox_changed, message}, socket) do
       {:noreply, stream_insert(socket, :messages, message)}
     end
     '''}
  ]

  @ds_files [
    {"router.ex",
     ~S'''
     scope "/", MyAppWeb do
       pipe_through [:browser, :require_authenticated_user]

       dstar "/inbox", InboxPage
     end
     '''},
    {"layouts.ex",
     ~S'''
     <aside><.sidebar unread={@unread} /></aside>
     <main>{@inner_content}</main>

     def sidebar(assigns) do
       ~H"""
       <a id="sidebar" href={~p"/inbox"}>Inbox <span>{@unread}</span></a>
       """
     end
     '''},
    {"inbox_page.ex",
     ~S'''
     def mount(conn, _params) do
       scope = conn.assigns.current_scope
       assign(conn, messages: Inbox.list(scope), unread: Inbox.unread_count(scope))
     end

     # One response, two patches: the row and the sidebar, wherever it lives.
     def handle_event(conn, "read:" <> id, _signals) do
       scope = conn.assigns.current_scope
       message = Inbox.mark_read!(scope, id)

       conn
       |> patch(&message_row/1, message: message)
       |> patch(&Layouts.sidebar/1, unread: Inbox.unread_count(scope))
     end

     # Other tabs: <main data-init={connect()}> — a POST through the same plugs.
     def handle_connect(conn, _params) do
       Inbox.subscribe(conn.assigns.current_scope)
       conn
     end

     def handle_info({:inbox_changed, message}, conn) do
       conn
       |> patch(&message_row/1, message: message)
       |> patch(&Layouts.sidebar/1, unread: Inbox.unread_count(conn.assigns.current_scope))
     end
     '''}
  ]

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn,
      page_title: "Follow the arrows — an inbox in LiveView and Dstar",
      messages: Inbox.list(),
      unread: Inbox.unread_count()
    )
  end

  @impl Dstar.Page
  def stream_key(_conn), do: {:dstar_demo, :explained_dx}

  @impl Dstar.Page
  def handle_connect(conn, _params) do
    :ok = Inbox.subscribe()
    patch_inbox(conn)
  end

  @impl Dstar.Page
  def handle_info(:inbox_changed, conn), do: patch_inbox(conn)

  @impl Dstar.Page
  def handle_disconnect(conn) do
    Inbox.unsubscribe()
    conn
  end

  @impl Dstar.Page
  def handle_event(conn, "read:" <> id, _signals) do
    with {id, ""} <- Integer.parse(id), do: Inbox.mark_read(id)
    patch_inbox(conn)
  end

  def handle_event(conn, "read_all", _signals) do
    Inbox.mark_all_read()
    patch_inbox(conn)
  end

  def handle_event(conn, "deliver", _signals) do
    Inbox.deliver()
    patch_inbox(conn)
  end

  def handle_event(conn, "reset", _signals) do
    Inbox.reset()
    patch_inbox(conn)
  end

  # Every path ends here: re-read the truth, patch the two places it shows.
  defp patch_inbox(conn) do
    conn
    |> patch(&inbox_sidebar/1, unread: Inbox.unread_count())
    |> patch(&inbox_list/1, messages: Inbox.list())
  end

  @impl Dstar.Page
  def render(assigns) do
    assigns =
      Map.merge(
        assigns,
        Map.new(
          stages: @stages,
          lv_files: @lv_files,
          ds_files: @ds_files,
          snippet: DstarDemoWeb.Snippets.fetch!(:explained_dx)
        )
      )

    ~H"""
    <Layouts.flash_group flash={@flash} />

    <.article_shell signals={%{stage: 1, dxFiles: "lv", dxLane: "ds"}}>
      <.lede eyebrow="Explainer 2 · follow the arrows" title="An inbox grows up">
        <p>
          Every app starts as a tidy page. An inbox: a list of messages and a button to mark one
          read. In LiveView or in Dstar, it's one module and one router line, and both feel great.
        </p>
        <p>
          Then the requests arrive. Log in first. Put an unread badge in the sidebar. Keep other
          tabs in sync. Survive a deploy. None of them is unusual, and each one adds an arrow to
          the diagram.
        </p>
        <p>
          This post follows those arrows in both models. The question isn't which one <em>can</em>
          build the inbox, because both can. It's how many arrows you have to keep
          in your head once it's built.
        </p>
      </.lede>

      <section id="arrows" class="mt-20">
        <div class="mx-auto max-w-[68ch]">
          <.section_heading>Following the arrows</.section_heading>
          <.para>
            Scroll, and the diagram follows along. Solid arrows are HTTP requests. Animated ones
            are long-lived connections. Dashed outlines are processes that live as long as the tab.
          </.para>
        </div>

        <div class="mt-10 grid gap-8 lg:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)]">
          <div class="order-2 lg:order-1">
            <.step n={1} title="One page" signal="stage" id_prefix="dx-stage">
              <p>
                <strong>LiveView:</strong>
                <code>live "/inbox", InboxLive</code>. The browser GETs the page through your
                router, then opens a WebSocket that goes straight to a new <code>InboxLive</code>
                process. That's two trips already, but nothing needs
                guarding yet.
              </p>
              <p>
                <strong>Dstar:</strong>
                <code>dstar "/inbox", InboxPage</code>. The GET goes through your router, and so
                does every click, as a POST to <code>/inbox/_event/…</code>. There's one trip, and
                it repeats.
              </p>
            </.step>
            <.step n={2} title="Log in, please" signal="stage" id_prefix="dx-stage">
              <p>
                <strong>LiveView:</strong>
                <code>pipe_through :require_authenticated_user</code>
                guards the HTTP render. The WebSocket never runs that pipeline, so the same rule
                gets written again as an <code>on_mount</code>
                hook. Two paths in, kept in sync by hand.
              </p>
              <p>
                <strong>Dstar:</strong>
                the same <code>pipe_through</code>, and you're done. The GET, every event POST
                and every stream connect are ordinary requests. Page-specific rules ("is this my
                message?") go in <code>authorize/2</code>, which runs before every event.
              </p>
            </.step>
            <.step n={3} title="The sidebar wants to know" signal="stage" id_prefix="dx-stage">
              <p>
                Design wants an unread badge in the sidebar, which lives in the <em>layout</em>,
                on every page.
              </p>
              <p>
                <strong>LiveView:</strong>
                the layout isn't a process, so the badge becomes a sticky nested LiveView. That's
                a second process per tab, with its own mount and its own <code>on_mount</code>
                (it isn't routed). The page can't touch it, so it sends a message.
              </p>
              <p>
                <strong>Dstar:</strong>
                the badge is an element with an id. The same handler that marks a message read
                patches <code>#sidebar</code>
                in the same response. There's no owner and no message.
              </p>
            </.step>
            <.step n={4} title="Other tabs want to know" signal="stage" id_prefix="dx-stage">
              <p>Open the inbox in two tabs. Mark one read. The other should follow.</p>
              <p>
                <strong>Both:</strong>
                subscribe to PubSub and update in <code>handle_info</code>. LiveView does it in
                both of its processes. Dstar does it in one stream that the page opens with <code>data-init={"{connect()}"}</code>, and that POST passes through the same plugs.
              </p>
              <p>This is parity. Real-time isn't something you give up.</p>
            </.step>
            <.step n={5} title="Then you deploy" signal="stage" id_prefix="dx-stage">
              <p>
                <strong>LiveView:</strong>
                every socket drops. Each tab rejoins, so <em>two</em>
                processes per tab pass <code>on_mount</code>
                and run <code>mount/3</code>
                again to rebuild their copies, all at the same moment.
              </p>
              <p>
                <strong>Dstar:</strong>
                each stream re-POSTs <code>connect()</code>
                through the plugs and <code>handle_connect/2</code>
                re-reads the badge. <code>mount/2</code>
                doesn't run, and there's no copy to rebuild. Clicks were never connected to begin with.
              </p>
            </.step>
          </div>

          <div class="sticky top-0 z-10 order-1 self-start lg:static lg:order-2 lg:self-stretch">
            <div class="-mx-5 border-b border-base-300 bg-base-100/95 px-5 py-3 backdrop-blur sm:-mx-8 sm:px-8 lg:sticky lg:top-[10vh] lg:mx-0 lg:border lg:bg-base-100 lg:p-5">
              <.arrows stages={@stages} />
            </div>
          </div>
        </div>
      </section>

      <section id="code" class="mx-auto mt-24 max-w-[860px]">
        <div class="max-w-[68ch]">
          <.section_heading>The whole feature, as code</.section_heading>
          <.para>
            The inbox with login, a layout badge and live tabs, written both ways. These are
            illustrative excerpts in the style of <code>phx.gen.auth</code>.
          </.para>
        </div>

        <div class="mt-6 flex border-b border-base-300" role="tablist" aria-label="Choose a model">
          <.tab_button signal="dxFiles" key="lv" label="LiveView · 5 files, 2 processes per tab" />
          <.tab_button signal="dxFiles" key="ds" label="Dstar · 3 files, no copies" />
        </div>

        <div data-show="$dxFiles == 'lv'" class="mt-5 space-y-4">
          <.code_block :for={{file, code} <- @lv_files} code={code} label={file} />
        </div>
        <div data-show="$dxFiles == 'ds'" style="display: none" class="mt-5 space-y-4">
          <.code_block :for={{file, code} <- @ds_files} code={code} label={file} />
        </div>
      </section>

      <aside
        id="dx-sources"
        class="mx-auto mt-8 max-w-[860px] border-l-2 border-base-300 pl-4 text-sm leading-6 text-base-content/70 [&_code]:font-mono"
      >
        <strong class="text-base-content">Checked against the source.</strong>
        The LiveView side follows <code>phx.gen.auth</code>
        in Phoenix 1.8: the <code>:require_authenticated</code>
        hook, and the <code>live_socket_id</code>
        "disconnect" broadcast on log-out. In LiveView 1.1, a nested LiveView joins without a
        route, so its <code>live_session</code>
        hooks don't run. That's why <code>SidebarLive</code>
        declares its own <code>on_mount</code>.
      </aside>

      <section id="for-real" class="mx-auto mt-24 max-w-[860px]">
        <div class="max-w-[68ch]">
          <.section_heading>The inbox, for real</.section_heading>
          <.para>
            This one is live and shared by everyone reading this page. The messages are held on
            the server, which is the source of truth. Every button is a POST, and every open tab
            follows along through one stream. <strong>Open this page in a second tab</strong>
            and click in one of them.
          </.para>
        </div>

        <div
          id="dx-inbox"
          class="mt-8 grid border border-base-300 sm:grid-cols-[200px_minmax(0,1fr)]"
          data-init={connect()}
          data-on:online__window={connect()}
        >
          <div class="border-b border-base-300 bg-base-200 p-4 sm:border-r sm:border-b-0">
            <p class="font-mono text-[11px] tracking-wide text-base-content/60 uppercase">
              layout
            </p>
            <.inbox_sidebar unread={@unread} />
            <p class="mt-4 text-xs leading-5 text-base-content/60">
              This badge sits outside the page's main content and is patched by id.
            </p>
          </div>
          <div class="min-w-0 p-4">
            <div class="flex flex-wrap items-center justify-between gap-2">
              <p class="font-mono text-[11px] tracking-wide text-base-content/60 uppercase">
                page
              </p>
              <div class="flex flex-wrap gap-2">
                <.action_button
                  id="dx-deliver"
                  label="Deliver one"
                  icon="hero-envelope-micro"
                  click={event("deliver")}
                />
                <.action_button
                  id="dx-read-all"
                  label="Mark all read"
                  icon="hero-check-micro"
                  click={event("read_all")}
                />
                <.action_button
                  id="dx-reset"
                  label="Reset"
                  icon="hero-arrow-path-micro"
                  click={event("reset")}
                />
              </div>
            </div>
            <.inbox_list messages={@messages} />
          </div>
        </div>

        <div class="mt-8">
          <.code_block
            language={@snippet.wiring_language}
            label={@snippet.source}
            code={@snippet.wiring}
          />
        </div>
      </section>

      <section id="fair" class="mx-auto mt-24 max-w-[860px]">
        <div class="max-w-[68ch]">
          <.section_heading>Where each one wins</.section_heading>
        </div>
        <div class="mt-8 grid border-t border-l border-base-300 md:grid-cols-2">
          <.verdict
            title="LiveView wins when…"
            tone="neutral"
            items={[
              "**Updates are tiny and constant.** A diff on an open socket is smaller and faster than an HTTP round trip that returns HTML.",
              "**The state really belongs to the connection.** Presence, uploads and long wizards fit a process that lives as long as the tab.",
              "**You want the mature path.** LiveViewTest, JS commands, streams and years of answers on the forum."
            ]}
          />
          <.verdict
            title="Dstar wins when…"
            tone="primary"
            items={[
              "**You want one way in.** The router pipeline guards the page, every event and every stream.",
              "**Updates cross the page.** Any handler patches any element by id, whether it's the layout, a toast or another list.",
              "**Deploys should be boring.** Nothing remounts, and only open streams reconnect.",
              "**The truth should stay in one place.** No per-tab copy to rebuild, sync or forget to invalidate."
            ]}
          />
        </div>
        <.para>
          Both live happily in one Phoenix app, so you can choose per route.
          <.xp_link href={~p"/explained/lab"}>Now go break them</.xp_link>
        </.para>
      </section>
    </.article_shell>
    """
  end

  # ── Live inbox ────────────────────────────────────────────────────────

  attr :unread, :integer, required: true

  def inbox_sidebar(assigns) do
    ~H"""
    <a
      id="dx-sidebar"
      href="#dx-inbox"
      class="mt-3 flex items-center justify-between gap-2 text-sm font-semibold"
    >
      <span class="flex items-center gap-2">
        <.icon name="hero-inbox-micro" class="size-4 opacity-70" /> Inbox
      </span>
      <span class={[
        "min-w-6 px-1.5 py-0.5 text-center font-mono text-xs tabular-nums",
        @unread > 0 && "bg-primary text-primary-content",
        @unread == 0 && "bg-base-300 text-base-content/70"
      ]}>
        {@unread}
      </span>
    </a>
    """
  end

  attr :messages, :list, required: true

  def inbox_list(assigns) do
    ~H"""
    <ul id="dx-list" class="mt-4 divide-y divide-base-300 border border-base-300">
      <li
        :for={m <- @messages}
        id={"dx-message-#{m.id}"}
        class={["flex items-center justify-between gap-3 px-3 py-2.5", !m.read && "bg-primary/5"]}
      >
        <div class="min-w-0">
          <p class={["truncate text-sm", !m.read && "font-semibold", m.read && "text-base-content/70"]}>
            {m.subject}
          </p>
          <p class="text-xs text-base-content/60">{m.from}</p>
        </div>
        <button
          :if={!m.read}
          id={"dx-read-#{m.id}"}
          type="button"
          data-on:click={event("read:#{m.id}")}
          class="shrink-0 rounded-md border border-base-300 px-2.5 py-1 text-xs font-medium transition hover:border-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
        >
          Mark read
        </button>
        <span :if={m.read} class="shrink-0 font-mono text-[11px] text-base-content/50">read</span>
      </li>
    </ul>
    """
  end

  # ── The diagram ───────────────────────────────────────────────────────

  attr :stages, :list, required: true

  defp arrows(assigns) do
    ~H"""
    <div id="dx-diagram">
      <div class="flex items-center justify-between gap-3">
        <p class="text-sm font-semibold">
          <span class="font-mono text-xs text-base-content/60" data-text="'Stage ' + $stage + ' / 5'">
            Stage 1 / 5
          </span>
          <span
            class="ml-2"
            data-text={"#{Jason.encode!(["" | Enum.map(@stages, &elem(&1, 1))])}[$stage]"}
          >
            One page
          </span>
        </p>
        <div class="flex gap-1">
          <button
            :for={{n, title} <- @stages}
            type="button"
            title={title}
            aria-label={"Show stage #{n}: #{title}"}
            data-on:click={"$stage = #{n}"}
            class="size-2.5 rounded-full bg-base-300 transition hover:bg-base-content/40"
            data-class={"{'!bg-primary': $stage == #{n}}"}
          >
          </button>
        </div>
      </div>

      <%!-- Both panels stacked are taller than a phone screen, which breaks the
      sticky diagram. Below lg, show one model at a time. --%>
      <div class="mt-3 flex border-b border-base-300 lg:hidden" role="tablist" aria-label="Model">
        <.tab_button signal="dxLane" key="lv" label="LiveView" />
        <.tab_button signal="dxLane" key="ds" label="Dstar" />
      </div>

      <.panel name="LiveView" tone="neutral" lane="lv">
        <:tally>
          <span data-text="'auth paths: ' + ($stage >= 2 ? 2 : 0)">auth paths: 0</span>
          <span data-text="'processes per tab: ' + ($stage >= 3 ? 2 : 1)">processes per tab: 1</span>
        </:tally>
        <svg viewBox="0 0 360 206" class="w-full" role="img" aria-label="LiveView architecture">
          <.svg_defs id="lv" />
          <.box x={8} y={78} w={64} label="Browser" />
          <.box x={118} y={16} w={92} label="router plugs" sub="HTTP only" hot="$stage == 2" />
          <%!-- socket path: straight in until on_mount exists --%>
          <g data-show="$stage == 1">
            <path
              d="M72 102 C 150 140, 190 120, 252 96"
              class="dx-wire dx-wire-hot"
              marker-end="url(#lv-head)"
            />
            <text x="150" y="140" class="dx-sub">WebSocket</text>
          </g>
          <g data-show="$stage >= 2" style="display: none" class="dx-enter">
            <.box x={118} y={120} w={92} label="on_mount" sub="auth, again" hot="$stage == 2" />
            <path
              d="M72 104 L 118 134"
              class="dx-wire dx-wire-hot"
              data-class="{'dx-wire-bad': $stage == 5}"
              marker-end="url(#lv-head)"
            />
            <path
              d="M210 134 L 252 104"
              class="dx-wire dx-wire-hot"
              data-class="{'dx-wire-bad': $stage == 5}"
              marker-end="url(#lv-head)"
            />
            <text x="64" y="150" class="dx-sub" data-show="$stage == 5" style="display: none">
              rejoin!
            </text>
          </g>
          <%!-- HTTP path --%>
          <path d="M72 88 L 118 40" class="dx-wire" marker-end="url(#lv-head)" />
          <path d="M210 36 L 252 80" class="dx-wire" marker-end="url(#lv-head)" />
          <%!-- InboxLive process --%>
          <rect x="244" y="62" width="108" height="54" class="dx-proc" />
          <text x="248" y="58" class="dx-sub">process / tab</text>
          <.box x={252} y={72} w={92} label="InboxLive" sub="mount/3 ×2" hot="$stage == 5" />
          <%!-- sidebar process --%>
          <g data-show="$stage >= 3" style="display: none" class="dx-enter">
            <rect x="244" y="136" width="108" height="54" class="dx-proc" />
            <text x="248" y="202" class="dx-sub">2nd process / tab</text>
            <.box x={252} y={146} w={92} label="SidebarLive" sub="own on_mount" hot="$stage == 3" />
            <path d="M298 106 L 298 146" class="dx-wire dx-wire-hot" marker-end="url(#lv-head)" />
            <text x="302" y="130" class="dx-sub">msg</text>
          </g>
          <g data-show="$stage >= 4" style="display: none" class="dx-enter">
            <.box x={150} y={170} w={60} label="PubSub" hot="$stage == 4" />
            <path
              d="M210 180 C 230 170, 236 120, 250 100"
              class="dx-wire dx-wire-hot"
              marker-end="url(#lv-head)"
            />
            <path d="M210 186 L 250 172" class="dx-wire dx-wire-hot" marker-end="url(#lv-head)" />
          </g>
        </svg>
      </.panel>

      <.panel name="Dstar" tone="primary" lane="ds">
        <:tally>
          <span>auth paths: 1</span>
          <span data-text="'copies per tab: 0' + ($stage >= 4 ? ' · 1 stream' : '')">
            copies per tab: 0
          </span>
        </:tally>
        <svg viewBox="0 0 360 200" class="w-full" role="img" aria-label="Dstar architecture">
          <.svg_defs id="ds" />
          <rect x="8" y="58" width="72" height="82" class="dx-box" />
          <text x="16" y="74" class="dx-text">Browser</text>
          <g data-show="$stage >= 3" style="display: none" class="dx-enter">
            <rect x="16" y="84" width="56" height="18" class="dx-box dx-box-hot" />
            <text x="22" y="96" class="dx-sub">#sidebar</text>
          </g>
          <rect x="16" y="110" width="56" height="18" class="dx-box" />
          <text x="22" y="122" class="dx-sub">#list</text>

          <.box
            x={130}
            y={78}
            w={114}
            label="router plugs"
            sub="GET · events · streams"
            hot="$stage == 2 || $stage == 5"
          />
          <path d="M80 92 L 130 94" class="dx-wire" marker-end="url(#ds-head)" />
          <text x="86" y="84" class="dx-sub">POST</text>
          <path d="M244 94 L 262 72" class="dx-wire" marker-end="url(#ds-head)" />
          <.box x={262} y={50} w={90} label="InboxPage" sub="handle_event/3" hot="$stage == 3" />

          <g data-show="$stage >= 3" style="display: none" class="dx-enter">
            <path
              d="M262 64 C 200 20, 120 30, 74 88"
              class="dx-wire dx-wire-hot"
              marker-end="url(#ds-head)"
            />
            <text x="140" y="34" class="dx-sub">SSE: #list + #sidebar</text>
          </g>

          <g data-show="$stage >= 4" style="display: none" class="dx-enter">
            <path
              d="M80 130 C 120 150, 150 140, 176 112"
              class="dx-wire dx-wire-hot"
              data-class="{'dx-wire-bad': $stage == 5}"
              marker-end="url(#ds-head)"
            />
            <text
              x="88"
              y="158"
              class="dx-sub"
              data-text="$stage == 5 ? 'connect() again' : 'connect() stream'"
            >
              connect() stream
            </text>
            <.box x={262} y={150} w={90} label="PubSub" sub="handle_info/2" hot="$stage == 4" />
            <path d="M306 150 L 306 100" class="dx-wire dx-wire-hot" marker-end="url(#ds-head)" />
          </g>
        </svg>
      </.panel>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :tone, :string, required: true
  attr :lane, :string, required: true
  slot :tally, required: true
  slot :inner_block, required: true

  defp panel(assigns) do
    ~H"""
    <div
      class="mt-4 border-t border-base-300 pt-3 max-lg:mt-2 max-lg:border-t-0"
      data-class={"{'max-lg:hidden': $dxLane != '#{@lane}'}"}
    >
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <p class="flex items-center gap-2 text-sm font-semibold"><.swatch tone={@tone} /> {@name}</p>
        <p class="flex gap-3 font-mono text-[11px] text-base-content/65">{render_slot(@tally)}</p>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :x, :integer, required: true
  attr :y, :integer, required: true
  attr :w, :integer, required: true
  attr :label, :string, required: true
  attr :sub, :string, default: nil
  attr :hot, :string, default: "false"

  defp box(assigns) do
    ~H"""
    <g>
      <rect
        x={@x}
        y={@y}
        width={@w}
        height={if(@sub, do: 34, else: 24)}
        class="dx-box"
        data-class={"{'dx-box-hot': #{@hot}}"}
      />
      <text x={@x + 7} y={@y + 15} class="dx-text">{@label}</text>
      <text :if={@sub} x={@x + 7} y={@y + 27} class="dx-sub">{@sub}</text>
    </g>
    """
  end

  attr :id, :string, required: true

  defp svg_defs(assigns) do
    ~H"""
    <defs>
      <marker
        id={"#{@id}-head"}
        viewBox="0 0 10 10"
        refX="9"
        refY="5"
        markerWidth="6"
        markerHeight="6"
        orient="auto-start-reverse"
      >
        <path d="M0 0 L10 5 L0 10 z" class="dx-head" />
      </marker>
    </defs>
    """
  end
end
