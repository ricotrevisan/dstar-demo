defmodule DstarDemoWeb.HomePage do
  @moduledoc """
  The developer-experience story, in the shape of Ash's "Introducing
  Signals": an inbox grows feature by feature while a sticky diagram redraws
  its arrows, then the same feature as code, then a later feature as a pull
  request in both models, then a real shared inbox streamed to every open tab.

  The LiveView side is written the way Phoenix 1.8 recommends: the layout is
  a function component rendered inside the LiveView, and the layout's badge
  comes from an `on_mount` hook with `attach_hook/4`. The diagram is SVG whose
  groups are shown by the `stage` signal; the inbox at the bottom is real
  Dstar backed by `DstarDemo.Inbox`, and the stage-6 deploy button drives the
  same `DstarDemo.ChaosLab.Server` as `/explained/lab`.
  """
  use DstarDemoWeb, :dstar_page

  import DstarDemoWeb.ExplainerComponents

  alias DstarDemo.ChaosLab.Server
  alias DstarDemo.Inbox
  alias DstarDemoWeb.HomeCode

  @stages [
    {1, "A page with buttons"},
    {2, "Your plugs, twice"},
    {3, "The sidebar wants to know"},
    {4, "Other tabs want to know"},
    {5, "A second page"},
    {6, "Then you deploy"}
  ]

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn,
      page_title: "Interactive, without staying connected: Dstar for Phoenix",
      meta: %{
        description:
          "Dstar makes Phoenix pages interactive without a socket: every click is a request answered with HTML patches, and live updates are one attribute where you need them. An inbox built with LiveView 1.8 and with Dstar, arrow by arrow.",
        path: ~p"/",
        image: "/images/og/home.png",
        image_alt: "Interactive, without staying connected: an inbox in LiveView and in Dstar",
        type: "article",
        published: ~D[2026-10-14]
      },
      messages: Inbox.list(),
      unread: Inbox.unread_count(),
      lab: Server.get()
    )
  end

  @impl Dstar.Page
  def stream_key(_conn), do: {:dstar_demo, :home}

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
          lv_files: HomeCode.files(:lv),
          ds_files: HomeCode.files(:ds),
          lv_pr: HomeCode.pr(:lv),
          ds_pr: HomeCode.pr(:ds),
          bench: bench_memory(),
          snippet: DstarDemoWeb.Snippets.fetch!(:home)
        )
      )

    ~H"""
    <.article_shell signals={%{stage: 1, dxFiles: "lv", dxLane: "ds", dxPr: "lv", dxView: "diagram"}}>
      <.lede
        eyebrow="An inbox grows up"
        title="Interactive, without staying connected"
        byline="Rico Trevisan · October 2026"
      >
        <:dek>
          <a href="https://hexdocs.pm/dstar">Dstar</a>
          renders Phoenix pages over <a href="https://data-star.dev">Datastar</a>: the browser
          sends signals, the server answers with HTML patches over SSE, and there's no
          client-side app.
        </:dek>
        <p>
          Phoenix gives every page a choice. A controller renders HTML and forgets the tab. It's
          cheap and simple, but every click reloads the page. A LiveView makes the page
          interactive, and to do that it keeps a socket and a process open for as long as the
          tab is.
        </p>
        <p>
          Dstar is a third option. A click is an ordinary request: it goes through your router,
          runs a handler, and comes back as HTML patches for whatever changed, wherever it is on
          the page. Nothing stays open between clicks. When a page needs to hear about changes
          it didn't make, you add one attribute, and it opens a stream.
        </p>
        <p>
          To see what that's worth, this post builds the same inbox both ways, with LiveView
          written the way Phoenix 1.8 recommends, and follows the arrows as it grows: a login, a
          badge in the layout, other tabs, a second page, a deploy. Both can build it. The question is what
          staying connected costs along the way, and whether you pay it on every page or only
          where you need it.
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

        <div class="mt-10 grid grid-cols-[minmax(0,1fr)] gap-8 lg:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)]">
          <div class="order-2 lg:order-1">
            <.step n={1} title="A page with buttons" signal="stage" id_prefix="dx-stage">
              <p>
                <strong>LiveView:</strong>
                <code>live "/inbox", InboxLive</code>. The GET renders through your router. Then
                the browser opens a WebSocket, and an <code>InboxLive</code>
                process mounts again and serves the tab for as long as it's open. Clicks ride that
                socket. The connection is what makes the page interactive, and everything below
                builds on it.
              </p>
              <p>
                <strong>Dstar:</strong>
                <code>dstar "/inbox", InboxPage</code>. The GET renders through your router, and
                so does every click, as a POST to <code>/inbox/_event/…</code>
                that answers with HTML patches. Between clicks, nothing is open and nothing is
                held. The page is interactive, and it isn't connected.
              </p>
              <:extra><.inline_code n={1} /></:extra>
            </.step>
            <.step n={2} title="Your plugs, twice" signal="stage" id_prefix="dx-stage">
              <p>
                <strong>LiveView:</strong>
                <code>phx.gen.auth</code>
                writes the login check twice: <code>pipe_through :require_authenticated_user</code>
                for the HTTP render, and an <code>on_mount</code>
                hook on the <code>live_session</code>
                for the socket, which never runs the router pipeline. That's the documented
                pattern, and it's sound. It's also what pays for cheap navigation, as stage 5
                shows: the socket is a second way in on purpose.
              </p>
              <p>
                Then you add a plug of your own, say the reader's language from <code>Accept-Language</code>. It sets the Gettext locale for the HTTP render. But the LiveView is
                a new process, Gettext keeps the locale per process, and the socket can't read that
                header at all. So the plug also hands its answer over in the session, and an
                <code>on_mount</code>
                sets it again. Every plug that feeds the page gets that second half. Forget it and
                nothing fails: the page renders in the reader's language, then switches to the
                default as soon as the socket connects.
              </p>
              <p>
                Good teams keep each rule in one module that the plug and the hook both call, so
                the logic is written once. What's left is two places to wire every new plug, and
                remembering that the second one exists.
              </p>
              <p>
                <strong>Dstar:</strong>
                the same plug, once. The GET, every click and every stream are requests through
                it, each in its own process, so the locale holds for whatever that request
                renders.
              </p>
              <p>
                <strong>Both:</strong>
                any client can send any event, so "is this my message?" gets checked on every
                event either way. In Dstar that check can live in <code>authorize/2</code>; in
                LiveView it lives in <code>handle_event/3</code>. That part is parity.
              </p>
              <:extra><.inline_code n={2} /></:extra>
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
              <:extra><.inline_code n={3} /></:extra>
            </.step>
            <.step n={4} title="Other tabs want to know" signal="stage" id_prefix="dx-stage">
              <p>Open the inbox in two tabs. Mark one read. The other should follow.</p>
              <p>
                <strong>LiveView:</strong>
                nothing new to open. The socket was already there, and the hook subscribed to
                PubSub when it connected. <code>handle_info/2</code>
                updates the rows.
              </p>
              <p>
                <strong>Dstar:</strong>
                this is the first time the inbox needs a connection, and it's one attribute: <code>data-init={"{connect()}"}</code>. That POST goes through the same plugs,
                <code>handle_connect/2</code>
                subscribes, and <code>handle_info/2</code>
                patches the rows and the badge. The handlers you already wrote don't change.
              </p>
              <p>
                From here it's parity, and so is the bill. A held-open stream costs about what a
                socket does: {@bench.ds} KB per tab against LiveView's {@bench.lv} KB in <.inline_link href={
                  ~p"/explained/lab#benchmark"
                }>the benchmark</.inline_link>. The difference is that you opened it here, for this page, because it needed one.
              </p>
              <:extra><.inline_code n={4} /></:extra>
            </.step>
            <.step n={5} title="A second page" signal="stage" id_prefix="dx-stage">
              <p>Real apps are many pages. Click a message to open it.</p>
              <p>
                <strong>LiveView:</strong>
                <code>{"<.link navigate={…}>"}</code>. Inside the <code>live_session</code>,
                navigation stays on the open socket: no HTTP request, no plug pipeline, no layout
                to download. <code>MessageLive</code>
                mounts in a new process, and the <code>on_mount</code>
                hooks run (auth, the locale, the badge). This is what the second way in from stage
                2 buys, and it's a real win: moving around the app skips the pipeline.
              </p>
              <p>
                <strong>Dstar:</strong>
                a plain <code>{"<a href={…}>"}</code>. The browser does a full GET: the router,
                every plug, <code>mount/2</code>
                and the whole page, layout included. Assets come from the cache, and
                cross-document View Transitions can make the swap smooth, but the server does the
                full render on every hop. If the old page had a stream, it closes, and the new page
                opens its own only if it needs one.
              </p>
              <p>
                We haven't benchmarked navigation yet, so there's no number here. Per hop,
                LiveView does less work.
              </p>
              <:extra><.inline_code n={5} /></:extra>
            </.step>
            <.step n={6} title="Then you deploy" signal="stage" id_prefix="dx-stage">
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
                doesn't run. And a click was never connected in the first place: one that lands
                mid-deploy is just a request, and Datastar retries it until a server answers.
              </p>
              <.deploy_demo lab={@lab} />
              <:extra><.inline_code n={6} /></:extra>
            </.step>
          </div>

          <div class="sticky top-0 z-10 order-1 self-start lg:static lg:order-2 lg:self-stretch">
            <div class="-mx-5 border-b border-base-300 bg-base-100/95 px-5 py-3 backdrop-blur sm:-mx-8 sm:px-8 lg:sticky lg:top-[10vh] lg:mx-0 lg:border lg:bg-base-100 lg:p-5">
              <.arrows stages={@stages} bench={@bench} code_view />
            </div>
          </div>
        </div>
      </section>

      <section id="code" class="mx-auto mt-24 max-w-[860px]">
        <div class="max-w-[68ch]">
          <.section_heading>The finished inbox, as code</.section_heading>
          <.para>
            All six stages stacked: login, the locale plug, a layout badge, live tabs and a
            second page, written both ways. These are illustrative excerpts on top of <code>phx.gen.auth</code>, which generates the same
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

      <section id="process" class="mx-auto mt-24 max-w-[860px]">
        <div class="max-w-[68ch]">
          <.section_heading>What the process buys</.section_heading>
          <.para>
            The diagram counts LiveView's process as a cost, and it is one: memory and a socket
            for every open tab. But it also pays for several of the arrows, and some of them
            Dstar doesn't have. Here's what you get for it, and Dstar's answer to each.
          </.para>
        </div>
        <div class="mt-6 overflow-x-auto">
          <table class="w-full min-w-[640px] border border-base-300 text-left text-sm leading-6">
            <thead class="bg-base-200 text-xs">
              <tr>
                <th class="w-[18%] px-4 py-2.5 font-medium text-base-content/70"></th>
                <th class="px-4 py-2.5 font-semibold">
                  <span class="inline-flex items-center gap-2">
                    <.swatch tone="neutral" /> LiveView's process
                  </span>
                </th>
                <th class="px-4 py-2.5 font-semibold">
                  <span class="inline-flex items-center gap-2"><.swatch tone="primary" /> Dstar</span>
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-base-300 align-top">
              <tr
                :for={{row, lv, ds} <- process_rows()}
                id={"process-#{row |> String.downcase() |> String.replace(" ", "-")}"}
              >
                <th class="px-4 py-3 font-medium">{row}</th>
                <td class="px-4 py-3 text-base-content/80"><.rich_text text={lv} /></td>
                <td class="px-4 py-3 text-base-content/80"><.rich_text text={ds} /></td>
              </tr>
            </tbody>
          </table>
        </div>
        <.para>
          Event order is the one to read twice. A Dstar handler can run twice, or alongside
          another one, so it should be safe to repeat: "mark read" is, "add one" isn't. You can
          watch the difference in <.inline_link href={~p"/explained/lab"}>the lab</.inline_link>: press "Ada double-clicks".
        </.para>
      </section>

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
            Which brings back the question from the top. If every page should be live, you're
            paying for the connection anyway, and LiveView's hook makes good use of it. If most
            pages are clicks and a few spots are live, Dstar lets the same module start as
            requests and add a stream where it's needed, and the cost stays there.
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
              "**Users move around a lot.** Navigation inside a live_session stays on the socket: no HTTP render and no plug pipeline per hop.",
              "**Order matters.** One process handles a tab's events one at a time, in order. Dstar's handlers can overlap and must be safe to repeat.",
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
              "**Interactive shouldn't mean connected.** Clicks are requests, so they're retried through a deploy or a flaky network, and nothing has to rejoin."
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

  # {row, LiveView, Dstar} for "What the process buys". Each claim was
  # checked against LiveView 1.1 and the vendored Datastar 1.0.1.
  defp process_rows do
    [
      {"Navigation",
       "**Over the open socket.** Inside a live_session, a new LiveView mounts with no HTTP request and no plug pipeline. Its on_mount hooks still run.",
       "**A full GET.** Router, plugs, mount/2 and the whole page. Assets are cached, and View Transitions can make it smooth, but the server renders every hop."},
      {"Event order",
       "**One at a time, in order.** A tab's events queue in its process, so a double click is two events, handled one after the other.",
       "**No ordering.** Each click is its own request and process. Datastar cancels the previous response from the same element, but the server may already have run it, and retries make delivery at-least-once."},
      {"State between events",
       "**In the process, out of the client's reach.** Assigns hold anything you like, trusted, until the tab closes.",
       "**In the database or the session.** Signals come from the browser, so they're input, not state. A multi-step form needs somewhere to keep its draft."},
      {"Updates",
       "**Diffs.** Only the changed dynamic parts go over the socket. Compression is off unless you set compress: true on the socket.",
       "**HTML patches.** The changed element, whole. Bandit compresses responses and streams by default. We haven't benchmarked compressed bytes yet."},
      {"Form recovery",
       "**Automatic.** After a reconnect, forms with phx-change are replayed into the new process.",
       "**Mostly not needed.** A deploy doesn't reload the page, so inputs stay in the DOM. But nothing on the server knows about a half-filled form."},
      {"Cost",
       "**A process and a socket per open tab,** about the same memory as one Dstar stream.",
       "**Nothing per tab,** until a page opens a stream."}
    ]
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

  # ── The code view ─────────────────────────────────────────────────────

  @lanes [{:lv, "LiveView", "neutral"}, {:ds, "Dstar", "primary"}]

  attr :key, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true

  defp view_button(assigns) do
    ~H"""
    <button
      type="button"
      role="tab"
      data-on:click={"$dxView = '#{@key}'"}
      data-class={"{'!border-primary !text-base-content !bg-base-200': $dxView == '#{@key}'}"}
      data-attr:aria-selected={"$dxView == '#{@key}'"}
      class="inline-flex items-center gap-1.5 rounded-md border border-base-300 px-2.5 py-1 text-xs font-medium text-base-content/65 transition hover:text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
    >
      <.icon name={@icon} class="size-3.5" /> {@label}
    </button>
    """
  end

  attr :stages, :list, required: true

  # lg and up: the sticky panel's code view, one stage and one lane at a time.
  defp stage_code_panel(assigns) do
    assigns = assign(assigns, lanes: @lanes)

    ~H"""
    <div
      id="dx-code-view"
      data-show="$dxView == 'code'"
      style="display: none"
      class="mt-3 max-h-[62vh] overflow-y-auto overscroll-contain"
    >
      <div
        :for={{lane, name, tone} <- @lanes}
        data-show={"$dxLane == '#{lane}'"}
        style={lane != :ds && "display: none"}
      >
        <div
          :for={{n, _title} <- @stages}
          id={"dx-code-#{lane}-#{n}"}
          data-show={"$stage == #{n}"}
          style={n != 1 && "display: none"}
        >
          <.stage_code n={n} lane={lane} name={name} tone={tone} />
        </div>
      </div>
    </div>
    """
  end

  attr :n, :integer, required: true

  # Below lg: the same code under each step, folded away until asked for.
  defp inline_code(assigns) do
    assigns = assign(assigns, lanes: @lanes)

    ~H"""
    <details class="group border border-base-300 lg:hidden">
      <summary class="flex cursor-pointer list-none items-center justify-between gap-2 px-3 py-2 text-sm font-medium [&::-webkit-details-marker]:hidden">
        <span class="flex items-center gap-2">
          <.icon name="hero-code-bracket-micro" class="size-4 opacity-60" /> The code at this step
        </span>
        <.icon
          name="hero-chevron-down-micro"
          class="size-4 transition-transform group-open:rotate-180"
        />
      </summary>
      <div class="space-y-5 border-t border-base-300 p-3">
        <.stage_code :for={{lane, name, tone} <- @lanes} n={@n} lane={lane} name={name} tone={tone} />
      </div>
    </details>
    """
  end

  attr :n, :integer, required: true
  attr :lane, :atom, required: true
  attr :name, :string, required: true
  attr :tone, :string, required: true

  defp stage_code(assigns) do
    files = HomeCode.stage(assigns.n, assigns.lane)
    so_far = Enum.sum(for n <- 1..assigns.n, do: HomeCode.added_lines(n, assigns.lane))

    assigns =
      assign(assigns,
        files: files,
        added: HomeCode.added_lines(assigns.n, assigns.lane),
        so_far: so_far
      )

    ~H"""
    <div class="space-y-3">
      <p class="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1 text-sm">
        <span class="flex items-center gap-2 font-semibold"><.swatch tone={@tone} /> {@name}</span>
        <span class="font-mono text-[11px] text-base-content/65">
          <%= if @files == [] do %>
            no code changes · {@so_far} lines so far
          <% else %>
            +{@added} lines in {length(@files)} {if(length(@files) == 1, do: "file", else: "files")} · {@so_far} so far
          <% end %>
        </span>
      </p>
      <p :if={@files == []} class="text-sm leading-6 text-base-content/70">
        A deploy needs no code in either model. What differs is what runs when it happens: press
        Deploy and watch the counters.
      </p>
      <.diff_file :for={{file, lines} <- @files} file={file} lines={lines} />
    </div>
    """
  end

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
  attr :code_view, :boolean, default: false

  @doc false
  def arrows(assigns) do
    ~H"""
    <div id="dx-diagram">
      <div class="flex items-center justify-between gap-3">
        <p class="text-sm font-semibold">
          <span
            class="font-mono text-xs text-base-content/60"
            data-text={"'Stage ' + $stage + ' / #{length(@stages)}'"}
          >
            Stage 1 / {length(@stages)}
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

      <%!-- The code view lives in this panel from lg up. Below lg the panel is
      already at its height limit, so each step shows its code inline instead. --%>
      <div :if={@code_view} class="mt-3 hidden gap-1 lg:flex" role="tablist" aria-label="View">
        <.view_button key="diagram" label="Diagram" icon="hero-share-micro" />
        <.view_button key="code" label="Code" icon="hero-code-bracket-micro" />
      </div>

      <%!-- Both panels stacked are taller than a phone screen, which breaks the
      sticky diagram. Below lg, show one model at a time; the code view uses
      the same tabs at every width. --%>
      <div
        class="mt-3 flex border-b border-base-300 lg:hidden"
        data-class="{'lg:!flex': $dxView == 'code'}"
        role="tablist"
        aria-label="Model"
      >
        <.tab_button signal="dxLane" key="lv" label="LiveView" />
        <.tab_button signal="dxLane" key="ds" label="Dstar" />
      </div>

      <.stage_code_panel :if={@code_view} stages={@stages} />

      <div data-show="$dxView != 'code'">
        <%!-- Both lanes use the same three counters. Processes and memory per
      open tab are the benchmark's measured medians. --%>
        <.panel name="LiveView" tone="neutral" lane="lv">
          <:tally>
            <.tally id="lv-auth" label="ways in" expr="2" initial="2" />
            <.tally id="lv-procs" label="processes per tab" expr="2" initial="2" />
            <.tally id="lv-nav" label="navigation" expr="'over the socket'" initial="over the socket" />
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
            <.box
              x={118}
              y={16}
              w={92}
              label="router plugs"
              sub="HTTP only"
              sub_expr="$stage == 5 ? 'skipped' : 'HTTP only'"
              hot="$stage == 2"
            />
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
                sub="plugs, again"
                sub_expr="$stage >= 3 ? 'plugs + @unread' : 'plugs, again'"
                hot="$stage == 2 || $stage == 3 || $stage == 5"
              />
              <path
                d="M72 104 L 118 134"
                class="dx-wire dx-wire-hot"
                data-class="{'dx-wire-bad': $stage == 6}"
                marker-end="url(#lv-head)"
              />
              <path
                d="M210 136 L 244 126"
                class="dx-wire dx-wire-hot"
                data-class="{'dx-wire-bad': $stage == 6}"
                marker-end="url(#lv-head)"
              />
              <text x="64" y="150" class="dx-sub" data-show="$stage == 6" style="display: none">
                rejoin!
              </text>
              <text x="60" y="150" class="dx-sub" data-show="$stage == 5" style="display: none">
                navigate
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
              label_expr="$stage == 5 ? 'MessageLive' : 'InboxLive'"
              sub="mount/3 ×2"
              sub_expr="$stage == 6 ? 'mount/3 again' : $stage == 5 ? 'mount/3, socket' : 'mount/3 ×2'"
              hot="$stage == 1 || $stage == 5 || $stage == 6"
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
            <.tally id="ds-auth" label="ways in" expr="1" initial="1" />
            <.tally
              id="ds-procs"
              label="processes per tab"
              expr="$stage == 4 || $stage == 6 ? 1 : 0"
              initial="0"
            />
            <.tally id="ds-nav" label="navigation" expr="'full GET'" initial="full GET" />
            <.tally
              id="ds-memory"
              label="memory per tab"
              expr={"$stage == 4 || $stage == 6 ? '#{@bench.ds} KB' : '≈ 0 KB'"}
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
              hot="$stage == 2 || $stage == 5 || $stage == 6"
            />
            <path d="M80 92 L 130 94" class="dx-wire" marker-end="url(#ds-head)" />
            <text x="86" y="84" class="dx-sub" data-text="$stage == 5 ? 'GET' : 'POST'">POST</text>
            <path d="M244 94 L 262 72" class="dx-wire" marker-end="url(#ds-head)" />
            <.box
              x={262}
              y={50}
              w={90}
              label="InboxPage"
              label_expr="$stage == 5 ? 'MessagePage' : 'InboxPage'"
              sub="handle_event/3"
              sub_expr="$stage == 5 ? 'mount/2, GET' : 'handle_event/3'"
              hot="$stage == 3 || $stage == 5"
            />

            <%!-- every click is answered with patches; the badge joins at stage 3 --%>
            <path
              d="M262 64 C 200 20, 120 30, 74 112"
              class="dx-wire dx-wire-hot"
              data-attr:d="$stage >= 3 ? 'M262 64 C 200 20, 120 30, 74 88' : 'M262 64 C 200 20, 120 30, 74 112'"
              marker-end="url(#ds-head)"
            />
            <text
              x="140"
              y="34"
              class="dx-sub"
              data-text="$stage == 5 ? 'HTML: the whole page' : $stage >= 3 ? 'SSE: #list + #sidebar' : 'SSE: #list'"
            >
              SSE: #list
            </text>

            <g data-show="$stage >= 4" style="display: none" class="dx-enter">
              <path
                d="M80 130 C 120 150, 150 140, 176 112"
                class="dx-wire dx-wire-hot"
                data-class="{'dx-wire-bad': $stage == 5 || $stage == 6}"
                marker-end="url(#ds-head)"
              />
              <text
                x="88"
                y="158"
                class="dx-sub"
                data-text="$stage == 6 ? 'connect() again' : $stage == 5 ? 'closes with the page' : 'connect() stream'"
              >
                connect() stream
              </text>
              <%!-- the message page opens no stream of its own --%>
              <g data-show="$stage != 5">
                <rect x="254" y="142" width="104" height="50" class="dx-proc" />
                <text x="258" y="204" class="dx-sub">1 process / tab</text>
                <.box
                  x={262}
                  y={150}
                  w={88}
                  label="the stream"
                  sub="handle_info/2"
                  hot="$stage == 4 || $stage == 6"
                />
                <path d="M306 150 L 306 100" class="dx-wire dx-wire-hot" marker-end="url(#ds-head)" />
              </g>
            </g>
          </svg>
        </.panel>

        <p class="mt-3 text-[11px] leading-4 text-base-content/60 max-lg:hidden">
          Processes and memory per open tab: measured medians from the benchmark, {@bench.tabs} tabs. A Dstar page without a stream holds neither, like the message page at stage 5. Navigation isn't benchmarked yet.
        </p>
      </div>
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
  attr :label_expr, :string, default: nil, doc: "Datastar expression that replaces `label`"
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
      <text x={@x + 7} y={@y + 15} class="dx-text" data-text={@label_expr}>{@label}</text>
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
