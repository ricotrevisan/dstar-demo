# Benchmark: one inbox, LiveView vs Dstar

1000 open tabs · 100 clicks · median of 3 runs per model

### Holding tabs open

| | LiveView | Dstar, with stream | Dstar, no stream |
| --- | ---: | ---: | ---: |
| Server memory per open tab | 23.6 KB | 24.4 KB | 0.0 KB |
| Server processes per open tab | 2.0 | 1.0 | 0.0 |

### Opening a tab

| | LiveView | Dstar, with stream | Dstar, no stream |
| --- | ---: | ---: | ---: |
| Server CPU per tab opened | 1.49 ms | 0.85 ms | 0.49 ms |
| HTML per page load | 5.7 KB | 7.0 KB | 7.0 KB |

### One click

| | LiveView | Dstar, with stream | Dstar, no stream |
| --- | ---: | ---: | ---: |
| Round trip for the clicking tab, p50 | 16.43 ms | 22.92 ms | 0.86 ms |
| Round trip for the clicking tab, p95 | 26.82 ms | 35.34 ms | 1.38 ms |
| Bytes back to the clicking tab | 516 B | 569 B | 569 B |
| Until every open tab is updated, p50 | 25.34 ms | 31.97 ms | – |
| Until every open tab is updated, p95 | 34.12 ms | 42.09 ms | – |
| Bytes pushed to each other tab | 477 B | 569 B | – |
| Server CPU per click, fan-out included | 54.93 ms | 68.5 ms | 1.2 ms |

### A deploy

| | LiveView | Dstar, with stream | Dstar, no stream |
| --- | ---: | ---: | ---: |
| Connections dropped | 1000 | 1000 | 0 |
| Until every tab is back | 265.04 ms | 214.47 ms | – |
| Server CPU for the reconnect storm | 925.0 ms | 354.0 ms | 4.0 ms |
| mount runs during the storm | 1000 | 0 | 0 |
| handle_connect runs during the storm | 0 | 1000 | 0 |

## Environment

- CPU: AMD EPYC-Genoa Processor (8 logical processors, 8 schedulers)
- OS: Linux 6.12.105+deb13-amd64
- Erlang/OTP 28 (ERTS 16.1), Elixir 1.19.5
- phoenix 1.8.11, phoenix_live_view 1.1.33, bandit 1.12.4, dstar 0.2.0
- Run at 2026-10-14T11:15:51Z (UTC). Server and load generator on the same machine, over loopback.

See `bench/README.md` for what each number means and how to reproduce it.
