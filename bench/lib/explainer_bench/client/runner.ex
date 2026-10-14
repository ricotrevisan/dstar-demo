defmodule ExplainerBench.Client.Runner do
  @moduledoc """
  Drives one model through four phases against a freshly started server and
  returns plain data for JSON:

    * **open**   — N tabs load the page and (if the model has one) connect.
    * **idle**   — let it settle, then read retained server memory.
    * **clicks** — K clicks, one at a time, from random tabs on random
      messages (seeded, so every model gets the same sequence). For each:
      the clicker's round trip, and how long until *every* tab got the update.
    * **deploy** — the server drops every long-lived connection at once;
      time until all of them are back, and what that cost the server.

  Server numbers come from the server VM itself (`/bench/metrics`), so the
  load generator's own work never shows up in them.
  """

  alias ExplainerBench.Client.{DstarTab, HTTP, LiveViewTab}

  @models ~w(liveview dstar dstar_nostream)
  @fanout_timeout_ms 15_000
  @deploy_timeout_ms 120_000

  def models, do: @models

  def run(%{model: model} = opts) when model in @models do
    port = opts.port
    :rand.seed(:exsss, {2026, 10, 14})

    env = HTTP.json!(port, "GET", "/bench/env")
    warm_up(model, port)
    baseline = metrics(port, gc: true)

    tabs =
      for id <- 1..opts.tabs do
        {:ok, pid} = start_tab(model, %{id: id, port: port, coordinator: self()})
        {id, pid}
      end

    log("#{model}: opening #{opts.tabs} tabs")
    {open_us, html_bytes} = timed(fn -> open_all(model, tabs, opts.concurrency) end)
    after_open = metrics(port)

    Process.sleep(opts.settle_ms)
    idle = metrics(port, gc: true)

    log("#{model}: #{opts.clicks} clicks")
    before_clicks = metrics(port)
    clicks = Enum.map(1..opts.clicks, fn _ -> click_once(model, tabs, port) end)
    after_clicks = metrics(port)

    log("#{model}: deploy")
    deploy = deploy(port, length(tabs))
    after_deploy = metrics(port, gc: true)

    n = opts.tabs

    %{
      model: model,
      params: Map.take(opts, [:tabs, :clicks, :concurrency, :settle_ms]),
      env: Map.merge(env, client_env()),
      open: %{
        wall_ms: ms(open_us),
        server_cpu_ms: after_open["runtime_ms"] - baseline["runtime_ms"],
        server_cpu_ms_per_tab: per(after_open["runtime_ms"] - baseline["runtime_ms"], n),
        html_bytes_per_tab: div(html_bytes, n),
        callbacks: stats_delta(baseline, after_open)
      },
      idle: %{
        memory_bytes_per_tab: per(idle["memory"]["total"] - baseline["memory"]["total"], n),
        process_memory_bytes_per_tab:
          per(idle["memory"]["processes"] - baseline["memory"]["processes"], n),
        processes_per_tab: per(idle["process_count"] - baseline["process_count"], n),
        open_connections: idle["conns"]["liveview"] + idle["conns"]["dstar"],
        memory_total_mb: Float.round(idle["memory"]["total"] / 1_048_576, 1),
        baseline_memory_total_mb: Float.round(baseline["memory"]["total"] / 1_048_576, 1)
      },
      clicks: summarize_clicks(clicks, before_clicks, after_clicks, n),
      deploy:
        Map.merge(deploy, %{
          memory_bytes_per_tab_after:
            per(after_deploy["memory"]["total"] - baseline["memory"]["total"], n)
        })
    }
  end

  # ── Phases ────────────────────────────────────────────────────────────

  # The first requests load code and fill caches the server keeps forever.
  # Pay for that before the baseline, with throwaway tabs that then close.
  defp warm_up(model, port) do
    tabs =
      for id <- 1..5 do
        {:ok, pid} = start_tab(model, %{id: -id, port: port, coordinator: self()})
        {-id, pid}
      end

    open_all(model, tabs, 5)
    click_once(model, tabs, port)
    Enum.each(tabs, fn {_id, pid} -> GenServer.stop(pid) end)

    # A Dstar stream only learns its client is gone when it next writes (or
    # at its 30s idle check). Change the inbox once so the warm-up streams
    # write, fail and exit before the baseline — otherwise they'd be counted.
    nudge(port)
    Process.sleep(1_000)
    flush()
  end

  defp nudge(port) do
    page = ExplainerBench.Client.Page.load(port, "/ds/inbox")

    {:ok, %{status: 200}} =
      HTTP.post_json(
        port,
        "/ds/inbox/_event/" <> URI.encode_www_form("read:1"),
        %{csrf: page.csrf},
        [
          {"cookie", page.cookie},
          {"accept", "text/event-stream, text/html, application/json"},
          {"datastar-request", "true"}
        ]
      )
  end

  defp start_tab("liveview", opts), do: LiveViewTab.start_link(opts)
  defp start_tab(_dstar, opts), do: DstarTab.start_link(opts)

  defp open_all(model, tabs, concurrency) do
    tabs
    |> Task.async_stream(fn {_id, pid} -> open(model, pid) end,
      max_concurrency: concurrency,
      timeout: :infinity
    )
    |> Enum.reduce(0, fn {:ok, {:ok, %{html_bytes: b}}}, acc -> acc + b end)
  end

  defp open("liveview", pid), do: LiveViewTab.open(pid)
  defp open("dstar", pid), do: DstarTab.open(pid, true)
  defp open("dstar_nostream", pid), do: DstarTab.open(pid, false)

  defp click_once(model, tabs, port) do
    {_id, pid} = Enum.random(tabs)
    message_id = :rand.uniform(20)
    flush()

    started = now()
    {:ok, %{micros: micros, bytes: bytes}} = send_click(model, pid, port, message_id)

    fanout =
      if model == "dstar_nostream",
        do: nil,
        else: await_fanout(length(tabs), started)

    %{micros: micros, bytes: bytes, fanout: fanout}
  end

  defp send_click("liveview", pid, _port, message_id), do: LiveViewTab.click(pid, message_id)

  defp send_click(_dstar, pid, port, message_id) do
    %{cookie: cookie, csrf: csrf} = DstarTab.credentials(pid)

    {:ok, %{status: 200, body: body, micros: micros}} =
      HTTP.post_json(
        port,
        "/ds/inbox/_event/" <> URI.encode_www_form("read:#{message_id}"),
        %{csrf: csrf},
        [
          {"cookie", cookie},
          {"accept", "text/event-stream, text/html, application/json"},
          {"datastar-request", "true"}
        ]
      )

    {:ok, %{micros: micros, bytes: byte_size(body)}}
  end

  # Every tab must report at least one push stamped after the click began.
  defp await_fanout(n, started) do
    deadline = System.monotonic_time(:millisecond) + @fanout_timeout_ms
    collect_fanout(n, started, deadline, %{}, 0)
  end

  defp collect_fanout(n, started, _deadline, seen, bytes) when map_size(seen) == n do
    %{complete_us: Enum.max(Map.values(seen)) - started, bytes: bytes, tabs: n}
  end

  defp collect_fanout(n, started, deadline, seen, bytes) do
    wait = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:push, id, at, b} when at >= started ->
        collect_fanout(n, started, deadline, Map.put_new(seen, id, at), bytes + b)

      {:push, _id, _at, _b} ->
        collect_fanout(n, started, deadline, seen, bytes)
    after
      wait -> %{complete_us: nil, bytes: bytes, tabs: map_size(seen), timed_out: true}
    end
  end

  defp deploy(port, n) do
    flush()
    before = metrics(port)
    started = now()
    %{"dropped" => dropped} = HTTP.json!(port, "POST", "/bench/drop")
    # Wait for this run's own tabs; `dropped` can include connections whose
    # client already left (see warm_up/2).
    times =
      await_reconnects(
        min(dropped, n),
        System.monotonic_time(:millisecond) + @deploy_timeout_ms,
        []
      )

    after_storm = metrics(port)
    reconnect_ms = times |> Enum.map(&ms(&1 - started)) |> Enum.sort()

    %{
      dropped: dropped,
      reconnected: length(times),
      all_back_ms: List.last(reconnect_ms),
      reconnect_p50_ms: percentile(reconnect_ms, 0.5),
      server_cpu_ms: after_storm["runtime_ms"] - before["runtime_ms"],
      server_cpu_ms_per_tab:
        per(after_storm["runtime_ms"] - before["runtime_ms"], max(dropped, 1)),
      callbacks: stats_delta(before, after_storm),
      tabs: n
    }
  end

  defp await_reconnects(0, _deadline, acc), do: acc

  defp await_reconnects(left, deadline, acc) do
    wait = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:reconnected, _id, at} -> await_reconnects(left - 1, deadline, [at | acc])
    after
      wait -> acc
    end
  end

  # ── Summaries ─────────────────────────────────────────────────────────

  defp summarize_clicks(clicks, before, after_clicks, n) do
    latencies = clicks |> Enum.map(&ms(&1.micros)) |> Enum.sort()
    fanouts = clicks |> Enum.map(& &1.fanout) |> Enum.reject(&is_nil/1)

    complete =
      fanouts
      |> Enum.map(& &1.complete_us)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&ms/1)
      |> Enum.sort()

    k = length(clicks)

    %{
      clicker_round_trip_ms: %{
        p50: percentile(latencies, 0.5),
        p95: percentile(latencies, 0.95),
        p99: percentile(latencies, 0.99)
      },
      clicker_response_bytes: div(Enum.sum(Enum.map(clicks, & &1.bytes)), k),
      all_tabs_updated_ms:
        if(fanouts == [],
          do: nil,
          else: %{
            p50: percentile(complete, 0.5),
            p95: percentile(complete, 0.95),
            timeouts: length(fanouts) - length(complete)
          }
        ),
      push_bytes_per_tab:
        if(fanouts == [],
          do: nil,
          else: per(Enum.sum(Enum.map(fanouts, & &1.bytes)), length(fanouts) * n)
        ),
      server_cpu_ms_per_click: per(after_clicks["runtime_ms"] - before["runtime_ms"], k)
    }
  end

  # ── Helpers ───────────────────────────────────────────────────────────

  defp metrics(port, opts \\ []) do
    HTTP.json!(port, "GET", "/bench/metrics" <> if(opts[:gc], do: "?gc=1", else: ""))
  end

  defp stats_delta(a, b) do
    Map.new(b["stats"], fn {k, v} -> {k, v - a["stats"][k]} end)
  end

  defp client_env do
    cpu =
      case File.read("/proc/cpuinfo") do
        {:ok, info} ->
          case Regex.run(~r/model name\s*:\s*(.+)/, info),
            do: (
              [_, m] -> String.trim(m)
              _ -> "unknown"
            )

        _ ->
          case System.cmd("sysctl", ["-n", "machdep.cpu.brand_string"], stderr_to_stdout: true) do
            {out, 0} -> String.trim(out)
            _ -> "unknown"
          end
      end

    {os, _} = System.cmd("uname", ["-sr"])
    %{cpu: cpu, os: String.trim(os), run_at: DateTime.utc_now() |> DateTime.truncate(:second)}
  end

  defp timed(fun) do
    started = now()
    result = fun.()
    {now() - started, result}
  end

  defp flush do
    receive do
      {:push, _, _, _} -> flush()
      {:reconnected, _, _} -> flush()
    after
      0 -> :ok
    end
  end

  defp percentile([], _p), do: nil
  defp percentile(sorted, p), do: Enum.at(sorted, max(ceil(p * length(sorted)) - 1, 0))

  defp per(value, n), do: Float.round(value / n, 2)
  defp ms(us), do: Float.round(us / 1000, 2)
  defp now, do: System.monotonic_time(:microsecond)
  defp log(text), do: IO.puts(:stderr, "[bench] " <> text)
end
