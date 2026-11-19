#!/usr/bin/env bash
# Checks the render path stays inside its time budget: the status line redraws every second,
# so one render must take well under BYTEK_RENDER_BUDGET_MS (default 50 ms) on average.
# Renders every state, plus a long text that gets cut, through the real bin/bytek.
# BYTEK_SKIP_SPEED=1 skips the budget (e.g. under kcov, whose tracing slows everything down).
# Usage: tests/speed.sh

export LC_ALL=en_US.UTF-8
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BYTEK="$ROOT/bin/bytek"
export BYTEK_HOME
BYTEK_HOME=$(mktemp -d)
trap 'rm -rf "$BYTEK_HOME"' EXIT

budget=${BYTEK_RENDER_BUDGET_MS:-50}
rounds=${BYTEK_SPEED_ROUNDS:-10}

if [ "${BYTEK_SKIP_SPEED:-}" = 1 ]; then
  echo "skip: render budget not checked (BYTEK_SKIP_SPEED=1)"
  exit 0
fi

# Renders every state $rounds times; prints the number of renders.
render_all() {
  local face state i n=0
  for face in "$ROOT"/faces/*; do
    state=${face##*/}
    "$BYTEK" set "$state" "src/a/rather/long/path/that/gets/cut/in/a/narrow/window.ts" --progress 3/5
    i=0
    while [ "$i" -lt "$rounds" ]; do
      printf '{"session_id":"default"}' | COLUMNS=60 "$BYTEK" render >/dev/null
      i=$((i + 1)) n=$((n + 1))
    done
  done
  echo "$n" > "$BYTEK_HOME/count"
}

# bash's own `time` gives milliseconds on bash 3.2 too, without extra tools.
TIMEFORMAT=%3R
seconds=$( { time render_all; } 2>&1 )
count=$(cat "$BYTEK_HOME/count")
# The total includes `bytek set` once per state; it's small, and counting it keeps the check strict.
avg=$(awk -v s="$seconds" -v n="$count" 'BEGIN { printf "%.1f", s * 1000 / n }')

if awk -v a="$avg" -v b="$budget" 'BEGIN { exit !(a <= b) }'; then
  echo "ok: render takes ${avg} ms on average over $count renders (budget ${budget} ms)"
else
  echo "FAIL speed: render takes ${avg} ms on average over $count renders, over the ${budget} ms budget"
  exit 1
fi
