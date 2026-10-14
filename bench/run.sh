#!/usr/bin/env bash
# Reproduce the LiveView vs Dstar inbox benchmark.
#
#   ./run.sh                          # 1000 tabs, 100 clicks, 3 repeats
#   TABS=5000 CLICKS=50 REPEAT=5 ./run.sh
#
# Every model gets a freshly started server for every repeat, and the
# models are interleaved (lv, dstar, nostream, lv, …) so machine noise is
# spread across all three instead of landing on one.
set -euo pipefail
cd "$(dirname "$0")"

export MIX_ENV=prod
export BENCH_PORT="${BENCH_PORT:-4100}"
TABS="${TABS:-1000}"
CLICKS="${CLICKS:-100}"
REPEAT="${REPEAT:-3}"
OUT="${OUT:-results/$(date -u +%Y-%m-%d)-${TABS}tabs}"

need=$((TABS * 4 + 256))
if [ "$(ulimit -n)" != "unlimited" ] && [ "$(ulimit -n)" -lt "$need" ]; then
  echo "ulimit -n is $(ulimit -n); need at least $need for $TABS tabs (try: ulimit -n $need)" >&2
  exit 1
fi

if curl -sf "http://127.0.0.1:$BENCH_PORT/bench/health" >/dev/null 2>&1; then
  echo "something is already listening on port $BENCH_PORT; stop it or set BENCH_PORT" >&2
  exit 1
fi

mix deps.get >/dev/null
mix compile >/dev/null
mkdir -p "$OUT"

for repeat in $(seq 1 "$REPEAT"); do
  for model in liveview dstar dstar_nostream; do
    echo "== repeat $repeat/$REPEAT · $model · $TABS tabs" >&2
    mix bench.server >"$OUT/server-$model-$repeat.log" 2>&1 &
    server=$!
    trap 'kill "$server" 2>/dev/null || true' EXIT

    for _ in $(seq 1 120); do
      curl -sf "http://127.0.0.1:$BENCH_PORT/bench/health" >/dev/null 2>&1 && break
      sleep 0.5
    done

    mix bench.client --model "$model" --tabs "$TABS" --clicks "$CLICKS" \
      --out "$OUT/$model-$repeat.json"

    kill "$server"
    wait "$server" 2>/dev/null || true
    trap - EXIT
  done
done

mix bench.report "$OUT"
cat "$OUT/SUMMARY.md"
