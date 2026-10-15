defmodule DstarDemoWeb.HomeCode do
  @moduledoc """
  The illustrative code on the home page, kept out of the page module.

    * `files/1` — the finished inbox in each model, file by file.
    * `stage/2` — what each scroll stage adds, as a diff per file. Stacked,
      the stages build `files/1`; `DstarDemoWeb.HomeCodeTest` checks that
      every added line really is in the finished file, so the two can't drift.
    * `pr/1` — the "a year later" pull request in each model.

  Files that are the same in both apps aren't shown or counted:
  `phx.gen.auth`'s `user_auth.ex` and the `Inbox` context.
  """

  # ── The finished inbox ────────────────────────────────────────────────

  @lv_files [
    {"router.ex",
     ~S'''
     pipeline :browser do
       # ...
       plug MyAppWeb.Locale
     end

     scope "/", MyAppWeb do
       pipe_through [:browser, :require_authenticated_user]

       live_session :require_authenticated_user,
         on_mount: [
           {MyAppWeb.UserAuth, :require_authenticated},
           MyAppWeb.Locale,
           MyAppWeb.Unread
         ] do
         live "/inbox", InboxLive
         # ...every page with the sidebar lives in this live_session
       end
     end
     '''},
    {"locale.ex",
     ~S'''
     defmodule MyAppWeb.Locale do
       @moduledoc "Picks the reader's language: once for HTTP, again for the socket."
       import Plug.Conn

       def init(opts), do: opts

       def call(conn, _opts) do
         locale = locale_from(get_req_header(conn, "accept-language"))
         Gettext.put_locale(MyAppWeb.Gettext, locale)
         # The socket can't read this header, so hand the answer over in the session.
         put_session(conn, :locale, locale)
       end

       # The LiveView process is a new process: set the locale again in it.
       def on_mount(:default, _params, session, socket) do
         Gettext.put_locale(MyAppWeb.Gettext, session["locale"] || "en")
         {:cont, socket}
       end

       defp locale_from(header), do: MyApp.Locales.best_match(header)
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
     pipeline :browser do
       # ...
       plug MyAppWeb.Locale
     end

     pipeline :unread do
       plug MyAppWeb.Unread
     end

     scope "/", MyAppWeb do
       pipe_through [:browser, :require_authenticated_user, :unread]

       dstar "/inbox", InboxPage
     end
     '''},
    {"locale.ex",
     ~S'''
     defmodule MyAppWeb.Locale do
       @moduledoc "Picks the reader's language. Runs on every request: the page, each click, each stream."
       import Plug.Conn

       def init(opts), do: opts

       def call(conn, _opts) do
         locale = locale_from(get_req_header(conn, "accept-language"))
         Gettext.put_locale(MyAppWeb.Gettext, locale)
         conn
       end

       defp locale_from(header), do: MyApp.Locales.best_match(header)
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

  # ── Stage by stage ────────────────────────────────────────────────────
  # {stage, lane} => [{file, diff}]. An empty list means no code changes.

  @stages %{
    {1, :lv} => [
      {"router.ex",
       ~S'''
       +live "/inbox", InboxLive
       '''},
      {"inbox_live.ex",
       ~S'''
       +def mount(_params, _session, socket) do
       +  {:ok, stream(socket, :messages, Inbox.list(socket.assigns.current_scope))}
       +end
       +
       +def handle_event("read", %{"id" => id}, socket) do
       +  message = Inbox.mark_read!(socket.assigns.current_scope, id)
       +  {:noreply, stream_insert(socket, :messages, message)}
       +end
       '''}
    ],
    {1, :ds} => [
      {"router.ex",
       ~S'''
       +dstar "/inbox", InboxPage
       '''},
      {"inbox_page.ex",
       ~S'''
       +def mount(conn, _params) do
       +  assign(conn, :messages, Inbox.list(conn.assigns.current_scope))
       +end
       +
       +def handle_event(conn, "read:" <> id, _signals) do
       +  message = Inbox.mark_read!(conn.assigns.current_scope, id)
       +
       +  conn
       +  |> patch(&message_row/1, message: message)
       '''}
    ],
    {2, :lv} => [
      {"router.ex",
       ~S'''
        pipeline :browser do
          # ...
       +  plug MyAppWeb.Locale
        end

       +scope "/", MyAppWeb do
       +  pipe_through [:browser, :require_authenticated_user]
       +
       +  live_session :require_authenticated_user,
       +    on_mount: [
       +      {MyAppWeb.UserAuth, :require_authenticated},
       +      MyAppWeb.Locale
       +    ] do
            live "/inbox", InboxLive
       +  end
       +end
       '''},
      {"locale.ex",
       ~S'''
       +def call(conn, _opts) do
       +  locale = locale_from(get_req_header(conn, "accept-language"))
       +  Gettext.put_locale(MyAppWeb.Gettext, locale)
       +  # The socket can't read this header, so hand the answer over in the session.
       +  put_session(conn, :locale, locale)
       +end
       +
       +# The LiveView process is a new process: set the locale again in it.
       +def on_mount(:default, _params, session, socket) do
       +  Gettext.put_locale(MyAppWeb.Gettext, session["locale"] || "en")
       +  {:cont, socket}
       +end
       '''}
    ],
    {2, :ds} => [
      {"router.ex",
       ~S'''
        pipeline :browser do
          # ...
       +  plug MyAppWeb.Locale
        end

       +scope "/", MyAppWeb do
       +  pipe_through [:browser, :require_authenticated_user]
            dstar "/inbox", InboxPage
       +end
       '''},
      {"locale.ex",
       ~S'''
       +def call(conn, _opts) do
       +  locale = locale_from(get_req_header(conn, "accept-language"))
       +  Gettext.put_locale(MyAppWeb.Gettext, locale)
       +  conn
       +end
       '''}
    ],
    {3, :lv} => [
      {"router.ex",
       ~S'''
       -      MyAppWeb.Locale
       +      MyAppWeb.Locale,
       +      MyAppWeb.Unread
            ] do
       '''},
      {"unread.ex",
       ~S'''
       +def on_mount(:default, _params, _session, socket) do
       +  scope = socket.assigns.current_scope
       +  if connected?(socket), do: Inbox.subscribe(scope)
       +
       +  {:cont,
       +   socket
       +   |> assign(:unread, Inbox.unread_count(scope))
       +   |> attach_hook(:unread, :handle_info, &handle_info/2)}
       +end
       +
       +defp handle_info({:inbox_changed, _message}, socket) do
       +  {:cont, assign(socket, :unread, Inbox.unread_count(socket.assigns.current_scope))}
       +end
       +
       +defp handle_info(_message, socket), do: {:cont, socket}
       '''},
      {"layouts.ex",
       ~S'''
       +attr :unread, :integer, default: 0

        def app(assigns) do
          ~H"""
       +  <aside>
       +    <.link navigate={~p"/inbox"}>Inbox <span>{@unread}</span></.link>
       +  </aside>
          <main>{render_slot(@inner_block)}</main>
       '''},
      {"inbox_live.ex",
       ~S'''
       -<Layouts.app flash={@flash} current_scope={@current_scope}>
       +<Layouts.app flash={@flash} current_scope={@current_scope} unread={@unread}>
       '''}
    ],
    {3, :ds} => [
      {"router.ex",
       ~S'''
       +pipeline :unread do
       +  plug MyAppWeb.Unread
       +end
       +
        scope "/", MyAppWeb do
       -  pipe_through [:browser, :require_authenticated_user]
       +  pipe_through [:browser, :require_authenticated_user, :unread]
       '''},
      {"unread.ex",
       ~S'''
       +def call(conn, _opts) do
       +  assign(conn, :unread, Inbox.unread_count(conn.assigns.current_scope))
       +end
       '''},
      {"layouts.ex",
       ~S'''
       +attr :unread, :integer, default: 0

        def app(assigns) do
          ~H"""
       +  <aside><.unread_badge unread={@unread} /></aside>
          <main>{render_slot(@inner_block)}</main>
       '''},
      {"inbox_page.ex",
       ~S'''
       -<Layouts.app flash={@flash} current_scope={@current_scope}>
       +<Layouts.app flash={@flash} current_scope={@current_scope} unread={@unread}>
        # ...
          conn
          |> patch(&message_row/1, message: message)
       +  |> patch_unread()
        end
       +
       +defp patch_unread(conn) do
       +  patch(conn, &Layouts.unread_badge/1, unread: Inbox.unread_count(conn.assigns.current_scope))
       +end
       '''}
    ],
    {4, :lv} => [
      {"inbox_live.ex",
       ~S'''
       +def handle_info({:inbox_changed, message}, socket) do
       +  {:noreply, stream_insert(socket, :messages, message)}
       +end
       '''}
    ],
    {4, :ds} => [
      {"inbox_page.ex",
       ~S'''
       -<ul id="messages">
       +<ul id="messages" data-init={connect()}>
        # ...
       +def handle_connect(conn, _params) do
       +  Inbox.subscribe(conn.assigns.current_scope)
       +  conn
       +end
       +
       +def handle_info({:inbox_changed, message}, conn) do
       +  conn
       +  |> patch(&message_row/1, message: message)
       +  |> patch_unread()
       +end
       '''}
    ],
    {5, :lv} => [],
    {5, :ds} => []
  }

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

  def files(:lv), do: @lv_files
  def files(:ds), do: @ds_files

  @doc "The diff a stage adds to one lane: `[{file, diff}]`, empty when nothing changes."
  def stage(n, lane), do: Map.fetch!(@stages, {n, lane})

  @doc "Lines added by a stage in one lane, blank lines excluded."
  def added_lines(n, lane) do
    for {_file, diff} <- stage(n, lane),
        "+" <> line <- String.split(diff, "\n"),
        String.trim(line) != "",
        reduce: 0 do
      acc -> acc + 1
    end
  end

  def pr(:lv), do: @lv_pr
  def pr(:ds), do: @ds_pr
end
