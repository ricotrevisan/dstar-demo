defmodule DstarDemoWeb.Snippets do
  @moduledoc """
  The code samples the documentation pages display, kept out of the page
  modules so one test can check every one of them against the source it
  quotes, and so the eight review-gated LiveView comparisons live in one file.

  `wiring` is the excerpt shown under **How it works**, and is also the Dstar
  side of the LiveView comparison — one verified excerpt, checked once.
  `liveview` and `note` are the other two parts of that comparison; a demo with
  no comparison yet leaves them `nil` and renders no `<:comparison>` slot.
  """

  @pages "lib/dstar_demo_web/pages"

  @snippets %{
    commands: %{
      source: "#{@pages}/commands_page.ex",
      wiring_language: "elixir",
      wiring: """
      def handle_event(conn, "validate", params) do
        validation = validate(params)
        intent = if ready?(validation), do: "accepted", else: "rejected"
        submitted = submitted_fields(params)

        conn
        |> patch(&status_badge/1, intent: intent)
        |> patch(&field_feedback/1,
          name: "email",
          hint: "Company addresses only — try ada@example.com.",
          field: validation["email"],
          intent: intent
        )
        |> patch(&field_feedback/1,
          name: "first_name",
          field: validation["first_name"],
          intent: intent
        )
        |> patch(&field_feedback/1,
          name: "last_name",
          field: validation["last_name"],
          intent: intent
        )
        |> patch(&validation_panel/1, validation: validation, intent: intent)
        |> patch(&payload_panel/1, submitted: submitted)
      end
      """,
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      def mount(_params, _session, socket) do
        changeset = AccessPass.changeset(%AccessPass{}, %{})

        {:ok, assign(socket, form: to_form(changeset, as: :access_pass))}
      end

      def handle_event("validate", %{"access_pass" => params}, socket) do
        form =
          %AccessPass{}
          |> AccessPass.changeset(params)
          |> Map.put(:action, :validate)
          |> to_form(as: :access_pass)

        {:noreply, assign(socket, form: form)}
      end

      def render(assigns) do
        ~H\"\"\"
        <.form for={@form} id="access-pass-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:first_name]} type="text" label="First name" minlength="2" />
          <.input field={@form[:last_name]} type="text" label="Last name" />

          <.button phx-disable-with="Checking…">Request access</.button>
        </.form>
        \"\"\"
      end
      """,
      note: """
      LiveView wins this one outright. A changeset plus `to_form/2` gives you
      field-level errors, `<.input>` renders each error next to its own field,
      `used_input?/1` keeps untouched fields quiet until they are touched,
      `phx-disable-with` handles the in-flight state, and form recovery after a
      dropped connection is automatic. The Dstar version hand-rolls all of it:
      the six `patch/3` calls and the whole `field_feedback/1` component exist to
      do what `<.input>` does for free.

      What Dstar buys in exchange is that this is a plain HTML form. It posts
      with `contentType: 'form'`, so the server receives ordinary form params and
      the markup would still submit with JavaScript disabled — and the response
      names exactly which six fragments change, rather than diffing a rendered
      tree the server had to keep.
      """
    },
    active_search: %{
      source: "#{@pages}/active_search_page.ex",
      wiring_language: "elixir",
      wiring: """
      def handle_event(conn, "search", signals) do
        query = String.trim(signals["query"] || "")
        segment = signals["segment"] || "all"
        results = search(query, segment)

        # The client owns query/segment — echoing them back would clobber
        # anything typed while this response was in flight.
        patch(conn, &result_panel/1,
          results: results,
          query: query,
          segment: segment,
          result_count: length(results)
        )
      end
      """,
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      def mount(_params, _session, socket) do
        {:ok, assign(socket, query: "", segment: "all", results: search("", "all"))}
      end

      def handle_event("search", %{"query" => query, "segment" => segment}, socket) do
        query = String.trim(query)

        {:noreply,
         assign(socket,
           query: query,
           segment: segment,
           results: search(query, segment)
         )}
      end

      def render(assigns) do
        ~H\"\"\"
        <form phx-change="search" phx-submit="search">
          <input
            type="search"
            name="query"
            value={@query}
            phx-debounce="240"
            autocomplete="off"
            placeholder="Try stream, patch, signal, or owner names"
          />

          <select name="segment">
            <option :for={s <- ~w(all workflow dashboard tool)} value={s} selected={s == @segment}>
              {s}
            </option>
          </select>
        </form>

        <div id="search-results">
          <p>{length(@results)} matches</p>

          <article :for={item <- @results} id={"result-" <> item.name}>
            <h2>{item.name}</h2>
            <p>{item.type} · {item.owner}</p>
          </article>
        </div>
        \"\"\"
      end
      """,
      note: """
      LiveView needs less wiring here. `phx-debounce="240"` is built in, and the
      diff engine works out on its own that only the result list changed — no
      selector is named anywhere. It also tracks the in-flight state for you
      through `phx-change`'s loading classes, where the Dstar version declares
      `data-indicator="_searchPending"` explicitly.

      Dstar's one real advantage is that `query` lives in a client signal, so
      the server never renders the input at all. LiveView protects the focused
      input too — it deliberately never overwrites the value of the element you
      are typing in, which is documented behaviour rather than luck. The
      difference is that LiveView needs that guard because the input is
      server-rendered on every round trip, and here there is no round trip to
      guard: the value is only ever read from the client, never sent back to it.
      That is exactly what the comment in the handler is preserving, and it is
      why nothing has to be held open between keystrokes.
      """
    },
    streaming_dashboard: %{
      source: "#{@pages}/streaming_dashboard_page.ex",
      wiring_language: "elixir",
      wiring: """
      def stream_key(_conn), do: {:dstar_demo, :streaming_dashboard}

      @impl Dstar.Page
      def handle_connect(conn, _params) do
        Process.send_after(self(), {:tick, 1}, @stream_delay)

        conn
        |> patch_signals(%{streamStatus: "live", progress: 0, tick: 0})
        |> patch(&stream_frame/1, [tick: 0, status: "live"], selector: "#stream-frame")
      end
      """,
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      @stream_steps 8
      @stream_delay 280

      def mount(_params, _session, socket) do
        if connected?(socket), do: Process.send_after(self(), {:tick, 1}, @stream_delay)

        {:ok,
         assign(socket,
           status: "live",
           tick: 0,
           throughput: 118,
           latency: 42,
           progress: 0,
           activity: []
         )}
      end

      def handle_info({:tick, tick}, socket) when tick <= @stream_steps do
        Process.send_after(self(), {:tick, tick + 1}, @stream_delay)

        {:noreply,
         assign(socket,
           tick: tick,
           throughput: 118 + tick * 9 + rem(tick, 3) * 4,
           latency: 42 - min(tick * 2, 18),
           progress: trunc(tick / @stream_steps * 100),
           activity: [tick | socket.assigns.activity]
         )}
      end

      def handle_info({:tick, _done}, socket) do
        {:noreply, assign(socket, status: "complete", progress: 100)}
      end
      """,
      note: """
      LiveView wins, and it wins structurally rather than on ergonomics. A
      LiveView **is** a stateful process per connection, so the entire notion of
      `stream_key/1` deduplication disappears: there is no second stream to
      replace, because a reconnect makes a new process and the old one dies. The
      three metric tiles and the activity list are assigns, so no `patch/3` call
      names a selector and no `mode: :prepend` has to be chosen. Bounding the run
      needs no `{:halt, conn}` — the final `handle_info/2` clause simply stops
      scheduling.

      Dstar's model is preferable only if you want the connection to be an HTTP
      request that ends. This stream closes and leaves nothing resident on the
      server; a LiveView holds a process, and its assigns, for as long as the tab
      is open. For a bounded eight-tick dashboard that is a poor trade, and this
      is the demo where the Dstar version is doing the most extra work for the
      least gain.
      """
    },
    patch_lab: %{
      source: "#{@pages}/patch_lab_page.ex",
      wiring_language: "elixir",
      wiring: """
      "before" ->
        patch(conn, &patch_badge/1, [mode: mode, count: count],
          selector: "#anchor-row",
          mode: :before
        )

      "after" ->
        patch(conn, &patch_badge/1, [mode: mode, count: count],
          selector: "#anchor-row",
          mode: :after
        )

      "remove" ->
        remove_elements(conn, "#removable-note")
      """,
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      #
      # LiveView has no patch-mode API at all: you change assigns and it works
      # out the DOM operation. The nearest thing to append and prepend is a
      # stream with :at; outer, inner, before and after have no equivalent
      # because you never name the operation.
      def mount(_params, _session, socket) do
        {:ok,
         socket
         |> assign(count: 0, note_visible?: true)
         |> stream(:rows, [%{id: "seed-row", label: "Seed row"}])}
      end

      def handle_event("append", _params, socket) do
        count = socket.assigns.count + 1

        {:noreply,
         socket
         |> assign(count: count)
         |> stream_insert(:rows, %{id: "row-" <> to_string(count), label: "append patch"}, at: -1)}
      end

      def handle_event("prepend", _params, socket) do
        count = socket.assigns.count + 1

        {:noreply,
         socket
         |> assign(count: count)
         |> stream_insert(:rows, %{id: "row-" <> to_string(count), label: "prepend patch"}, at: 0)}
      end

      def handle_event("remove", _params, socket) do
        {:noreply, assign(socket, note_visible?: false)}
      end

      def render(assigns) do
        ~H\"\"\"
        <div id="patch-list" phx-update="stream">
          <div :for={{dom_id, row} <- @streams.rows} id={dom_id}>{row.label}</div>
        </div>

        <div :if={@note_visible?} id="removable-note">Remove mode deletes this note.</div>
        \"\"\"
      end
      """,
      note: """
      These are different philosophies rather than a winner and a loser.
      LiveView deliberately hides the DOM operation: you describe the state you
      want and the diff engine picks the mutation. That is why there is no
      `:outer` or `:before` to get wrong, and why `remove` is expressed as a
      conditional rather than a deletion. `phx-update="stream"` covers the
      append and prepend cases and manages a memory bound for you, which
      hand-written `mode: :append` calls do not.

      Dstar exposes the operation directly. That is what makes this page
      demonstrable at all — there is nothing to show if the framework chooses for
      you — and it is what you need when the server holds no rendered copy of the
      page to diff against. The honest summary is that most applications want
      LiveView's abstraction, and the ones that cannot afford resident
      server-side state want this.
      """
    },
    server_components: %{
      source: "#{@pages}/server_components_page.ex",
      wiring_language: "heex",
      wiring: """
      <.action_button
        id="component-profile"
        label="Profile"
        icon="hero-identification-micro"
        click={"$component_kind = 'profile'; \#{ComponentStage.event("profile")}"}
        active={@component_kind == "profile"}
        data-class={variant_classes("profile")}
      />
      """,
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      defmodule DstarDemoWeb.ComponentStageLive do
        use DstarDemoWeb, :live_component

        def render(assigns) do
          ~H\"\"\"
          <div id={@id}>
            <button phx-click="profile" phx-target={@myself}>Profile</button>
            <button phx-click="timeline" phx-target={@myself}>Timeline</button>
            <button phx-click="deploy" phx-target={@myself}>Deploy</button>

            <p>{@component_kind} · renders: {@render_count}</p>
          </div>
          \"\"\"
        end

        def handle_event(kind, _params, socket) do
          {:noreply,
           assign(socket,
             component_kind: kind,
             render_count: socket.assigns.render_count + 1
           )}
        end
      end

      # In the parent LiveView:
      #
      #   <.live_component
      #     module={DstarDemoWeb.ComponentStageLive}
      #     id="component-stage"
      #     component_kind={@component_kind}
      #     render_count={@render_count}
      #   />
      """,
      note: """
      Near parity, and `Phoenix.LiveComponent` does strictly more:
      it has its own lifecycle through `update/2` and `update_many/1`, and it
      can hold state between events without the parent knowing. If a stage
      needed to remember anything of its own, LiveView would win here without
      argument.

      The costs on the LiveView side are that a component requires an `:id`, that
      every event needs `phx-target={@myself}` or it silently dispatches to the
      parent instead, and that the component's state still lives in the parent's
      process. `Dstar.Component` is stateless and routes by module name, so
      nothing has to be targeted and this page needs no handler clauses at all —
      but there is no per-instance state to be had, and two stages on one page
      would share the same handler.
      """
    },
    signals: %{
      source: "#{@pages}/signals_page.ex",
      wiring_language: "elixir",
      wiring: """
      def handle_event(conn, "patch", signals) do
        tick = next_tick(signals)
        state = client_state(signals, tick: tick, audit: "patch_signals tick \#{tick}")

        conn
        |> patch_signals(state)
        |> patch(&inspector/1, state)
      end
      """,
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      #
      # There is no client-owned state to inspect: assigns live on the server,
      # and the client only ever sends what a binding names explicitly. So this
      # page has no real LiveView counterpart — only the nearest thing.
      def mount(_params, _session, socket) do
        {:ok,
         assign(socket,
           scope: "release",
           filter: "open",
           server_tick: 0,
           audit_trail: "mount"
         )}
      end

      def handle_event("patch", _params, socket) do
        tick = socket.assigns.server_tick + 1

        {:noreply, assign(socket, server_tick: tick, audit_trail: "assign tick")}
      end

      # To send client-held values at all, each one must be named:
      #
      #   <button phx-click="patch" phx-value-scope={@scope} phx-value-filter={@filter}>
      #
      # or a JS hook pushes them:
      #
      #   this.pushEvent("patch", {scope, filter})
      """,
      note: """
      This is the one page where the two frameworks disagree about where state
      lives rather than one doing the same job better. LiveView's assigns are
      server-authoritative: the client cannot invent a field, so there is nothing
      to validate, no `remove_signals/2` to need, and no way for a stale client
      value to reach a handler. That is genuinely simpler and genuinely safer,
      and for most applications it is the right default.

      Dstar's signals are client-owned and arrive with every event, which is what
      makes an inspector like this one possible — and it means every handler must
      treat them as untrusted input. The tax is visible in this page's own code:
      `client_state/2` drops `csrf`, `_csrf_token`, `tabId` and `last_read` before
      displaying anything, and each numeric field is parsed defensively because a
      signal can arrive as a string, or as `""` when it was never set.
      """
    },
    scripts: %{
      source: "#{@pages}/scripts_page.ex",
      wiring_language: "elixir",
      wiring: """
      conn
      |> patch_signals(%{script_runs: runs, last_script_action: "execute_script"})
      |> prepend_log(runs, "execute_script/3", source)
      |> execute_script(source,
        auto_remove: false,
        attributes: %{"data-demo-script" => "run"}
      )
      """,
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      def handle_event("execute", _params, socket) do
        runs = socket.assigns.script_runs + 1

        {:noreply,
         socket
         |> assign(script_runs: runs, last_script_action: "push_event")
         |> push_event("script-pulse", %{run: runs})}
      end

      def handle_event("console", _params, socket) do
        runs = socket.assigns.script_runs + 1

        {:noreply,
         socket
         |> assign(script_runs: runs, last_script_action: "push_event")
         |> push_event("script-log", %{level: "info", run: runs})}
      end

      def handle_event("redirect", _params, socket) do
        {:noreply, push_navigate(socket, to: ~p"/scripts?redirected=1")}
      end

      # The browser half is a hook, declared once in your bundle rather than
      # sent down per event:
      #
      #   Hooks.ScriptPulse = {
      #     mounted() {
      #       this.handleEvent("script-pulse", ({run}) => {
      #         document.documentElement.dataset.dstarScriptPulse = String(run)
      #       })
      #
      #       this.handleEvent("script-log", ({level, run}) => {
      #         console[level]("dstar demo", {run})
      #       })
      #     }
      #   }
      """,
      note: """
      LiveView's design is better here, and the difference is a security one.
      `push_event/3` sends **data** to a named hook that already exists in your
      bundle; `execute_script/3` sends **code**. Anything interpolated into that
      string is one mistake away from running in the browser — which is why this
      page's own counter goes through `Jason.encode!/1` before it is spliced in.
      LiveView also gives two softer ways to move the user than the full
      navigation `redirect/3` performs: `push_patch/2` changes the URL and
      re-runs `handle_params/3` in the same process, and `push_navigate/2`
      tears this LiveView down and mounts another over the same socket — a new
      process, but still no page load.

      Dstar's helpers win on immediacy only: no hook has to be written,
      registered, or bundled to make a one-off effect happen. That is why they
      exist, and it is also why the other seven demos deliberately avoid them —
      the server-rendered patch flow stays easier to inspect without them.
      """
    },
    presence: %{
      source: "#{@pages}/presence_page.ex",
      wiring_language: "elixir",
      wiring: """
      def handle_connect(conn, _params) do
        # ...

        Phoenix.PubSub.subscribe(DstarDemo.PubSub, @topic)
        remember_presence_instance(registry_tab, presence_instance)

        {:ok, _} =
          Presence.track(self(), @topic, tab_id, %{
            name: name,
            color: color,
            status: "active",
            presence_instance: presence_instance,
            last_seen: System.system_time(:second)
          })

        # ...
      end

      # ...

      # Sent by the pagehide beacon in app.js. The response body is never read
      # by the browser, so the already-started SSE stream simply closes empty.
      def handle_event(conn, "leave", signals) do
        # Same validation the stream registered under, so the lookup can't miss.
        registry_tab = Dstar.Utility.StreamRegistry.tab_id(conn)
        presence_instance = sanitize_token(signals["presenceInstance"])

        if registry_tab && presence_instance do
          notify_presence_stream(
            registry_tab,
            presence_instance,
            {:presence_leave, registry_tab, presence_instance}
          )
        end

        conn
      end

      # ...

      def handle_info({:presence_leave, tab, presence_instance}, conn) do
        if tab != nil and tab == conn.assigns[:registry_tab] and
             presence_instance == conn.assigns.presence_instance do
          {:halt, conn}
        else
          conn
        end
      end

      # ...

      # Runs on every exit from the library's receive loop. Dstar releases the
      # StreamRegistry key itself; this is the app-owned state handle_connect/2
      # acquired. Both operations are scoped to self(), so a takeover cannot
      # clobber what the replacing stream already tracked for the same tab.
      @impl Dstar.Page
      def handle_disconnect(conn) do
        if tab_id = conn.assigns[:tab_id] do
          Presence.untrack(self(), @topic, tab_id)
        end

        Phoenix.PubSub.unsubscribe(DstarDemo.PubSub, @topic)
      end
      """,
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      def mount(_params, _session, socket) do
        # ...

        if connected?(socket) do
          Phoenix.PubSub.subscribe(DstarDemo.PubSub, @topic)

          # Same meta, minus presence_instance — and socket.id instead of a
          # client-sent tab_id, because the process itself is the identity.
          {:ok, _} =
            Presence.track(self(), @topic, socket.id, %{
              name: name,
              color: color,
              status: "active",
              last_seen: System.system_time(:second)
            })
        end

        # ...
      end

      # ... presence_diff, ping, and rename handlers elided — they mirror
      # the Dstar side.

      # Leaving takes zero parts. No untrack is written anywhere: Presence
      # is bound to self(), and the LiveView process dying on disconnect
      # removes the entry — including when it dies by crashing.
      """,
      note: """
      LiveView wins, and this demo shows precisely why. Presence is keyed to a
      process, and a LiveView already has one per connection: tracking happens
      once in `mount/3`, and untracking happens for free when the process dies.

      A Dstar stream is a request that has to clean up after itself. This page
      therefore needs `handle_disconnect/1` to untrack, a `presence_instance`
      token so a replaced stream can tell itself apart from the one that replaced
      it, and a `pagehide` beacon in `app.js` posting a `leave` event so a closed
      tab does not sit in the roster until it times out. That is three moving
      parts LiveView does not have, and all three are visible in this page's
      source.

      What Dstar gets back is that nothing is resident between events. For
      presence specifically, resident state is the entire feature — so this is
      the demo where the Dstar version is hardest to justify on its own merits,
      and it is here to show the pattern rather than to recommend it.
      """
    }
  }

  @spec all() :: %{atom() => map()}
  def all, do: @snippets

  @spec fetch!(atom()) :: map()
  def fetch!(demo), do: Map.fetch!(@snippets, demo)
end
