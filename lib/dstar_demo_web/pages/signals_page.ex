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
    ~H"""
    <.demo_shell
      active="Signals"
      title="Signals lifecycle"
      eyebrow="Inspector"
      summary="Inspect the signals handed to handle_event/3, patch server-owned values, and remove client signals while watching the current flow."
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
      <:aside>
        <.demo_facts items={[
          "handle_event/3 receives the request signals already read.",
          "patch_signals/3 updates server-owned signals.",
          "remove_signals/3 clears selected client state.",
          "The inspector itself is patched after each command."
        ]} />
      </:aside>

      <section class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_340px]">
        <div class="rounded-lg border border-zinc-800 bg-zinc-900 p-5">
          <div class="grid gap-4 md:grid-cols-3">
            <label class="block">
              <span class="mb-2 block text-sm font-medium text-zinc-300">Scope</span>
              <input
                id="signals-scope"
                data-bind:scope
                value={@scope}
                class="w-full rounded-md border border-zinc-700 bg-zinc-950 px-3 py-2.5 text-zinc-100 outline-none transition focus:border-emerald-300"
              />
            </label>
            <label class="block">
              <span class="mb-2 block text-sm font-medium text-zinc-300">Filter</span>
              <input
                id="signals-filter"
                data-bind:filter
                value={@filter}
                class="w-full rounded-md border border-zinc-700 bg-zinc-950 px-3 py-2.5 text-zinc-100 outline-none transition focus:border-emerald-300"
              />
            </label>
            <label class="block">
              <span class="mb-2 block text-sm font-medium text-zinc-300">Ephemeral</span>
              <input
                id="signals-ephemeral"
                data-bind:ephemeral
                value={@ephemeral}
                class="w-full rounded-md border border-zinc-700 bg-zinc-950 px-3 py-2.5 text-zinc-100 outline-none transition focus:border-emerald-300"
              />
            </label>
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

        <aside class="rounded-lg border border-zinc-800 bg-zinc-950 p-4">
          <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">
            Current flow
          </p>
          <ol class="mt-4 space-y-2 text-sm text-zinc-300">
            <li class="rounded-md bg-zinc-900 px-3 py-2">
              1. Client sends scope, filter, and ephemeral.
            </li>
            <li class="rounded-md bg-zinc-900 px-3 py-2">
              2. Dstar.Page.Plug reads the signals and starts SSE.
            </li>
            <li class="rounded-md bg-zinc-900 px-3 py-2">3. Server patches or removes signals.</li>
            <li class="rounded-md bg-zinc-900 px-3 py-2">4. Inspector HTML is patched.</li>
          </ol>
        </aside>
      </section>
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
    <div id="signals-inspector" class="mt-5 rounded-lg border border-zinc-800 bg-zinc-950 p-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p class="text-sm font-semibold text-zinc-100">Signal snapshot</p>
          <p class="mt-1 text-xs text-zinc-500">{@audit_trail}</p>
        </div>
        <.pill label={"tick #{@server_tick}"} tone="info" />
      </div>

      <dl class="mt-4 grid gap-2 md:grid-cols-2">
        <.signal_row label="scope" value={@scope} />
        <.signal_row label="filter" value={@filter} />
        <.signal_row label="ephemeral" value={inspect(@ephemeral)} />
        <.signal_row label="server_tick" value={to_string(@server_tick)} />
      </dl>

      <pre class="mt-4 overflow-x-auto rounded-md bg-zinc-900 p-3 text-xs leading-5 text-zinc-300"><code>{Jason.encode!(@last_read, pretty: true)}</code></pre>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  def signal_row(assigns) do
    ~H"""
    <div class="rounded-md border border-zinc-800 bg-zinc-900 px-3 py-2">
      <dt class="text-xs text-zinc-500">{@label}</dt>
      <dd class="mt-1 break-words text-sm font-semibold text-zinc-100">{@value}</dd>
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
