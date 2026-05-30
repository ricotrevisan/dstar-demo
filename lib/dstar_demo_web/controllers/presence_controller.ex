defmodule DstarDemoWeb.PresenceController do
  use DstarDemoWeb, :dstar

  alias DstarDemoWeb.Presence

  @topic "presence:lobby"
  @colors ~w(emerald sky violet amber rose cyan lime fuchsia)
  @animals ~w(Otter Finch Lynx Panda Moth Heron Gecko Raven)

  @impl Dstar
  def mount(conn, _params) do
    visitor = visitor_for(get_session(conn, :presence_seed) || random_seed())

    conn
    |> put_session(:presence_seed, visitor.seed)
    |> signal(:visitorName, visitor.name)
    |> signal(:visitorColor, visitor.color)
    |> signal(:presenceStatus, "connecting")
  end

  def home(conn, _params), do: conn

  def join(conn, _params) do
    conn = normalize_tab_id(conn)
    signals = read_signals(conn)
    tab_id = Map.get(signals, "tabId") || random_seed()
    visitor = visitor_for(Map.get(signals, "visitorName") || tab_id)

    Phoenix.PubSub.subscribe(DstarDemo.PubSub, @topic)
    conn = Dstar.start_stream(conn, {:dstar_demo, :presence})

    {:ok, _} =
      Presence.track(self(), @topic, tab_id, %{
        name: Map.get(signals, "visitorName") || visitor.name,
        color: Map.get(signals, "visitorColor") || visitor.color,
        status: "active",
        last_seen: System.system_time(:second)
      })

    broadcast_activity(
      "#{Map.get(signals, "visitorName") || visitor.name} joined the room",
      "join"
    )

    case safe_presence_patch(conn, fn conn ->
           conn
           |> signal(:presenceStatus, "live")
           |> patch_presence()
         end) do
      {:ok, conn} -> presence_loop(conn)
      {:closed, conn} -> conn
    end
  end

  def ping(conn, _params) do
    signals = read_signals(conn)
    name = Map.get(signals, "visitorName", "Someone")
    color = Map.get(signals, "visitorColor", "emerald")

    broadcast_activity("#{name} sent a room ping", "ping", color)

    conn
    |> Dstar.start()
    |> Dstar.patch_elements(
      activity_row(%{message: "Ping sent — other tabs will see it.", kind: "ping", color: color}),
      selector: "#presence-activity",
      mode: :prepend
    )
  end

  @impl Dstar
  def render(assigns) do
    ~H"""
    <.demo_shell
      active="Presence"
      title="Presence room"
      eyebrow="Realtime presence"
      summary="Open this page in multiple tabs to see visitors join, leave, and send collaborative room pings through Phoenix Presence and Dstar patches."
      signals={init_signals(@conn)}
    >
      <:aside>
        <.demo_facts items={[
          "Phoenix Presence tracks each browser tab as a visitor.",
          "A long-lived Dstar stream subscribes to presence diffs.",
          "Roster, online count, and activity are patched independently.",
          "The ping button broadcasts a tiny collaborative interaction."
        ]} />
      </:aside>

      <section
        id="presence-room"
        data-init="@post('/presence/join', {retryMaxCount: Infinity})"
        data-on:online__window="@post('/presence/join', {retryMaxCount: Infinity})"
        class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_340px]"
      >
        <div class="grid gap-5">
          <div class="overflow-hidden rounded-2xl border border-emerald-300/20 bg-zinc-900 shadow-2xl shadow-emerald-950/20">
            <div class="relative p-5 sm:p-6">
              <div class="absolute inset-x-0 top-0 h-1 bg-gradient-to-r from-emerald-300 via-sky-300 to-violet-300">
              </div>
              <div class="flex flex-wrap items-start justify-between gap-4">
                <div>
                  <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">Lobby</p>
                  <h2 class="mt-2 text-2xl font-semibold text-zinc-50">Who is here right now?</h2>
                  <p class="mt-2 max-w-2xl text-sm leading-6 text-zinc-400">
                    Keep this tab open, then open another. Each tab becomes a distinct presence and receives live roster patches.
                  </p>
                </div>
                <button
                  id="presence-ping"
                  data-on:click="@post('/presence/ping')"
                  class="inline-flex items-center gap-2 rounded-md bg-emerald-300 px-4 py-2.5 text-sm font-semibold text-zinc-950 transition hover:-translate-y-0.5 hover:bg-emerald-200 focus:outline-none focus:ring-2 focus:ring-emerald-300/60"
                >
                  <.icon name="hero-sparkles-micro" class="size-4" /> Ping room
                </button>
              </div>

              <.presence_board users={[]} />
            </div>
          </div>
        </div>

        <aside class="grid gap-5">
          <div class="rounded-2xl border border-zinc-800 bg-zinc-950 p-5">
            <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">You</p>
            <div class="mt-4 flex items-center gap-3">
              <span class={[
                "grid size-11 place-items-center rounded-full text-sm font-bold text-zinc-950",
                color_class(@visitorColor)
              ]}>
                {initials(@visitorName)}
              </span>
              <div>
                <p class="font-semibold text-zinc-100">{@visitorName}</p>
                <p class="text-sm text-zinc-500">status: {@presenceStatus}</p>
              </div>
            </div>
          </div>

          <div class="rounded-2xl border border-zinc-800 bg-zinc-950 p-5">
            <div class="flex items-center justify-between gap-3">
              <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">Activity</p>
              <.pill label="broadcast" tone="info" />
            </div>
            <div id="presence-activity" class="mt-4 space-y-2">
              <.activity_row message="Waiting for visitors…" kind="idle" color="zinc" />
            </div>
          </div>
        </aside>
      </section>
    </.demo_shell>
    """
  end

  attr :users, :list, required: true

  def presence_board(assigns) do
    ~H"""
    <div id="presence-board" class="mt-6 grid gap-4 md:grid-cols-[180px_minmax(0,1fr)]">
      <div id="presence-count" class="rounded-xl border border-zinc-800 bg-zinc-950 p-4">
        <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">Online now</p>
        <p class="mt-3 text-4xl font-semibold text-zinc-50">{length(@users)}</p>
        <p class="mt-1 text-sm text-zinc-500">active browser tabs</p>
      </div>
      <div id="presence-roster" class="grid gap-2">
        <div
          :if={@users == []}
          class="rounded-xl border border-dashed border-zinc-700 bg-zinc-950/70 p-4 text-sm text-zinc-500"
        >
          Connecting to the room stream…
        </div>
        <div
          :for={user <- @users}
          class="flex items-center justify-between gap-3 rounded-xl border border-zinc-800 bg-zinc-950 p-3"
        >
          <div class="flex min-w-0 items-center gap-3">
            <span class={[
              "grid size-10 place-items-center rounded-full text-xs font-bold text-zinc-950",
              color_class(user.color)
            ]}>
              {initials(user.name)}
            </span>
            <div class="min-w-0">
              <p class="truncate text-sm font-semibold text-zinc-100">{user.name}</p>
              <p class="text-xs text-zinc-500">active now</p>
            </div>
          </div>
          <span class="size-2 rounded-full bg-emerald-300 shadow-lg shadow-emerald-300/40"></span>
        </div>
      </div>
    </div>
    """
  end

  attr :message, :string, required: true
  attr :kind, :string, required: true
  attr :color, :string, default: "emerald"

  def activity_row(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-800 bg-zinc-900 px-3 py-2 text-sm text-zinc-300">
      <span class={["mr-2 inline-block size-2 rounded-full", dot_class(@kind, @color)]}></span>{@message}
    </div>
    """
  end

  def presence_diff_summary(%{joins: joins, leaves: leaves}) do
    {count_metas(joins), count_metas(leaves)}
  end

  defp presence_loop(conn) do
    receive do
      %Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff} ->
        {joins, leaves} = presence_diff_summary(diff)
        message = "Presence changed: +#{joins} / -#{leaves}"

        case safe_presence_patch(conn, fn conn ->
               conn
               |> patch_presence()
               |> Dstar.patch_elements(
                 activity_row(%{message: message, kind: "diff", color: "sky"}),
                 selector: "#presence-activity",
                 mode: :prepend
               )
             end) do
          {:ok, conn} -> presence_loop(conn)
          {:closed, conn} -> conn
        end

      %Phoenix.Socket.Broadcast{event: "presence_activity", payload: payload} ->
        case safe_presence_patch(conn, fn conn ->
               Dstar.patch_elements(conn, activity_row(payload),
                 selector: "#presence-activity",
                 mode: :prepend
               )
             end) do
          {:ok, conn} -> presence_loop(conn)
          {:closed, conn} -> conn
        end
    after
      30_000 ->
        case Dstar.check_connection(conn) do
          {:ok, conn} -> presence_loop(conn)
          {:error, conn} -> conn
        end
    end
  end

  defp patch_presence(conn) do
    users =
      @topic
      |> Presence.list()
      |> Enum.map(fn {_key, %{metas: [meta | _]}} -> meta end)
      |> Enum.sort_by(& &1.name)

    Dstar.patch_elements(conn, presence_board(%{users: users}), selector: "#presence-board")
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

  defp read_signals(conn) do
    case Dstar.read_signals_result(conn) do
      {:ok, signals} when is_map(signals) -> signals
      _ -> %{}
    end
  end

  defp normalize_tab_id(%Plug.Conn{body_params: body_params, params: params} = conn)
       when is_map(body_params) do
    case {body_params["tabId"], body_params["tabid"]} do
      {nil, tab_id} when is_binary(tab_id) ->
        %{
          conn
          | body_params: Map.put(body_params, "tabId", tab_id),
            params: Map.put(params, "tabId", tab_id)
        }

      _ ->
        conn
    end
  end

  defp normalize_tab_id(conn), do: conn

  defp visitor_for(seed) do
    index = :erlang.phash2(seed, length(@animals))
    color = Enum.at(@colors, :erlang.phash2("color:" <> seed, length(@colors)))
    %{seed: seed, name: "Visitor #{Enum.at(@animals, index)}", color: color}
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

  defp color_class("sky"), do: "bg-sky-300"
  defp color_class("violet"), do: "bg-violet-300"
  defp color_class("amber"), do: "bg-amber-300"
  defp color_class("rose"), do: "bg-rose-300"
  defp color_class("cyan"), do: "bg-cyan-300"
  defp color_class("lime"), do: "bg-lime-300"
  defp color_class("fuchsia"), do: "bg-fuchsia-300"
  defp color_class(_), do: "bg-emerald-300"

  defp dot_class("join", color), do: color_class(color)
  defp dot_class("ping", _), do: "bg-amber-300"
  defp dot_class("diff", _), do: "bg-sky-300"
  defp dot_class(_, _), do: "bg-zinc-500"
end
