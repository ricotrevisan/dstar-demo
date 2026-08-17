defmodule DstarDemoWeb.PresencePage do
  use DstarDemoWeb, :dstar_page

  alias DstarDemoWeb.Presence

  @topic "presence:lobby"
  @stream_scope {:dstar_demo, :presence}
  @colors ~w(emerald sky violet amber rose cyan lime fuchsia)

  # Visitors are named after the main cast of The Expanse. The portraits are
  # scaled-down stills from expanse.fandom.com, copied into priv/static so the
  # page never reaches out to another host at runtime. A visitor who renames
  # themselves to something off this list falls back to initials-in-a-circle.
  @characters [
    %{name: "James Holden", avatar: "holden", color: "sky"},
    %{name: "Naomi Nagata", avatar: "nagata", color: "violet"},
    %{name: "Amos Burton", avatar: "burton", color: "amber"},
    %{name: "Alex Kamal", avatar: "kamal", color: "rose"},
    %{name: "Chrisjen Avasarala", avatar: "avasarala", color: "fuchsia"},
    %{name: "Bobbie Draper", avatar: "draper", color: "lime"},
    %{name: "Camina Drummer", avatar: "drummer", color: "cyan"},
    %{name: "Josephus Miller", avatar: "miller", color: "emerald"}
  ]

  @avatars Map.new(@characters, &{&1.name, &1.avatar <> ".webp"})

  @impl Dstar.Page
  def mount(conn, _params) do
    visitor = visitor_for(get_session(conn, :presence_seed) || random_seed())

    conn
    |> put_session(:presence_seed, visitor.seed)
    |> assign(:visitorName, visitor.name)
    |> assign(:visitorColor, visitor.color)
    |> assign(:presenceInstance, random_seed())
    |> assign(:presenceStatus, "connecting")
  end

  # POST /presence — Dstar.Page.Plug opens the SSE stream (deduplicated per
  # tab via stream_key/1) and owns the receive loop behind handle_info/2.
  @impl Dstar.Page
  def stream_key(_conn), do: @stream_scope

  @impl Dstar.Page
  def handle_connect(conn, _params) do
    signals = read_signals(conn)
    # Two different keys on purpose. registry_tab is the exact value
    # Dstar.start_stream registered under — nil when the tabId was unusable
    # (missing, blank, or over 64 bytes) and this stream is simply not
    # deduplicated. The presence identity is separate: it only has to be
    # stable per tab, so an oversized tabId is truncated rather than dropped.
    registry_tab = Dstar.Utility.StreamRegistry.tab_id(conn)
    tab_id = sanitize_token(signals["tabId"]) || random_seed()
    presence_instance = sanitize_token(signals["presenceInstance"]) || random_seed()
    name = sanitize_name(signals["visitorName"])
    visitor = visitor_for(name || tab_id)
    name = name || visitor.name
    color = sanitize_color(signals["visitorColor"]) || visitor.color

    {:ok, _} =
      Presence.track(self(), @topic, tab_id, %{
        name: name,
        color: color,
        status: "active",
        presence_instance: presence_instance,
        last_seen: System.system_time(:second)
      })

    presence_stream_topic = presence_stream_topic(registry_tab, presence_instance)
    Phoenix.PubSub.subscribe(DstarDemo.PubSub, @topic)
    subscribe_presence_stream(presence_stream_topic)
    broadcast_activity("#{name} joined the room", "join")

    conn =
      conn
      |> assign(:tab_id, tab_id)
      |> assign(:registry_tab, registry_tab)
      |> assign(:presence_instance, presence_instance)
      |> assign(:presence_stream_topic, presence_stream_topic)

    case safe_presence_patch(conn, fn conn ->
           conn
           |> patch_signals(%{presenceStatus: "live"})
           |> patch_presence()
         end) do
      {:ok, conn} ->
        conn

      {:closed, conn} ->
        # handle_connect cannot halt the loop directly; have handle_info do it.
        send(self(), :client_gone)
        conn
    end
  end

  @impl Dstar.Page
  def handle_info(:client_gone, conn), do: {:halt, conn}

  def handle_info({:presence_leave, tab, presence_instance}, conn) do
    if tab != nil and tab == conn.assigns[:registry_tab] and
         presence_instance == conn.assigns.presence_instance do
      {:halt, conn}
    else
      conn
    end
  end

  def handle_info({:presence_rename, name}, conn) do
    case current_meta(conn.assigns.tab_id) do
      %{name: ^name} ->
        conn

      %{} = meta ->
        {:ok, _} = Presence.update(self(), @topic, conn.assigns.tab_id, %{meta | name: name})
        broadcast_activity("#{meta.name} is now #{name}", "rename", meta.color)

        # Presence.update's diff repaints every roster, including this tab's.
        # The "You" card is outside #presence-board, so patch its avatar here;
        # the name itself is already on screen — the input the user typed into.
        case safe_presence_patch(conn, fn conn ->
               patch(
                 conn,
                 &avatar/1,
                 [
                   id: "presence-you-avatar",
                   name: name,
                   color: meta.color,
                   class: "size-11 text-sm"
                 ],
                 selector: "#presence-you-avatar"
               )
             end) do
          {:ok, conn} -> conn
          {:closed, conn} -> {:halt, conn}
        end

      nil ->
        conn
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, conn) do
    {joins, leaves} = presence_diff_summary(diff)
    message = "Presence changed: +#{joins} / -#{leaves}"

    case safe_presence_patch(conn, fn conn ->
           conn = patch_presence(conn)

           # A rename is a join and a leave on the same key. The roster still
           # has to repaint, but announcing "+1 / -1" for it would be a lie.
           if joins + leaves > 0 do
             patch(conn, &activity_row/1, [message: message, kind: "diff", color: "sky"],
               selector: "#presence-activity",
               mode: :prepend
             )
           else
             conn
           end
         end) do
      {:ok, conn} -> conn
      {:closed, conn} -> {:halt, conn}
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_activity", payload: payload}, conn) do
    case safe_presence_patch(conn, fn conn ->
           patch(conn, &activity_row/1, payload,
             selector: "#presence-activity",
             mode: :prepend
           )
         end) do
      {:ok, conn} -> conn
      {:closed, conn} -> {:halt, conn}
    end
  end

  # Runs on every exit from the library's receive loop. Dstar releases its
  # stream claim; this page releases the Presence and PubSub state it acquired.
  @impl Dstar.Page
  def handle_disconnect(conn) do
    if tab_id = conn.assigns[:tab_id] do
      Presence.untrack(self(), @topic, tab_id)
    end

    unsubscribe_presence_stream(conn.assigns[:presence_stream_topic])
    Phoenix.PubSub.unsubscribe(DstarDemo.PubSub, @topic)
  end

  @impl Dstar.Page
  def handle_event(conn, "ping", signals) do
    name = sanitize_name(signals["visitorName"]) || "Someone"
    color = sanitize_color(signals["visitorColor"]) || "emerald"

    broadcast_activity("#{name} sent a room ping", "ping", color)

    patch(
      conn,
      &activity_row/1,
      [message: "Ping sent — other tabs will see it.", kind: "ping", color: color],
      selector: "#presence-activity",
      mode: :prepend
    )
  end

  # The name input is client-owned ($visitorName), so the roster only learns
  # about a rename when this event hands it to the tab's own stream process —
  # that process is the one Presence tracked under, so it owns the update.
  def handle_event(conn, "rename", signals) do
    registry_tab = Dstar.Utility.StreamRegistry.tab_id(conn)
    presence_instance = sanitize_token(signals["presenceInstance"])
    name = sanitize_name(signals["visitorName"])

    if registry_tab && presence_instance && name do
      notify_presence_stream(registry_tab, presence_instance, {:presence_rename, name})
    end

    conn
  end

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

  @impl Dstar.Page
  def render(assigns) do
    assigns = Map.put(assigns, :snippet, DstarDemoWeb.Snippets.fetch!(:presence))

    ~H"""
    <.demo_shell
      active="Presence"
      title="Presence room"
      summary="Open this page in multiple tabs to see visitors join, leave, and send collaborative room pings through Phoenix Presence and Dstar patches."
      signals={
        %{
          visitorName: @visitorName,
          visitorColor: @visitorColor,
          presenceInstance: @presenceInstance,
          presenceStatus: @presenceStatus
        }
      }
    >
      <:demo>
        <section
          id="presence-room"
          data-init={room_connect()}
          data-on:online__window={room_connect()}
          data-on:pageshow__window={"evt.persisted && ($presenceInstance = crypto.randomUUID(), el.dataset.presenceInstance = $presenceInstance, #{room_connect()})"}
          data-presence-leave-url={~p"/presence/_event/leave"}
          data-presence-instance={@presenceInstance}
          class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_340px]"
        >
          <div class="grid gap-5">
            <div class="border border-base-300 bg-base-200">
              <div class="p-5 sm:p-6">
                <div class="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <p class="font-mono text-xs tracking-wide text-base-content/65 uppercase">
                      Lobby
                    </p>
                    <h2 class="mt-2 text-2xl font-semibold text-base-content">
                      Who is here right now?
                    </h2>
                    <p class="mt-2 max-w-[68ch] text-sm leading-6 text-base-content/70">
                      Keep this tab open, then open another. Each tab becomes a distinct presence and receives live roster patches.
                    </p>
                  </div>
                  <button
                    id="presence-ping"
                    data-on:click={event("ping")}
                    class="inline-flex items-center gap-2 rounded-md border border-primary bg-primary px-4 py-2.5 text-sm font-medium text-primary-content transition hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                  >
                    <.icon name="hero-sparkles-micro" class="size-4" /> Ping room
                  </button>
                </div>

                <.presence_board users={[]} />
              </div>
            </div>
          </div>

          <aside class="grid gap-5">
            <div class="border border-base-300 bg-base-100 p-5">
              <p class="font-mono text-xs tracking-wide text-base-content/65 uppercase">You</p>
              <div class="mt-4 flex items-center gap-3">
                <.avatar
                  id="presence-you-avatar"
                  name={@visitorName}
                  color={@visitorColor}
                  class="size-11 text-sm"
                />
                <div class="min-w-0">
                  <label for="presence-you-name" class="sr-only">Your display name</label>
                  <input
                    id="presence-you-name"
                    type="text"
                    value={@visitorName}
                    maxlength="40"
                    data-bind:visitor-name
                    data-on:input__debounce.400ms={event("rename")}
                    class="w-full border-b border-base-300 bg-transparent px-0 py-0.5 font-semibold text-base-content focus:border-primary focus:outline-none"
                  />
                  <p class="mt-1 text-sm text-base-content/70">
                    status: <span data-text="$presenceStatus">{@presenceStatus}</span>
                  </p>
                </div>
              </div>
            </div>

            <div class="border border-base-300 bg-base-100 p-5">
              <div class="flex items-center justify-between gap-3">
                <p class="font-mono text-xs tracking-wide text-base-content/65 uppercase">
                  Activity
                </p>
                <.pill label="broadcast" tone="info" />
              </div>
              <div id="presence-activity" class="mt-4 space-y-2">
                <.activity_row message="Waiting for visitors…" kind="idle" color="zinc" />
              </div>
            </div>
          </aside>
        </section>
      </:demo>

      <:how_it_works>
        <.key_points items={[
          "Phoenix Presence tracks each browser tab as a visitor.",
          "handle_connect/2 and handle_info/2 drive the room stream.",
          "Roster, online count, and activity are patched independently.",
          "Renaming yourself repaints every open tab's roster.",
          "The ping button broadcasts a tiny collaborative interaction."
        ]} />

        <.prose>
          <code class="font-mono text-sm">handle_connect/2</code>
          subscribes to the room topic and tracks this tab with <code class="font-mono text-sm">Phoenix.Presence</code>, then patches the roster.
          <code class="font-mono text-sm">handle_info/2</code>
          reacts to <code class="font-mono text-sm">presence_diff</code>
          broadcasts, and <code class="font-mono text-sm">handle_disconnect/1</code>
          untracks on every exit from the receive loop — bookkeeping that a per-connection process
          would do for you.
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
          Both sides track each tab with <code class="font-mono text-sm">Phoenix.Presence</code>,
          react to <code class="font-mono text-sm">presence_diff</code>, and broadcast a room ping.
          They differ in what has to happen when a visitor leaves.
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

  attr :users, :list, required: true

  def presence_board(assigns) do
    ~H"""
    <div id="presence-board" class="mt-6 grid gap-4 md:grid-cols-[180px_minmax(0,1fr)]">
      <div id="presence-count" class="border border-base-300 bg-base-100 p-4">
        <p class="font-mono text-xs tracking-wide text-base-content/65 uppercase">Online now</p>
        <p class="mt-3 text-4xl font-semibold tabular-nums text-base-content">{length(@users)}</p>
        <p class="mt-1 text-sm text-base-content/70">active browser tabs</p>
      </div>
      <div id="presence-roster" class="grid gap-2">
        <div
          :if={@users == []}
          class="border border-dashed border-base-300 bg-base-100 p-4 text-sm text-base-content/70"
        >
          Connecting to the room stream…
        </div>
        <div
          :for={user <- @users}
          class="flex items-center justify-between gap-3 border border-base-300 bg-base-100 p-3"
        >
          <div class="flex min-w-0 items-center gap-3">
            <.avatar name={user.name} color={user.color} class="size-10 text-xs" />
            <div class="min-w-0">
              <p class="truncate text-sm font-semibold text-base-content">{user.name}</p>
              <p class="text-xs text-base-content/65">active now</p>
            </div>
          </div>
          <span class="size-2 rounded-full bg-primary"></span>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, default: nil
  attr :name, :string, required: true
  attr :color, :string, required: true
  attr :class, :string, required: true

  def avatar(assigns) do
    assigns = assign(assigns, :src, avatar_src(assigns.name))

    ~H"""
    <span
      id={@id}
      class={[
        "grid shrink-0 place-items-center overflow-hidden rounded-full font-bold",
        @class,
        is_nil(@src) && color_class(@color)
      ]}
    >
      <%!-- The stills are taller than wide with the face near the top, so a
      centred crop would take the forehead off. --%>
      <img :if={@src} src={@src} alt={@name} class="size-full object-cover object-top" />
      <span :if={is_nil(@src)}>{initials(@name)}</span>
    </span>
    """
  end

  attr :message, :string, required: true
  attr :kind, :string, required: true
  attr :color, :string, default: "emerald"

  def activity_row(assigns) do
    ~H"""
    <div class="border border-base-300 bg-base-200 px-3 py-2 text-sm text-base-content/80">
      <span class={["mr-2 inline-block size-2 rounded-full", dot_class(@kind, @color)]}></span>{@message}
    </div>
    """
  end

  # Keys on both sides are updates to an existing entry (a rename), not
  # arrivals or departures, so they cancel out of the join/leave counts.
  def presence_diff_summary(%{joins: joins, leaves: leaves}) do
    updated = joins |> Map.keys() |> Enum.filter(&Map.has_key?(leaves, &1))
    {count_metas(Map.drop(joins, updated)), count_metas(Map.drop(leaves, updated))}
  end

  defp current_meta(tab_id) do
    case Presence.get_by_key(@topic, tab_id) do
      %{metas: [meta | _]} -> meta
      _ -> nil
    end
  end

  defp patch_presence(conn) do
    users =
      @topic
      |> Presence.list()
      |> Enum.map(fn {_key, %{metas: [meta | _]}} -> meta end)
      |> Enum.sort_by(& &1.name)

    patch(conn, &presence_board/1, [users: users], selector: "#presence-board")
  end

  defp safe_presence_patch(conn, patch_fun) when is_function(patch_fun, 1) do
    {:ok, patch_fun.(conn)}
  rescue
    error in RuntimeError ->
      if String.starts_with?(Exception.message(error), "Failed to send SSE event:") do
        {:closed, conn}
      else
        reraise error, __STACKTRACE__
      end
  end

  defp broadcast_activity(message, kind, color \\ "emerald") do
    Phoenix.PubSub.broadcast(DstarDemo.PubSub, @topic, %Phoenix.Socket.Broadcast{
      topic: @topic,
      event: "presence_activity",
      payload: %{message: message, kind: kind, color: color}
    })
  end

  # No client auto-retry. Duplicated tabs share the sessionStorage tabId, so
  # a replaced stream that immediately retries would reclaim the key and make
  # the two tabs replace one another forever. data-on:online__window and the
  # pageshow handler cover the cases where reconnecting actually matters.
  defp room_connect, do: connect(opts: "{retryMaxCount: 0}")

  defp presence_stream_topic(nil, _presence_instance), do: nil

  defp presence_stream_topic(registry_tab, presence_instance) do
    key = Base.url_encode64(registry_tab <> <<0>> <> presence_instance, padding: false)
    @topic <> ":stream:" <> key
  end

  defp subscribe_presence_stream(nil), do: :ok
  defp subscribe_presence_stream(topic), do: Phoenix.PubSub.subscribe(DstarDemo.PubSub, topic)

  defp unsubscribe_presence_stream(nil), do: :ok

  defp unsubscribe_presence_stream(topic),
    do: Phoenix.PubSub.unsubscribe(DstarDemo.PubSub, topic)

  defp notify_presence_stream(registry_tab, presence_instance, message) do
    Phoenix.PubSub.broadcast(
      DstarDemo.PubSub,
      presence_stream_topic(registry_tab, presence_instance),
      message
    )
  end

  # Signals are client-controlled: reject non-strings and cap lengths so a
  # forged request can't impersonate with arbitrary markup-length strings or
  # park megabytes in Presence metas that rebroadcast to every viewer.
  defp sanitize_name(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> String.slice(trimmed, 0, 40)
    end
  end

  defp sanitize_name(_), do: nil

  defp sanitize_token(value) when is_binary(value) and value != "",
    do: String.slice(value, 0, 64)

  defp sanitize_token(_), do: nil

  defp sanitize_color(value) when value in @colors, do: value
  defp sanitize_color(_), do: nil

  defp visitor_for(seed) do
    character = Enum.at(@characters, :erlang.phash2(seed, length(@characters)))
    %{seed: seed, name: character.name, color: character.color}
  end

  defp avatar_src(name) do
    case Map.fetch(@avatars, name) do
      {:ok, file} -> ~p"/images/expanse/#{file}"
      :error -> nil
    end
  end

  defp random_seed, do: Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)

  defp count_metas(entries) do
    entries
    |> Map.values()
    |> Enum.reduce(0, fn %{metas: metas}, total -> total + length(metas) end)
  end

  defp initials(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
  end

  # The visitor palette is the one place this demo needs eight distinguishable
  # hues. They map onto daisyUI's eight semantic tokens rather than raw Tailwind
  # swatches, so the avatars follow the theme in both light and dark, and each
  # pairs with its own `*-content` foreground — which is exactly the token those
  # values are calibrated for, unlike a tinted background. The `@colors` names
  # themselves are unchanged; they are presence metadata, not CSS.
  defp swatch_class("sky"), do: "bg-info"
  defp swatch_class("violet"), do: "bg-secondary"
  defp swatch_class("amber"), do: "bg-warning"
  defp swatch_class("rose"), do: "bg-error"
  defp swatch_class("cyan"), do: "bg-accent"
  defp swatch_class("lime"), do: "bg-primary"
  defp swatch_class("fuchsia"), do: "bg-neutral"
  defp swatch_class(_), do: "bg-success"

  defp color_class("sky"), do: "bg-info text-info-content"
  defp color_class("violet"), do: "bg-secondary text-secondary-content"
  defp color_class("amber"), do: "bg-warning text-warning-content"
  defp color_class("rose"), do: "bg-error text-error-content"
  defp color_class("cyan"), do: "bg-accent text-accent-content"
  defp color_class("lime"), do: "bg-primary text-primary-content"
  defp color_class("fuchsia"), do: "bg-neutral text-neutral-content"
  defp color_class(_), do: "bg-success text-success-content"

  defp dot_class("join", color), do: swatch_class(color)
  defp dot_class("rename", color), do: swatch_class(color)
  defp dot_class("ping", _), do: "bg-warning"
  defp dot_class("diff", _), do: "bg-info"
  defp dot_class(_, _), do: "bg-base-content/45"
end
