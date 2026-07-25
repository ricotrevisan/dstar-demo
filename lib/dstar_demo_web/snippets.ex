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
      """,
      liveview: nil,
      note: nil
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

      Dstar's one real advantage is that `query` lives in a client signal, so the
      server never re-renders the input at all. There is no round trip that could
      disturb a cursor position or an in-progress IME composition — which is
      exactly what the comment in the handler is guarding — and nothing is held
      open between keystrokes.
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
      liveview: nil,
      note: nil
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
      liveview: nil,
      note: nil
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
      liveview: nil,
      note: nil
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
      liveview: nil,
      note: nil
    },
    scripts: %{
      source: "#{@pages}/scripts_page.ex",
      wiring_language: "elixir",
      wiring: """
      def handle_event(conn, "execute", signals) do
        runs = next_runs(signals)

        conn
        |> patch_signals(%{script_runs: runs, last_script_action: "execute_script"})
        |> execute_script(
          "document.documentElement.dataset.dstarScriptPulse = \#{Jason.encode!(Integer.to_string(runs))}",
          auto_remove: false,
          attributes: %{"data-demo-script" => "execute"}
        )
      end
      """,
      liveview: nil,
      note: nil
    },
    presence: %{
      source: "#{@pages}/presence_page.ex",
      wiring_language: "elixir",
      wiring: """
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
      """,
      liveview: nil,
      note: nil
    }
  }

  @spec all() :: %{atom() => map()}
  def all, do: @snippets

  @spec fetch!(atom()) :: map()
  def fetch!(demo), do: Map.fetch!(@snippets, demo)
end
