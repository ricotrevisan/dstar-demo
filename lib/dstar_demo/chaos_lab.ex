defmodule DstarDemo.ChaosLab do
  @moduledoc """
  The pure model behind `/explained/lab`: six browser tabs open on the same
  inbox page, once as a LiveView app and once as a Dstar app, and what each
  model has to do when something happens to them.

  Nothing here is measured; everything is *counted* from the code paths each
  model runs. A counter only moves when the corresponding callback would run:

    * `mounts` — `mount/3` (LiveView) or `mount/2` (Dstar) executions
    * `auth`   — places a session was checked: router plugs, or `on_mount`
    * `copies` — copies of page state held in server memory between events
    * `conns`  — open WebSockets (LiveView) or open SSE streams (Dstar)
    * `msgs`   — process-to-process messages (PubSub fan-out, send_update…)

  Both pages show a live unread badge, so both hold one long-lived
  connection per tab. That is the fair comparison — a Dstar page without a
  stream would hold none.
  """

  @users ~w(Ada Ada Ben Cy Dee Eve)
  @tunnel_tab 4
  @refill 9

  @type world :: :lv | :ds

  def new do
    tabs =
      @users
      |> Enum.with_index(1)
      |> Enum.map(fn {user, id} ->
        %{
          id: id,
          user: user,
          lv: :live,
          ds: :live,
          lv_badge: @refill,
          ds_badge: @refill,
          pending: 0
        }
      end)

    n = length(tabs)

    %{
      tabs: tabs,
      # Opening the page, per tab — LiveView: GET (plugs + mount), then the
      # socket connects (on_mount + mount again). Dstar: GET (plugs + mount),
      # then data-init's connect() POST (plugs, handle_connect, no mount).
      lv: %{db: @refill, mounts: 2 * n, auth: 2 * n, copies: n, conns: n, msgs: 0},
      ds: %{db: @refill, mounts: n, auth: 2 * n, copies: 0, conns: n, msgs: 0},
      log: [
        entry(0, "Six tabs opened the inbox",
          lv:
            "Each tab: one HTTP render, then a socket and a second mount/3. Six processes now hold a copy of the page.",
          ds:
            "Each tab: one HTTP render, then a connect() POST through the same plugs. handle_connect/2 runs, mount/2 does not. Nothing is copied."
        )
      ],
      seq: 0,
      flash: %{lv: [], ds: []},
      cursor: 0
    }
  end

  def tunnel_tab, do: @tunnel_tab

  # ── Actions ───────────────────────────────────────────────────────────

  def apply_action(state, "click") do
    case next_actor(state) do
      nil -> state
      tab -> click(state, tab)
    end
  end

  def apply_action(state, "deploy") do
    lv_live = ids(state, :lv, :live)
    ds_live = ids(state, :ds, :live)
    nl = length(lv_live)
    nd = length(ds_live)

    state
    |> bump(:lv, mounts: nl, auth: nl)
    |> bump(:ds, auth: nd)
    |> refresh_badges(:lv, lv_live)
    |> refresh_badges(:ds, ds_live)
    |> log("Someone deployed",
      lv:
        "All #{nl} sockets dropped. All #{nl} reconnected at once: #{nl} on_mount checks, #{nl} more mount/3 calls, #{nl} copies rebuilt from the database.",
      ds:
        "All #{nd} streams dropped. All #{nd} re-POSTed connect() through the router plugs. handle_connect/2 re-read the badge, and mount/2 did not run. Pages without a stream wouldn't have noticed."
    )
    |> flash(lv_live, ds_live)
  end

  def apply_action(state, "tunnel") do
    tab = Enum.find(state.tabs, &(&1.id == @tunnel_tab))

    if tab.lv == :offline, do: leave_tunnel(state, tab), else: enter_tunnel(state, tab)
  end

  def apply_action(state, "revoke") do
    ada = for t <- state.tabs, t.user == "Ada", do: t.id
    lv_hit = Enum.filter(ada, &(status(state, &1, :lv) != :out))
    ds_hit = Enum.filter(ada, &(status(state, &1, :ds) != :out))

    if lv_hit == [] and ds_hit == [] do
      state
    else
      nl = length(Enum.filter(lv_hit, &(status(state, &1, :lv) == :live)))
      nd = length(Enum.filter(ds_hit, &(status(state, &1, :ds) == :live)))

      state
      |> set_status(:lv, lv_hit, :out)
      |> set_status(:ds, ds_hit, :out)
      |> bump(:lv, auth: nl, copies: -nl, conns: -nl, msgs: 1)
      |> bump(:ds, auth: nd, conns: -nd, msgs: 1)
      |> log("Ada's session was revoked from another device",
        lv:
          "phx.gen.auth broadcasts \"disconnect\" on Ada's live_socket_id. Ada's #{nl} sockets drop, reconnect, and on_mount sends them to log in. Without that broadcast, both processes would keep serving Ada.",
        ds:
          "Ada's next click would fail the plugs. Ada's #{nd} open streams were authorized when they opened, so they are told to stop too: a broadcast to Ada's user topic, then handle_info returns {:halt, conn}. The reconnect is refused by the same plugs."
      )
      |> flash(lv_hit, ds_hit)
    end
  end

  def apply_action(_state, "reset"), do: new()
  def apply_action(state, _unknown), do: state

  # ── Clicks ────────────────────────────────────────────────────────────

  defp click(state, tab) do
    {state, lv_text, lv_flash} = lv_click(state, tab)
    {state, ds_text, ds_flash} = ds_click(state, tab)

    state
    |> Map.update!(:cursor, &(&1 + 1))
    |> log("#{tab.user} (tab #{tab.id}) marked a message read", lv: lv_text, ds: ds_text)
    |> flash(lv_flash, ds_flash)
  end

  defp lv_click(state, %{id: id, user: user}) do
    case status(state, id, :lv) do
      :live ->
        others = ids(state, :lv, :live) -- [id]
        n = length(others)
        state = state |> mark_read(:lv) |> bump(:lv, msgs: n)
        state = refresh_badges(state, :lv, [id | others])

        {state,
         "The event rides #{user}'s open socket. No auth check, because the socket was checked when it connected. #{user}'s process updates its copy, then PubSub tells #{n} other processes to update theirs.",
         [id | others]}

      :offline ->
        {state,
         "#{user} is in a tunnel. The socket is down, so LiveView doesn't send the event. The click is lost and the page shows it is disconnected.",
         []}
    end
  end

  defp ds_click(state, %{id: id, user: user}) do
    case status(state, id, :ds) do
      :live ->
        others = ids(state, :ds, :live) -- [id]
        n = length(others)
        state = state |> mark_read(:ds) |> bump(:ds, auth: 1, msgs: n)
        state = refresh_badges(state, :ds, [id | others])

        {state,
         "An ordinary POST: the router plugs check #{user}'s session, the handler writes to the database, and the response patches that tab's #list and #sidebar. PubSub nudges #{n} open streams, and each re-reads the badge from the database.",
         [id | others]}

      :offline ->
        state = update_tab(state, id, &%{&1 | pending: &1.pending + 1})

        {state,
         "#{user}'s POST can't reach the server. Datastar retries it after 1s, 2s, 4s… (up to 10 tries). It lands once the tab is back.",
         []}
    end
  end

  # ── The tunnel ────────────────────────────────────────────────────────

  defp enter_tunnel(state, tab) do
    state
    |> set_status(:lv, [tab.id], :offline)
    |> set_status(:ds, [tab.id], :offline)
    |> bump(:lv, copies: -1, conns: -1)
    |> bump(:ds, conns: -1)
    |> log("#{tab.user} (tab #{tab.id}) went into a tunnel",
      lv:
        "The socket drops. When the heartbeat gives up, the process and its copy of the page go with it.",
      ds:
        "The stream drops. There was no copy to lose. The badge stays as it was until the tab is back."
    )
    |> flash([tab.id], [tab.id])
  end

  defp leave_tunnel(state, tab) do
    pending = tab.pending

    state =
      state
      |> set_status(:lv, [tab.id], :live)
      |> set_status(:ds, [tab.id], :live)
      |> bump(:lv, auth: 1, mounts: 1, copies: 1, conns: 1)
      |> bump(:ds, auth: 1 + pending, conns: 1)
      |> update_tab(tab.id, &%{&1 | pending: 0})

    state = Enum.reduce(List.duplicate(:ds, pending), state, fn w, s -> mark_read(s, w) end)

    state =
      state
      |> refresh_badges(:lv, ids(state, :lv, :live))
      |> refresh_badges(:ds, ids(state, :ds, :live))

    retried =
      if pending > 0,
        do:
          " The tab's #{pending} retried click#{if pending > 1, do: "s", else: ""} went through the plugs and landed.",
        else: ""

    state
    |> log("#{tab.user} (tab #{tab.id}) came out of the tunnel",
      lv:
        "The socket rejoins. A new process runs on_mount and mount/3 again and rebuilds the copy from scratch.",
      ds:
        "connect() re-POSTs through the plugs, and handle_connect/2 re-reads the badge." <>
          retried
    )
    |> flash([tab.id], [tab.id])
  end

  # ── Helpers ───────────────────────────────────────────────────────────

  # Round-robin over everyone still logged in somewhere, tunnel included —
  # a click from inside the tunnel is the interesting case.
  defp next_actor(state) do
    candidates = Enum.reject(state.tabs, &(&1.lv == :out and &1.ds == :out))

    case candidates do
      [] -> nil
      list -> Enum.at(list, rem(state.cursor, length(list)))
    end
  end

  defp mark_read(state, world) do
    update_in(state, [world, :db], fn
      n when n > 1 -> n - 1
      _ -> @refill
    end)
  end

  defp refresh_badges(state, world, tab_ids) do
    db = state[world].db
    key = if world == :lv, do: :lv_badge, else: :ds_badge

    Enum.reduce(tab_ids, state, fn id, s -> update_tab(s, id, &Map.put(&1, key, db)) end)
  end

  defp status(state, id, world), do: Enum.find(state.tabs, &(&1.id == id))[world]

  defp ids(state, world, wanted), do: for(t <- state.tabs, t[world] == wanted, do: t.id)

  defp set_status(state, world, tab_ids, value) do
    Enum.reduce(tab_ids, state, fn id, s -> update_tab(s, id, &Map.put(&1, world, value)) end)
  end

  defp update_tab(state, id, fun) do
    %{state | tabs: Enum.map(state.tabs, fn t -> if t.id == id, do: fun.(t), else: t end)}
  end

  defp bump(state, world, changes) do
    Map.update!(state, world, fn counters ->
      Enum.reduce(changes, counters, fn {k, v}, acc -> Map.update!(acc, k, &max(&1 + v, 0)) end)
    end)
  end

  defp flash(state, lv_ids, ds_ids), do: %{state | flash: %{lv: lv_ids, ds: ds_ids}}

  defp log(state, title, texts) do
    seq = state.seq + 1
    %{state | seq: seq, log: Enum.take([entry(seq, title, texts) | state.log], 6)}
  end

  defp entry(seq, title, lv: lv, ds: ds), do: %{seq: seq, title: title, lv: lv, ds: ds}
end
