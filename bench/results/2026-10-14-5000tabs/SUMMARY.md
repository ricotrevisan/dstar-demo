# Benchmark: one inbox, LiveView vs Dstar

5000 open tabs · 50 clicks · median of 3 runs per model

### Holding tabs open

| | LiveView | Dstar, with stream | Dstar, no stream |
| --- | ---: | ---: | ---: |
| Server memory per open tab | 24.2 KB | 24.6 KB | 0.1 KB |
| Server processes per open tab | 2.0 | 1.0 | 0.0 |

### Opening a tab

| | LiveView | Dstar, with stream | Dstar, no stream |
| --- | ---: | ---: | ---: |
| Server CPU per tab opened | 1.64 ms | 1.04 ms | 0.45 ms |
| HTML per page load | 5.7 KB | 7.0 KB | 7.0 KB |

### One click

| | LiveView | Dstar, with stream | Dstar, no stream |
| --- | ---: | ---: | ---: |
| Round trip for the clicking tab, p50 | 150.82 ms | 159.34 ms | 0.72 ms |
| Round trip for the clicking tab, p95 | 198.37 ms | 214.23 ms | 1.22 ms |
| Bytes back to the clicking tab | 517 B | 569 B | 569 B |
| Until every open tab is updated, p50 | 182.74 ms | 200.59 ms | – |
| Until every open tab is updated, p95 | 214.44 ms | 230.86 ms | – |
| Bytes pushed to each other tab | 477 B | 569 B | – |
| Server CPU per click, fan-out included | 291.24 ms | 327.5 ms | 1.42 ms |

### A deploy

| | LiveView | Dstar, with stream | Dstar, no stream |
| --- | ---: | ---: | ---: |
| Connections dropped | 5000 | 5000 | 0 |
| Until every tab is back | 2530.32 ms | 1634.77 ms | – |
| Server CPU for the reconnect storm | 7021.0 ms | 3964.0 ms | 6.0 ms |
| mount runs during the storm | 5000 | 0 | 0 |
| handle_connect runs during the storm | 0 | 5000 | 0 |

## Environment

- CPU: AMD EPYC-Genoa Processor (8 logical processors, 8 schedulers)
- OS: Linux 6.12.105+deb13-amd64
- Erlang/OTP 28 (ERTS 16.1), Elixir 1.19.5
- phoenix 1.8.11, phoenix_live_view 1.1.33, bandit 1.12.4, dstar 0.2.0
- Run at 2026-10-14T11:20:33Z (UTC). Server and load generator on the same machine, over loopback.

See `bench/README.md` for what each number means and how to reproduce it.
