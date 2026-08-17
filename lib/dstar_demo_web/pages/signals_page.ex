defmodule DstarDemoWeb.SignalsPage do
  use DstarDemoWeb, :dstar_page

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn,
      scope: "release",
      filter: "open",
      ephemeral: "client-note",
      server_tick: 0,
      audit_trail: "mounted",
      last_read: %{}
    )
  end

  @impl Dstar.Page
  def render(assigns) do
    assigns = Map.put(assigns, :snippet, DstarDemoWeb.Snippets.fetch!(:signals))

    ~H"""
    <.demo_shell
      active="Signals"
      title="Signal-native UI"
      summary="Edit reactive client state with no request, then choose when the server should read it, reconcile it, patch owned values, or remove a signal."
      signals={
        %{
          scope: @scope,
          filter: @filter,
          ephemeral: @ephemeral,
          server_tick: @server_tick,
          audit_trail: @audit_trail,
          last_read: @last_read
        }
      }
    >
      <:demo>
        <section class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_340px]">
          <div class="border border-base-300 bg-base-200 p-5">
            <div class="grid gap-4 md:grid-cols-3">
              <label class="block">
                <span class="mb-2 block text-sm font-medium text-base-content/80">Scope</span>
                <input
                  id="signals-scope"
                  data-bind:scope
                  value={@scope}
                  class="w-full rounded-md border border-base-300 bg-base-100 px-3 py-2.5 text-base-content transition focus:border-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                />
              </label>
              <label class="block">
                <span class="mb-2 block text-sm font-medium text-base-content/80">Filter</span>
                <input
                  id="signals-filter"
                  data-bind:filter
                  value={@filter}
                  class="w-full rounded-md border border-base-300 bg-base-100 px-3 py-2.5 text-base-content transition focus:border-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                />
              </label>
              <label class="block">
                <span class="mb-2 block text-sm font-medium text-base-content/80">Ephemeral</span>
                <input
                  id="signals-ephemeral"
                  data-bind:ephemeral
                  value={@ephemeral}
                  class="w-full rounded-md border border-base-300 bg-base-100 px-3 py-2.5 text-base-content transition focus:border-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                />
              </label>
            </div>

            <div
              id="signals-local-preview"
              class="mt-5 border border-primary/35 bg-primary/10 p-4"
            >
              <div class="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <p class="text-sm font-semibold text-base-content">Instant local projection</p>
                  <p class="mt-1 text-xs text-base-content/60">
                    These bindings update in the browser. No HTTP request has happened yet.
                  </p>
                </div>
                <.pill label="client only" tone="good" />
              </div>
              <p
                class="mt-4 font-mono text-sm font-semibold text-base-content"
                data-text="$scope + ' · ' + $filter"
              >
                {@scope} · {@filter}
              </p>
              <p
                class="mt-2 text-sm text-base-content/70"
                data-show="$ephemeral"
                data-text="'Draft: ' + $ephemeral"
              >
                Draft: {@ephemeral}
              </p>
              <p class="mt-2 text-sm text-base-content/50" data-show="!$ephemeral">
                The ephemeral signal is absent. Patch or reload to restore client state.
              </p>
            </div>

            <div class="mt-5 flex flex-wrap gap-2">
              <.action_button
                id="signals-read"
                label="Read"
                icon="hero-eye-micro"
                click={event("read")}
                active
              />
              <.action_button
                id="signals-patch"
                label="Patch signals"
                icon="hero-arrow-up-tray-micro"
                click={event("patch")}
              />
              <.action_button
                id="signals-remove"
                label="Remove"
                icon="hero-trash-micro"
                click={event("remove")}
              />
            </div>

            <.inspector
              scope={@scope}
              filter={@filter}
              ephemeral={@ephemeral}
              server_tick={@server_tick}
              audit_trail={@audit_trail}
              last_read={@last_read}
            />
          </div>

          <aside class="border border-base-300 bg-base-100 p-4">
            <p class="font-mono text-xs tracking-wide text-base-content/65 uppercase">
              Current flow
            </p>
            <ol class="mt-4 space-y-2 text-sm text-base-content/80">
              <li class="bg-base-200 px-3 py-2">
                1. Client sends scope, filter, and ephemeral.
              </li>
              <li class="bg-base-200 px-3 py-2">
                2. Dstar.Page.Plug reads the signals and starts SSE.
              </li>
              <li class="bg-base-200 px-3 py-2">3. Server patches or removes signals.</li>
              <li class="bg-base-200 px-3 py-2">4. The inspector HTML is patched.</li>
            </ol>
          </aside>
        </section>
      </:demo>

      <:how_it_works>
        <.key_points items={[
          "Bindings and expressions react locally before any request reaches Phoenix.",
          "handle_event/3 receives the request signals already read.",
          "patch_signals/3 updates server-owned signals.",
          "remove_signals/3 clears selected client state.",
          "The inspector itself is patched after each command."
        ]} />

        <.prose>
          Signals are client state. Datastar posts the current set with every event, so
          <code class="font-mono text-sm">handle_event/3</code>
          receives them already read; <code class="font-mono text-sm">patch_signals/2</code>
          writes server-owned values back and <code class="font-mono text-sm">remove_signals/2</code>
          deletes client ones. The inspector prints the raw map it was handed, minus the CSRF and
          tab keys.
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
          This is the one comparison where the two sides are not solving the same
          problem, because LiveView does not have the concept this page inspects.
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
  def handle_event(conn, "read", signals) do
    state =
      client_state(signals, tick: current_tick(signals), audit: "signals from handle_event/3")

    conn
    |> patch_signals(state)
    |> patch(&inspector/1, state)
  end

  def handle_event(conn, "patch", signals) do
    tick = next_tick(signals)
    state = client_state(signals, tick: tick, audit: "patch_signals tick #{tick}")

    conn
    |> patch_signals(state)
    |> patch(&inspector/1, state)
  end

  def handle_event(conn, "remove", signals) do
    state = client_state(signals, tick: current_tick(signals), audit: "remove_signals ephemeral")
    state = %{state | ephemeral: nil}

    conn
    |> patch_signals(state)
    |> remove_signals("ephemeral")
    |> patch(&inspector/1, state)
  end

  attr :scope, :string, required: true
  attr :filter, :string, required: true
  attr :ephemeral, :any, required: true
  attr :server_tick, :integer, required: true
  attr :audit_trail, :string, required: true
  attr :last_read, :map, required: true

  def inspector(assigns) do
    ~H"""
    <div id="signals-inspector" class="mt-5 border border-base-300 bg-base-100 p-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p class="text-sm font-semibold text-base-content">Signal snapshot</p>
          <p class="mt-1 font-mono text-xs text-base-content/65">{@audit_trail}</p>
        </div>
        <.pill label={"tick #{@server_tick}"} tone="info" />
      </div>

      <dl class="mt-4 grid gap-2 md:grid-cols-2">
        <.signal_row label="scope" value={@scope} />
        <.signal_row label="filter" value={@filter} />
        <.signal_row label="ephemeral" value={inspect(@ephemeral)} />
        <.signal_row label="server_tick" value={to_string(@server_tick)} />
      </dl>

      <pre class="mt-4 overflow-x-auto border border-base-300 bg-base-200 p-3 font-mono text-xs leading-5 text-base-content"><code>{Jason.encode!(@last_read, pretty: true)}</code></pre>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  def signal_row(assigns) do
    ~H"""
    <div class="border border-base-300 bg-base-200 px-3 py-2">
      <dt class="font-mono text-xs text-base-content/65">{@label}</dt>
      <dd class="mt-1 break-words text-sm font-semibold text-base-content">{@value}</dd>
    </div>
    """
  end

  defp client_state(signals, tick: tick, audit: audit) do
    %{
      scope: signals["scope"] || "release",
      filter: signals["filter"] || "open",
      ephemeral: Map.get(signals, "ephemeral", "client-note"),
      server_tick: tick,
      audit_trail: audit,
      # Drop last_read too: it round-trips as a signal, so leaving the
      # previous snapshot inside the new one nests it a level per event.
      last_read: Map.drop(signals, ["csrf", "_csrf_token", "tabId", "last_read"])
    }
  end

  defp next_tick(signals) do
    case signals["server_tick"] do
      tick when is_integer(tick) -> tick + 1
      tick when is_binary(tick) -> String.to_integer(tick) + 1
      _ -> 1
    end
  rescue
    ArgumentError -> 1
  end

  defp current_tick(signals) do
    case signals["server_tick"] do
      tick when is_integer(tick) -> tick
      tick when is_binary(tick) -> String.to_integer(tick)
      _ -> 0
    end
  rescue
    ArgumentError -> 0
  end
end
