# Benchmark: one inbox, LiveView vs Dstar

The explainers at `/explained/dx` and `/explained/lab` *count* what each model
does: mounts, auth checks, copies of page state. This benchmark *measures*
what that costs a server: memory, CPU, bytes and time.

It's built so anyone can rerun it and get comparable numbers.

## Run it

Requirements: Elixir ≥ 1.15 with Erlang/OTP ≥ 26, `curl`, and Linux or macOS.

```bash
cd bench
./run.sh                               # 1000 tabs, 100 clicks, 3 repeats
TABS=5000 CLICKS=50 REPEAT=3 ./run.sh  # bigger
```

Results land in `results/<date>-<tabs>tabs/`:

- one JSON file per model and repeat, with every raw number
- `SUMMARY.md`: the median across repeats, as tables
- `summary.json`: the same medians, for the lab page

`run.sh` checks `ulimit -n` (each tab needs a few file descriptors on each
side) and refuses to start if the port is busy. A full 1000-tab run takes a
few minutes.

**Share your numbers:** commit your `results/<dir>/` (logs are ignored) and
open a PR. Different hardware is the point.

## What runs

There are two OS processes, so the load generator's work never shows up in
the server's numbers:

| | command | what it is |
| --- | --- | --- |
| server | `mix bench.server` | a minimal Phoenix app with the same inbox built twice, plus a `/bench/*` control plane |
| client | `mix bench.client` | thousands of simulated browser tabs, built with Mint and Mint.WebSocket |

`run.sh` starts a **fresh server for every model and repeat**, and
interleaves the models (LiveView, Dstar, Dstar without a stream, then
again), so machine noise is spread across all three.

### The three models

| model | page | long-lived connection per tab |
| --- | --- | --- |
| `liveview` | `InboxLive` at `/lv/inbox` | one WebSocket (LiveView join) |
| `dstar` | `InboxPage` at `/ds/inbox` | one SSE stream (`data-init={connect()}`) |
| `dstar_nostream` | the same `InboxPage` | none: the tab loads the page and only POSTs clicks |

Both pages render **the same markup** (`InboxComponents`): a sidebar badge
and 20 messages. They sit behind **the same pipeline** (session, CSRF, root
layout). Clicking toggles a message's read state in a shared ETS table and
broadcasts on PubSub. Every open tab then updates the row and the badge.

### What the simulated tabs do

- **LiveView tab:** it speaks the `phoenix_live_view.js` wire protocol
  (vsn 2.0.0). It GETs the page, opens `/live/websocket`, sends `phx_join`
  with the page's session and static tokens, and sends heartbeats. Clicks
  are `event` messages, and the reply carries the diff. After a drop it
  reconnects and rejoins without a new GET, like the JS client.
- **Dstar tab:** it sends the same headers as Datastar 1.0's fetch. It GETs
  the page, then POSTs to the page path for the stream. The stream counts as
  open once `handle_connect/2`'s first patch arrives. Clicks are POSTs to
  `/_event/read:<id>`. After a drop it re-POSTs the stream.

### Phases, per model

1. **Warm-up:** five throwaway tabs open, click and close, so code loading
   and caches are paid for before the baseline.
2. **Open:** N tabs load and connect, 100 at a time.
3. **Idle:** wait 2 s, force a GC, and read retained server memory.
4. **Clicks:** K clicks, one at a time, from a random tab on a random
   message. The sequence is seeded, so all models get the same one. For
   each click, the runner measures the clicker's round trip and the time
   until *every* tab has received the update.
5. **Deploy:** `POST /bench/drop` kills every long-lived connection's owner
   process at once, as a deploy would. The runner measures the time until
   all of this run's tabs are back, and the server CPU spent getting there.

## What the numbers mean

| row | how it's measured |
| --- | --- |
| Server memory per open tab | (`:erlang.memory(:total)` after open − baseline) ÷ N, both after a forced GC |
| Server processes per open tab | Δ process count ÷ N |
| Server CPU per tab opened | Δ `:erlang.statistics(:runtime)` (all schedulers) ÷ N, over the open phase |
| HTML per page load | body size of the GET |
| Round trip for the clicking tab | LiveView: `event` sent → `phx_reply` received. Dstar: TCP connect → last byte of the POST response |
| Bytes back to the clicking tab | that reply frame or response body |
| Until every open tab is updated | click start → the last tab's first push |
| Bytes pushed to each other tab | push bytes ÷ (tabs × clicks) |
| Server CPU per click | Δ runtime ÷ clicks; includes the PubSub fan-out to all N tabs |
| Deploy: until every tab is back | drop → the last tab back (LiveView: join reply; Dstar: first patch) |
| Deploy: server CPU | Δ runtime from the drop until all are back |
| mount / handle_connect runs | server-side counters, so you can see *what* reran |

All server numbers come from the server VM itself, through `/bench/metrics`.

## Fairness: choices that favour one side

**In LiveView's favour:**

- `InboxLive` uses **streams**, so the process doesn't keep the list, and
  the badge lives **in the same LiveView**. That's the cheapest LiveView
  shape. The explainer's layout sidebar would be a second, nested LiveView
  per tab.

**Against Dstar:**

- Every Dstar click opens a **new TCP connection**. A browser on keep-alive
  or HTTP/2 would reuse one, so Dstar's click round trip is an upper bound.

**Neutral by design:**

- No auth on either side, because it would cost the same plugs on both. The
  lab page counts auth paths instead.
- Reconnects happen **at once, without backoff or jitter**, on both sides.
  Real clients spread them out: LiveView with its reconnect schedule,
  Datastar with 1 s, 2 s, 4 s… This measures the worst-case storm.
- Request logging is off for both (`config :logger, level: :warning`).

## Limitations to keep in mind

- **One machine, loopback, HTTP/1.1, no TLS.** The load generator competes
  with the server for CPU. Latencies are therefore pessimistic in absolute
  terms but comparable between models. The server's CPU and memory numbers
  are its own.
- **Memory is read after a forced GC.** It shows what each tab *retains*,
  not the peak while busy.
- **A dead SSE stream lingers.** A Dstar stream only learns its client is
  gone on its next write or at its 30 s idle check. The runner nudges the
  inbox after warm-up so those streams exit before the baseline. In
  production, the same thing makes a closed tab's stream outlive the tab by
  up to 30 s. A LiveView process ends as soon as its socket does.
- **No HTTP/2.** Dstar's extra request per click would be cheaper with it.
  Bandit supports it, but the client here doesn't.

## Files

```
bench/
├── run.sh                         # the whole experiment
├── lib/explainer_bench_web/       # the server under test
│   ├── inbox_live.ex              # LiveView model
│   ├── inbox_page.ex              # Dstar model
│   ├── inbox_components.ex        # markup both render
│   └── control_controller.ex      # /bench/health, env, metrics, drop
├── lib/explainer_bench/client/    # the load generator
│   ├── live_view_tab.ex
│   ├── dstar_tab.ex
│   └── runner.ex                  # phases and arithmetic
├── lib/mix/tasks/                 # bench.server, bench.client, bench.report
└── results/                       # committed results, one dir per run
```

The versions are pinned to what dstar-demo ships (Phoenix 1.8.11,
LiveView 1.1.33, Bandit 1.12.4, dstar `91db2de`), so the numbers describe
the stack the explainer pages run on.
