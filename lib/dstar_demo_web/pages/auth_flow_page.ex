defmodule DstarDemoWeb.AuthFlowPage do
  use DstarDemoWeb, :dstar_page

  @pipeline_code ~S"""
  # router.ex
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_current_scope
    plug Dstar.Plugs.RenameCsrfParam
    plug :protect_from_forgery
  end

  pipeline :require_authenticated_user do
    plug :require_authenticated_user
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :require_authenticated_user]

    dstar "/settings", SettingsPage
    dstar_components "/ds", [SettingsForm]
  end
  """

  @authorization_code ~S"""
  # settings_page.ex — resource authorization, not a second login flow
  @impl Dstar.Page
  def authorize(conn, {:event, "save:" <> account_id}) do
    case Accounts.fetch_for_scope(conn.assigns.current_scope, account_id) do
      {:ok, account} -> assign(conn, :account, account)

      :error ->
        conn
        |> send_resp(403, "Forbidden")
        |> halt()
    end
  end

  def authorize(conn, {:event, _event}), do: conn
  def authorize(conn, {:stream, _params}), do: conn
  """

  @liveview_code ~S"""
  # Illustrative generated-style LiveView routing.
  scope "/", MyAppWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{MyAppWeb.UserAuth, :require_authenticated}] do
      live "/settings", SettingsLive, :edit
    end
  end
  """

  @impl Dstar.Page
  def render(assigns) do
    assigns =
      Map.merge(assigns, %{
        pipeline_code: @pipeline_code,
        authorization_code: @authorization_code,
        liveview_code: @liveview_code
      })

    ~H"""
    <.demo_shell
      active="Auth Flow"
      title="One authentication flow"
      summary="Dstar events and streams are ordinary HTTP requests. Put the page routes and component dispatcher behind one Phoenix authentication pipeline, and that same gate protects the initial render and every later interaction."
    >
      <:demo>
        <section id="auth-flow" class="border border-base-300 bg-base-200 p-5 sm:p-6">
          <div class="grid gap-3 lg:grid-cols-[1fr_auto_1.15fr_auto_1fr] lg:items-stretch">
            <div id="auth-browser" class="border border-base-300 bg-base-100 p-4">
              <div class="flex items-center gap-2">
                <.icon name="hero-window-micro" class="size-5 text-primary" />
                <h2 class="text-sm font-semibold">Browser</h2>
              </div>
              <p class="mt-3 text-sm leading-6 text-base-content/70">
                Sends the signed session cookie with each request; Datastar actions also carry the
                CSRF signal.
              </p>
            </div>

            <div class="hidden items-center text-base-content/35 lg:flex" aria-hidden="true">
              <.icon name="hero-arrow-right-micro" class="size-5" />
            </div>

            <div id="auth-pipeline" class="border-2 border-primary bg-base-100 p-4">
              <div class="flex items-center justify-between gap-3">
                <div class="flex items-center gap-2">
                  <.icon name="hero-shield-check-micro" class="size-5 text-primary" />
                  <h2 class="text-sm font-semibold">One Phoenix pipeline</h2>
                </div>
                <.pill label="auth gate" tone="good" />
              </div>
              <p class="mt-3 text-sm leading-6 text-base-content/70">
                Fetch the session, load the current scope, require a user, and reject before dispatch.
              </p>
            </div>

            <div class="hidden items-center text-base-content/35 lg:flex" aria-hidden="true">
              <.icon name="hero-arrow-right-micro" class="size-5" />
            </div>

            <div id="auth-handler" class="border border-base-300 bg-base-100 p-4">
              <div class="flex items-center gap-2">
                <.icon name="hero-bolt-micro" class="size-5 text-primary" />
                <h2 class="text-sm font-semibold">Dstar.Page</h2>
              </div>
              <p class="mt-3 text-sm leading-6 text-base-content/70">
                Only authenticated conns reach mount, event, stream, or component callbacks.
              </p>
            </div>
          </div>

          <div id="auth-route-table" class="mt-5 overflow-x-auto border border-base-300 bg-base-100">
            <table class="w-full min-w-[660px] text-left text-sm">
              <thead class="border-b border-base-300 bg-base-200 text-xs tracking-wide text-base-content/60 uppercase">
                <tr>
                  <th class="px-4 py-3 font-medium">Request</th>
                  <th class="px-4 py-3 font-medium">Purpose</th>
                  <th class="px-4 py-3 font-medium">After the same gate</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-base-300">
                <.flow_row
                  request="GET /settings"
                  purpose="Initial HTML"
                  destination="mount/2 → render/1"
                />
                <.flow_row
                  request="POST /settings/_event/:event"
                  purpose="Browser event"
                  destination="authorize/2 → handle_event/3"
                />
                <.flow_row
                  request="POST /settings"
                  purpose="Long-lived stream"
                  destination="authorize/2 → handle_connect/2"
                />
                <.flow_row
                  request="POST /ds/:module/:event"
                  purpose="Shared component event"
                  destination="component handle_event/3"
                />
              </tbody>
            </table>
          </div>
        </section>
      </:demo>

      <:how_it_works>
        <.key_points items={[
          "Every Dstar request crosses the same Phoenix authentication pipeline.",
          "The signed session cookie is already available because every interaction is HTTP.",
          "mount/2 runs only on GET; it is not protection for direct event or stream POSTs.",
          "authorize/2 handles page- or resource-specific checks before SSE starts.",
          "CSRF protection is separate from authentication and still belongs in the browser pipeline."
        ]} />

        <.prose>
          A <code class="font-mono text-sm">dstar "/settings", SettingsPage</code>
          line expands to three routes: a GET, an event POST, and a stream POST. Phoenix runs every
          one through the surrounding pipelines. The browser sends the same signed session cookie,
          so your existing <code class="font-mono text-sm">fetch_current_scope</code>
          and <code class="font-mono text-sm">require_authenticated_user</code>
          plugs are the only authentication path you need. Put
          <code class="font-mono text-sm">dstar_components/2</code>
          in that scope too when its handlers require a user.
        </.prose>

        <div class="mt-6">
          <.code_block language="elixir" label="illustrative router.ex" code={@pipeline_code} />
        </div>

        <h3 class="mt-8 text-base font-semibold tracking-tight">
          Authentication is not authorization
        </h3>
        <.prose class="mt-3">
          The pipeline answers “who is this?” once, consistently. A record-level rule still has to
          answer “may this user change this account?” Use
          <code class="font-mono text-sm">authorize/2</code>
          for page event and stream POSTs. It runs after signals are parsed but before the response
          becomes SSE, so it can still return a normal 401 or 403. On GET, load only an authorized
          resource in <code class="font-mono text-sm">mount/2</code>. Component handlers must do
          their resource check before calling <code class="font-mono text-sm">start/1</code>.
        </.prose>

        <div class="mt-6">
          <.code_block
            language="elixir"
            label="illustrative settings_page.ex"
            code={@authorization_code}
          />
        </div>

        <aside class="mt-6 max-w-[68ch] border-l-2 border-warning/60 pl-4 text-sm leading-6 text-base-content/80">
          A long-lived stream is authenticated when it connects. If access can be revoked while it
          is open, close or replace that stream when authorization changes; no framework can make an
          already-open response re-enter a Plug pipeline by itself.
        </aside>
      </:how_it_works>

      <:comparison>
        <.prose>
          LiveView uses the same session token, but it has two request lifecycles to guard. The Plug
          protects the initial HTTP request; an <code class="font-mono text-sm">on_mount</code>
          hook protects the connected LiveView process. Dstar has no authenticated socket process,
          so every request simply re-enters the Plug pipeline.
        </.prose>

        <.compare>
          <:dstar>
            <.code_block language="elixir" label="illustrative router.ex" code={@pipeline_code} />
          </:dstar>
          <:liveview>
            <.code_block language="elixir" label="illustrative" code={@liveview_code} />
          </:liveview>
          <:note>
            “One flow” means one authentication enforcement path, not fewer authorization rules.
            Dstar re-runs that path per interaction; LiveView authenticates the connected process and
            then keeps it resident. The right tradeoff depends on whether request-by-request identity
            checks or a stateful server process better fits the feature.
          </:note>
        </.compare>
      </:comparison>
    </.demo_shell>
    """
  end

  attr :request, :string, required: true
  attr :purpose, :string, required: true
  attr :destination, :string, required: true

  def flow_row(assigns) do
    ~H"""
    <tr>
      <td class="px-4 py-3 font-mono text-xs text-base-content">{@request}</td>
      <td class="px-4 py-3 text-base-content/70">{@purpose}</td>
      <td class="px-4 py-3 font-mono text-xs text-base-content/70">{@destination}</td>
    </tr>
    """
  end
end
