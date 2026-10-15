defmodule DstarDemoWeb.ExplainedDxPage do
  @moduledoc """
  The developer-experience story, in the shape of Ash's "Introducing
  Signals": an inbox grows feature by feature while a sticky diagram redraws
  its arrows, then the same feature as code, then a later feature as a pull
  request in both models, then a real shared inbox streamed to every open tab.

  The LiveView side is written the way Phoenix 1.8 recommends: the layout is
  a function component rendered inside the LiveView, and the layout's badge
  comes from an `on_mount` hook with `attach_hook/4`. The diagram is SVG whose
  groups are shown by the `stage` signal; the inbox at the bottom is real
  Dstar backed by `DstarDemo.Inbox`, and the stage-5 deploy button drives the
  same `DstarDemo.ChaosLab.Server` as `/explained/lab`.
  """
  use DstarDemoWeb, :dstar_page

  import DstarDemoWeb.ExplainerComponents

  alias DstarDemo.ChaosLab.Server
  alias DstarDemo.Inbox

  @stages [
    {1, "One page"},
    {2, "Log in, please"},
    {3, "The sidebar wants to know"},
    {4, "Other tabs want to know"},
    {5, "Then you deploy"}
  ]

  # ── The whole feature, as code ─────────────────────────────────────────
  # Files that differ between the two apps. phx.gen.auth's user_auth.ex and
  # the Inbox context are the same in both, so neither side counts them.

  @lv_files [
    {"router.ex",
     ~S'''
     scope "/", MyAppWeb do
       pipe_through [:browser, :require_authenticated_user]

       live_session :require_authenticated_user,
         on_mount: [{MyAppWeb.UserAuth, :require_authenticated}, MyAppWeb.Unread] do
         live "/inbox", InboxLive
         # ...every page with the sidebar lives in this live_session
       end
     end
     '''},
    {"unread.ex",
     ~S'''
     defmodule MyAppWeb.Unread do
       @moduledoc "Keeps the layout's unread badge fresh on every LiveView in the live_session."
       import Phoenix.Component, only: [assign: 3]
       import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]

       alias MyApp.Inbox

       def on_mount(:default, _params, _session, socket) do
         scope = socket.assigns.current_scope
         if connected?(socket), do: Inbox.subscribe(scope)

         {:cont,
          socket
          |> assign(:unread, Inbox.unread_count(scope))
          |> attach_hook(:unread, :handle_info, &handle_info/2)}
       end

       # :cont hands the message on, so the page can update its own rows.
       # Every LiveView in the live_session receives inbox messages.
       defp handle_info({:inbox_changed, _message}, socket) do
         {:cont, assign(socket, :unread, Inbox.unread_count(socket.assigns.current_scope))}
       end

       defp handle_info(_message, socket), do: {:cont, socket}
     end
     '''},
    {"layouts.ex",
     ~S'''
     attr :flash, :map, required: true
     attr :current_scope, :map, default: nil
     attr :unread, :integer, default: 0
     slot :inner_block, required: true

     def app(assigns) do
       ~H"""
       <aside>
         <.link navigate={~p"/inbox"}>Inbox <span>{@unread}</span></.link>
       </aside>
       <main>{render_slot(@inner_block)}</main>
       <.flash_group flash={@flash} />
       """
     end
     '''},
    {"inbox_live.ex",
     ~S'''
     def mount(_params, _session, socket) do
       {:ok, stream(socket, :messages, Inbox.list(socket.assigns.current_scope))}
     end

     # Every LiveView hands its layout the badge it was given by the hook.
     def render(assigns) do
       ~H"""
       <Layouts.app flash={@flash} current_scope={@current_scope} unread={@unread}>
         <ul id="messages" phx-update="stream">
           <.message_row :for={{id, message} <- @streams.messages} id={id} message={message} />
         </ul>
       </Layouts.app>
       """
     end

     # Inbox.mark_read!/2 broadcasts. The hook hears it and updates @unread.
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
     pipeline :unread do
       plug MyAppWeb.Unread
     end

     scope "/", MyAppWeb do
       pipe_through [:browser, :require_authenticated_user, :unread]

       dstar "/inbox", InboxPage
     end
     '''},
    {"unread.ex",
     ~S'''
     defmodule MyAppWeb.Unread do
       @moduledoc "Assigns the layout's unread badge. Runs on every request behind it."
       import Plug.Conn

       alias MyApp.Inbox

       def init(opts), do: opts

       def call(conn, _opts) do
         assign(conn, :unread, Inbox.unread_count(conn.assigns.current_scope))
       end
     end
     '''},
    {"layouts.ex",
     ~S'''
     attr :flash, :map, required: true
     attr :current_scope, :map, default: nil
     attr :unread, :integer, default: 0
     slot :inner_block, required: true

     def app(assigns) do
       ~H"""
       <aside><.unread_badge unread={@unread} /></aside>
       <main>{render_slot(@inner_block)}</main>
       <.flash_group flash={@flash} />
       """
     end

     attr :unread, :integer, required: true

     def unread_badge(assigns) do
       ~H"""
       <a id="sidebar" href={~p"/inbox"}>Inbox <span>{@unread}</span></a>
       """
     end
     '''},
    {"inbox_page.ex",
     ~S'''
     def mount(conn, _params) do
       assign(conn, :messages, Inbox.list(conn.assigns.current_scope))
     end

     def render(assigns) do
       ~H"""
       <Layouts.app flash={@flash} current_scope={@current_scope} unread={@unread}>
         <ul id="messages" data-init={connect()}>
           <.message_row :for={message <- @messages} message={message} />
         </ul>
       </Layouts.app>
       """
     end

     # One response, two patches: the row, and the badge in the layout.
     def handle_event(conn, "read:" <> id, _signals) do
       message = Inbox.mark_read!(conn.assigns.current_scope, id)

       conn
       |> patch(&message_row/1, message: message)
       |> patch_unread()
     end

     # Other tabs: connect() is a POST through the same plugs, then a stream.
     def handle_connect(conn, _params) do
       Inbox.subscribe(conn.assigns.current_scope)
       conn
     end

     def handle_info({:inbox_changed, message}, conn) do
       conn
       |> patch(&message_row/1, message: message)
       |> patch_unread()
     end

     # Nothing keeps the badge fresh for you: whatever changes it, patches it.
     defp patch_unread(conn) do
       patch(conn, &Layouts.unread_badge/1, unread: Inbox.unread_count(conn.assigns.current_scope))
     end
     '''}
  ]

  # ── A year later, as a pull request ───────────────────────────────────

  @lv_pr [
    {"lib/my_app_web/unread.ex", "the hook",
     ~S'''
        import Phoenix.Component, only: [assign: 3]
     -  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]
     +  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1, put_flash: 3]
      
        # ...
        defp handle_info({:inbox_changed, _message}, socket) do
          {:cont, assign(socket, :unread, Inbox.unread_count(socket.assigns.current_scope))}
        end
      
     +  defp handle_info({:new_message, message}, socket) do
     +    {:cont,
     +     socket
     +     |> assign(:unread, Inbox.unread_count(socket.assigns.current_scope))
     +     |> put_flash(:info, "New mail from #{message.from}: #{message.subject}")}
     +  end
     +
        defp handle_info(_message, socket), do: {:cont, socket}
     '''},
    {"lib/my_app_web/components/layouts.ex", "the layout",
     ~S'''
        def app(assigns) do
          ~H"""
     +    <header>
     +      <.link navigate={~p"/inbox"}>Inbox <span>{@unread}</span></.link>
     +    </header>
          <aside>
            <.link navigate={~p"/inbox"}>Inbox <span>{@unread}</span></.link>
          </aside>
          <main>{render_slot(@inner_block)}</main>
          <.flash_group flash={@flash} />
          """
        end
     '''},
    {"lib/my_app_web/live/inbox_live.ex", "the page",
     ~S'''
        def handle_info({:inbox_changed, message}, socket) do
          {:noreply, stream_insert(socket, :messages, message)}
        end
     +
     +  def handle_info({:new_message, message}, socket) do
     +    {:noreply, stream_insert(socket, :messages, message, at: 0)}
     +  end
     '''}
  ]

  @ds_pr [
    {"lib/my_app_web/components/layouts.ex", "the layout",
     ~S'''
        def app(assigns) do
          ~H"""
     +    <header><.unread_badge id="header" unread={@unread} /></header>
     -    <aside><.unread_badge unread={@unread} /></aside>
     +    <aside><.unread_badge id="sidebar" unread={@unread} /></aside>
          <main>{render_slot(@inner_block)}</main>
     +    <div id="toasts" role="status"></div>
          <.flash_group flash={@flash} />
          """
        end
      
     +  attr :id, :string, required: true
        attr :unread, :integer, required: true
      
        def unread_badge(assigns) do
          ~H"""
     -    <a id="sidebar" href={~p"/inbox"}>Inbox <span>{@unread}</span></a>
     +    <a id={@id} href={~p"/inbox"}>Inbox <span>{@unread}</span></a>
          """
        end
     +
     +  attr :message, :map, required: true
     +
     +  def toast(assigns) do
     +    ~H"""
     +    <p data-init__delay.5s="el.remove()">New mail from {@message.from}: {@message.subject}</p>
     +    """
     +  end
     '''},
    {"lib/my_app_web/pages/inbox_page.ex", "the page",
     ~S'''
        def handle_info({:inbox_changed, message}, conn) do
          conn
          |> patch(&message_row/1, message: message)
          |> patch_unread()
        end
     +
     +  def handle_info({:new_message, message}, conn) do
     +    conn
     +    |> patch(&message_row/1, [message: message], selector: "#messages", mode: :prepend)
     +    |> patch(&Layouts.toast/1, [message: message], selector: "#toasts", mode: :append)
     +    |> patch_unread()
     +  end
      
        defp patch_unread(conn) do
     -    patch(conn, &Layouts.unread_badge/1, unread: Inbox.unread_count(conn.assigns.current_scope))
     +    unread = Inbox.unread_count(conn.assigns.current_scope)
     +
     +    conn
     +    |> patch(&Layouts.unread_badge/1, id: "sidebar", unread: unread)
     +    |> patch(&Layouts.unread_badge/1, id: "header", unread: unread)
        end
     '''}
  ]

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn,
      page_title: "An inbox grows up: LiveView and Dstar, arrow by arrow",
      meta: %{
        description:
          "An inbox grows from one page to login, a layout badge, live tabs and a deploy, built with Phoenix LiveView 1.8 and with Dstar. Follow the arrows and count what each model asks of you.",
        path: ~p"/explained/dx",
        image: "/images/og/explained-dx.png",
        image_alt: "The arrows diagram: an inbox in LiveView and in Dstar",
        type: "article",
        published: ~D[2026-10-14]
      },
      messages: Inbox.list(),
      unread: Inbox.unread_count(),
      lab: Server.get()
    )
  end

  @impl Dstar.Page
  def stream_key(_conn), do: {:dstar_demo, :explained_dx}

  @impl Dstar.Page
  def handle_connect(conn, _params) do
    :ok = Inbox.subscribe()
    :ok = Server.subscribe()
    patch_inbox(conn)
  end

  @impl Dstar.Page
  def handle_info(:inbox_changed, conn), do: patch_inbox(conn)
  def handle_info(:chaos_lab_changed, conn), do: patch(conn, &deploy_demo/1, lab: Server.get())

  @impl Dstar.Page
  def handle_disconnect(conn) do
    Inbox.unsubscribe()
    Server.unsubscribe()
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

  # The same reducer as /explained/lab, so a deploy here shows up there too.
  def handle_event(conn, "lab_deploy", _signals) do
    patch(conn, &deploy_demo/1, lab: Server.dispatch("deploy"))
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
          lv_pr: @lv_pr,
          ds_pr: @ds_pr,
          bench: bench_memory(),
          snippet: DstarDemoWeb.Snippets.fetch!(:explained_dx)
        )
      )

    ~H"""
    <.article_shell signals={%{stage: 1, dxFiles: "lv", dxLane: "ds", dxPr: "lv"}}>
      <.lede eyebrow="Follow the arrows" title="An inbox grows up">
        <:dek>
          <a href="https://hexdocs.pm/dstar">Dstar</a>
          renders Phoenix pages over <a href="https://data-star.dev">Datastar</a>: the browser
          sends signals, the server answers with HTML patches over SSE, and there's no
          client-side app.
        </:dek>
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
          This post follows those arrows in both models, with the LiveView side written the way
          Phoenix 1.8 recommends. The question isn't which one <em>can</em>
          build the inbox, because both can. It's where each arrow goes, and what it costs once
          it's there.
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
                router, then opens a WebSocket, and an <code>InboxLive</code>
                process serves that tab for as long as it's open. Two trips, one process per tab.
              </p>
              <p>
                <strong>Dstar:</strong>
                <code>dstar "/inbox", InboxPage</code>. The GET goes through your router, and so
                does every click, as a POST to <code>/inbox/_event/…</code>. There's one kind of
                trip, it repeats, and nothing stays behind between clicks.
              </p>
            </.step>
            <.step n={2} title="Log in, please" signal="stage" id_prefix="dx-stage">
              <p>
                <strong>LiveView:</strong>
                <code>phx.gen.auth</code>
                puts <code>pipe_through :require_authenticated_user</code>
                on the scope, and the same check in an <code>on_mount</code>
                hook on the <code>live_session</code>. That's the documented pattern, and it's
                sound: the WebSocket never runs the router pipeline, and <code>on_mount</code>
                guards both the HTTP render and every socket mount. It's still a second path in,
                written in a second place, and the two have to agree.
              </p>
              <p>
                <strong>Dstar:</strong>
                the same <code>pipe_through</code>, and that's the only path. The GET, every event
                POST and every stream connect are ordinary requests. Page-specific rules ("is this
                my message?") go in <code>authorize/2</code>, which runs before every event.
              </p>
            </.step>
            <.step n={3} title="The sidebar wants to know" signal="stage" id_prefix="dx-stage">
              <p>
                Design wants an unread badge in the sidebar, which is part of the layout on every
                page.
              </p>
              <p>
                <strong>LiveView:</strong>
                in Phoenix 1.8 the layout is a function component, <code>&lt;Layouts.app&gt;</code>, rendered inside the LiveView, so the badge is just an assign. An
                <code>on_mount</code>
                hook on the <code>live_session</code>
                assigns <code>@unread</code>, and <code>attach_hook/4</code>
                keeps it fresh. Still one process per tab, no nested LiveView. The cost is
                wiring: the badge lives in each page's assigns, so every LiveView passes
                <code>unread={"{@unread}"}</code>
                to its layout, and only that page's process can change it.
              </p>
              <p>
                <strong>Dstar:</strong>
                the badge is an element with an id. A plug assigns the count for the first render.
                After that, any handler can patch <code>#sidebar</code>
                in the response it's already sending, and nothing owns it. The flip side: nothing
                keeps it fresh for you either. Whatever changes the count has to patch it.
              </p>
            </.step>
            <.step n={4} title="Other tabs want to know" signal="stage" id_prefix="dx-stage">
              <p>Open the inbox in two tabs. Mark one read. The other should follow.</p>
              <p>
                <strong>Both:</strong>
                subscribe to PubSub and update in <code>handle_info</code>. In LiveView, the hook
                already subscribed when the socket connected. Dstar opens one stream with <code>data-init={"{connect()}"}</code>, and that POST passes through the same plugs.
              </p>
              <p>
                This is parity, and so is the bill. A held-open stream costs about what a socket
                does: {@bench.ds} KB per tab against LiveView's {@bench.lv} KB in <.inline_link href={
                  ~p"/explained/lab#benchmark"
                }>the benchmark</.inline_link>. So open one only where a tab needs live updates. A page without one holds
                nothing.
              </p>
            </.step>
            <.step n={5} title="Then you deploy" signal="stage" id_prefix="dx-stage">
              <p>
                <strong>LiveView:</strong>
                every socket drops. Each tab rejoins, runs its <code>on_mount</code>
                hooks (auth and the badge) and <code>mount/3</code>
                again to rebuild its assigns, all at the same moment.
              </p>
              <p>
                <strong>Dstar:</strong>
                each stream re-POSTs <code>connect()</code>
                through the plugs, and <code>handle_connect/2</code>
                re-reads what it shows. <code>mount/2</code>
                doesn't run. Clicks were never connected, and pages without a stream don't notice.
              </p>
              <.deploy_demo lab={@lab} />
            </.step>
          </div>

          <div class="sticky top-0 z-10 order-1 self-start lg:static lg:order-2 lg:self-stretch">
            <div class="-mx-5 border-b border-base-300 bg-base-100/95 px-5 py-3 backdrop-blur sm:-mx-8 sm:px-8 lg:sticky lg:top-[10vh] lg:mx-0 lg:border lg:bg-base-100 lg:p-5">
              <.arrows stages={@stages} bench={@bench} />
            </div>
          </div>
        </div>
      </section>

      <section id="code" class="mx-auto mt-24 max-w-[860px]">
        <div class="max-w-[68ch]">
          <.section_heading>The whole feature, as code</.section_heading>
          <.para>
            The inbox with login, a layout badge and live tabs, written both ways. These are
            illustrative excerpts on top of <code>phx.gen.auth</code>, which generates the same
            <code>user_auth.ex</code>
            for both apps, so it isn't counted. Neither is the <code>Inbox</code>
            context, which is the same in both.
          </.para>
        </div>

        <div class="mt-6 flex border-b border-base-300" role="tablist" aria-label="Choose a model">
          <.tab_button
            signal="dxFiles"
            key="lv"
            label={"LiveView · #{length(@lv_files)} files · 2 processes per tab"}
          />
          <.tab_button
            signal="dxFiles"
            key="ds"
            label={"Dstar · #{length(@ds_files)} files · 1 process per tab, the stream"}
          />
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
        plug and <code>on_mount</code>
        hook, and the app layout as a function component. In LiveView 1.1, <code>on_mount</code>
        runs on the HTTP render and on every connected mount, and an <code>attach_hook/4</code>
        <code>:handle_info</code>
        hook that returns <code>{"{:cont, socket}"}</code>
        passes the message on to the page's own <code>handle_info/2</code>.
        Processes and memory per tab are the measured medians from the <.inline_link href={
          ~p"/explained/lab#benchmark"
        }>lab's benchmark</.inline_link>.
      </aside>

      <section id="payoff" class="mx-auto mt-24 max-w-[860px]">
        <div class="max-w-[68ch]">
          <.section_heading>Where it pays off, and where it doesn't</.section_heading>
          <.para>
            Say that a year from now, someone wants the unread count in the header too, and a
            toast when new mail arrives. <code>Inbox.deliver/2</code>
            now broadcasts <code>{"{:new_message, message}"}</code>, which is the same change in
            both apps. Here's the rest of that pull request, both ways:
          </.para>
        </div>

        <div class="mt-8 border border-base-300">
          <div class="flex flex-wrap items-center justify-between gap-3 border-b border-base-300 bg-base-200 px-4 py-3">
            <p class="text-sm font-semibold">Header badge and a new-mail toast</p>
            <div class="flex" role="tablist" aria-label="Choose a model">
              <.tab_button signal="dxPr" key="lv" label="With a hook" />
              <.tab_button signal="dxPr" key="ds" label="With a patch" />
            </div>
          </div>

          <div id="payoff-lv" data-show="$dxPr == 'lv'" class="space-y-4 p-4">
            <p class="text-sm text-base-content/75">
              <strong class="text-base-content">{length(@lv_pr)} files</strong>
              changed. The toast shows on every LiveView in the <code class="font-mono">live_session</code>.
            </p>
            <.diff_file :for={{file, owner, lines} <- @lv_pr} file={file} owner={owner} lines={lines} />
          </div>
          <div id="payoff-ds" data-show="$dxPr == 'ds'" style="display: none" class="space-y-4 p-4">
            <p class="text-sm text-base-content/75">
              <strong class="text-base-content">{length(@ds_pr)} files</strong>
              changed. The toast shows on pages with an open stream: here, the inbox.
            </p>
            <.diff_file :for={{file, owner, lines} <- @ds_pr} file={file} owner={owner} lines={lines} />
          </div>
        </div>

        <div class="max-w-[68ch]">
          <.para>
            With a hook, the change is split by owner. The hook owns the badge and the toast, the
            page owns its rows, and the layout shows what it's handed. In return, the toast
            reaches every LiveView in the <code>live_session</code>
            for free, because every page there is already a process subscribed to the inbox.
            (Put the toast in <code>InboxLive</code>
            instead, and it's two files with the same reach as Dstar's.)
          </.para>
          <.para>
            With a patch, the whole change lives in the handler that heard about the mail. It
            patches the row, both badges and the toast by id, and the layout only gives the toast
            somewhere to land. The catch is reach. Only a page with an open stream hears about
            new mail. A page without one shows the right count on its next request and costs
            nothing in between. To toast on every page, every page opens a stream, and pays
            what a socket costs.
          </.para>
          <.para>
            So if every page should be live, LiveView's hook is the better tool. If most pages
            are requests and a few are live, Dstar keeps each change next to the code that
            caused it, and the cost where you opted in.
          </.para>
        </div>
      </section>

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
              "**Every page should be live.** One hook on the live_session reaches every LiveView. There's no stream to open page by page.",
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
              "**Most pages are requests, and a few are live.** A page without a stream holds no process and no memory. You pay for live updates where you open one.",
              "**A change should live with the code that caused it.** Any handler patches any element by id, whether it's the layout, a toast or another list.",
              "**Deploys should be boring.** Streams reconnect without remounting, and pages without one don't notice."
            ]}
          />
        </div>
        <.para>
          Both live happily in one Phoenix app, so you can choose per route.
        </.para>
      </section>

      <.try_dstar>
        If the arrows on the right look like your app, Dstar is worth an afternoon. If the ones
        on the left do, LiveView's hook is already the right tool, and nothing here should
        change your mind.
      </.try_dstar>
    </.article_shell>

    <%!-- After the content, so crawlers and unfurlers read the H1 first. --%>
    <Layouts.flash_group flash={@flash} />
    """
  end

  @doc false
  # Measured medians from the smallest published benchmark run, in KB.
  def bench_memory do
    [run | _] = DstarDemo.BenchResults.all()

    %{
      lv: kb(run["models"]["liveview"]["Server memory per open tab"]),
      ds: kb(run["models"]["dstar"]["Server memory per open tab"]),
      tabs: run["params"]["tabs"]
    }
  end

  defp kb(bytes) when is_number(bytes), do: round(bytes / 1024)
  defp kb(_), do: 0

  # ── Stage 5: deploy, in place ─────────────────────────────────────────

  attr :lab, :map, required: true

  def deploy_demo(assigns) do
    assigns = assign(assigns, parity: rem(assigns.lab.seq, 2), latest: hd(assigns.lab.log))

    ~H"""
    <div id="dx-deploy" class="mt-2 border border-base-300 bg-base-100">
      <div class="flex flex-wrap items-center justify-between gap-2 border-b border-base-300 bg-base-200 px-3 py-2">
        <p class="text-xs text-base-content/70">The lab's six tabs, open in both apps.</p>
        <button
          id="dx-deploy-button"
          type="button"
          data-on:click={event("lab_deploy")}
          class="inline-flex items-center gap-1.5 rounded-md border border-primary bg-primary px-2.5 py-1 text-xs font-medium text-primary-content transition hover:brightness-110 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
        >
          <.icon name="hero-rocket-launch-micro" class="size-3.5" /> Deploy
        </button>
      </div>
      <div class="grid grid-cols-2 divide-x divide-base-300">
        <.deploy_world name="LiveView" tone="neutral" counters={@lab.lv} parity={@parity} />
        <.deploy_world name="Dstar" tone="primary" counters={@lab.ds} parity={@parity} />
      </div>
      <p class="border-t border-base-300 px-3 py-2 text-xs leading-5 text-base-content/70">
        <span class="font-semibold text-base-content">Last:</span> {@latest.title}.
        <a href={~p"/explained/lab"} class="underline underline-offset-2 hover:text-base-content">
          Open the full lab
        </a>
      </p>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :tone, :string, required: true
  attr :counters, :map, required: true
  attr :parity, :integer, required: true

  defp deploy_world(assigns) do
    ~H"""
    <div class="px-3 py-2.5">
      <p class="flex items-center gap-2 text-xs font-semibold"><.swatch tone={@tone} /> {@name}</p>
      <dl class="mt-2 space-y-1 font-mono text-[11px] text-base-content/70">
        <div class="flex justify-between gap-2">
          <dt>mount runs</dt>
          <dd class={["px-1 tabular-nums text-base-content", "lab-ping-#{@parity}"]}>
            {@counters.mounts}
          </dd>
        </div>
        <div class="flex justify-between gap-2">
          <dt>auth checks</dt>
          <dd class="px-1 tabular-nums text-base-content">{@counters.auth}</dd>
        </div>
        <div class="flex justify-between gap-2">
          <dt>open connections</dt>
          <dd class="px-1 tabular-nums text-base-content">{@counters.conns}</dd>
        </div>
      </dl>
    </div>
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
  attr :bench, :map, required: true

  @doc false
  def arrows(assigns) do
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

      <%!-- Both lanes use the same three counters. Processes and memory per
      open tab are the benchmark's measured medians. --%>
      <.panel name="LiveView" tone="neutral" lane="lv">
        <:tally>
          <.tally id="lv-auth" label="auth paths" expr="$stage >= 2 ? 2 : 0" initial="0" />
          <.tally id="lv-procs" label="processes per tab" expr="2" initial="2" />
          <.tally
            id="lv-memory"
            label="memory per tab"
            expr={"'#{@bench.lv} KB'"}
            initial={"#{@bench.lv} KB"}
          />
        </:tally>
        <svg viewBox="0 0 360 206" class="w-full" role="img" aria-label="LiveView architecture">
          <.svg_defs id="lv" />
          <.box x={8} y={78} w={64} label="Browser" />
          <.box x={118} y={16} w={92} label="router plugs" sub="HTTP only" hot="$stage == 2" />
          <%!-- socket path: straight in until on_mount exists --%>
          <g data-show="$stage == 1">
            <path
              d="M72 102 C 150 140, 190 130, 244 112"
              class="dx-wire dx-wire-hot"
              marker-end="url(#lv-head)"
            />
            <text x="140" y="146" class="dx-sub">WebSocket</text>
          </g>
          <g data-show="$stage >= 2" style="display: none" class="dx-enter">
            <.box
              x={118}
              y={120}
              w={92}
              label="on_mount"
              sub="auth, again"
              sub_expr="$stage >= 3 ? 'auth + @unread' : 'auth, again'"
              hot="$stage == 2 || $stage == 3"
            />
            <path
              d="M72 104 L 118 134"
              class="dx-wire dx-wire-hot"
              data-class="{'dx-wire-bad': $stage == 5}"
              marker-end="url(#lv-head)"
            />
            <path
              d="M210 136 L 244 126"
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
          <path d="M210 34 L 252 62" class="dx-wire" marker-end="url(#lv-head)" />
          <%!-- the one InboxLive process; from stage 3 the layout renders inside it --%>
          <rect
            x="244"
            y="50"
            width="108"
            height="56"
            class="dx-proc"
            data-class="{'dx-proc-tall': $stage >= 3}"
          />
          <text x="248" y="46" class="dx-sub">1 process / tab</text>
          <.box
            x={252}
            y={60}
            w={92}
            label="InboxLive"
            sub="mount/3 ×2"
            sub_expr="$stage == 5 ? 'mount/3 again' : 'mount/3 ×2'"
            hot="$stage == 1 || $stage == 5"
          />
          <g data-show="$stage >= 3" style="display: none" class="dx-enter">
            <.box x={252} y={104} w={92} label="Layouts.app" sub="@unread badge" hot="$stage == 3" />
          </g>
          <g data-show="$stage >= 4" style="display: none" class="dx-enter">
            <.box x={130} y={172} w={68} label="PubSub" hot="$stage == 4" />
            <path
              d="M198 182 C 224 182, 236 168, 250 150"
              class="dx-wire dx-wire-hot"
              marker-end="url(#lv-head)"
            />
            <text x="214" y="198" class="dx-sub">attach_hook</text>
          </g>
        </svg>
      </.panel>

      <.panel name="Dstar" tone="primary" lane="ds">
        <:tally>
          <.tally id="ds-auth" label="auth paths" expr="$stage >= 2 ? 1 : 0" initial="0" />
          <.tally id="ds-procs" label="processes per tab" expr="$stage >= 4 ? 1 : 0" initial="0" />
          <.tally
            id="ds-memory"
            label="memory per tab"
            expr={"$stage >= 4 ? '#{@bench.ds} KB' : '≈ 0 KB'"}
            initial="≈ 0 KB"
          />
        </:tally>
        <svg viewBox="0 0 360 210" class="w-full" role="img" aria-label="Dstar architecture">
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
            <rect x="254" y="142" width="104" height="50" class="dx-proc" />
            <text x="258" y="204" class="dx-sub">1 process / tab</text>
            <.box
              x={262}
              y={150}
              w={88}
              label="the stream"
              sub="handle_info/2"
              hot="$stage == 4 || $stage == 5"
            />
            <path d="M306 150 L 306 100" class="dx-wire dx-wire-hot" marker-end="url(#ds-head)" />
          </g>
        </svg>
      </.panel>

      <p class="mt-3 text-[11px] leading-4 text-base-content/60 max-lg:hidden">
        Processes and memory per open tab: measured medians from the benchmark, {@bench.tabs} tabs. A Dstar page without a stream holds neither.
      </p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :expr, :string, required: true
  attr :initial, :string, required: true

  defp tally(assigns) do
    ~H"""
    <span id={@id} class="whitespace-nowrap">
      {@label}: <span class="font-semibold text-base-content" data-text={@expr}>{@initial}</span>
    </span>
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
      <p class="flex items-center gap-2 text-sm font-semibold"><.swatch tone={@tone} /> {@name}</p>
      <p class="mt-1 flex flex-wrap gap-x-4 gap-y-0.5 font-mono text-[11px] text-base-content/65">
        {render_slot(@tally)}
      </p>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :x, :integer, required: true
  attr :y, :integer, required: true
  attr :w, :integer, required: true
  attr :label, :string, required: true
  attr :sub, :string, default: nil
  attr :sub_expr, :string, default: nil, doc: "Datastar expression that replaces `sub`"
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
      <text :if={@sub} x={@x + 7} y={@y + 27} class="dx-sub" data-text={@sub_expr}>{@sub}</text>
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
