#!/usr/bin/env bats
# The render path stays inside its time budget: the status line redraws every second, so one
# render must take well under BYTEK_RENDER_BUDGET_MS (default 50 ms) on average. Renders every
# state, with a long text that gets cut, through the real bin/bytek.
# BYTEK_SKIP_SPEED=1 skips it (e.g. under kcov, whose tracing slows everything down).

load helpers

# Renders every state $1 times; writes the number of renders to $TMP/count.
render_all() {
  local face i n=0
  for face in "$ROOT"/faces/*; do
    "$BYTEK" set "${face##*/}" "src/a/rather/long/path/that/gets/cut/in/a/narrow/window.ts" --progress 3/5
    i=0
    while [ "$i" -lt "$1" ]; do
      COLUMNS=60 render >/dev/null
      i=$((i + 1)) n=$((n + 1))
    done
  done
  echo "$n" >"$TMP/count"
}

@test "a render takes less than the budget on average" {
  [ "${BYTEK_SKIP_SPEED:-}" = 1 ] && skip "render budget not checked (BYTEK_SKIP_SPEED=1)"
  local budget=${BYTEK_RENDER_BUDGET_MS:-50} seconds avg TIMEFORMAT=%3R
  # bash's own `time` gives milliseconds on bash 3.2 too, without extra tools.
  seconds=$({ time render_all "${BYTEK_SPEED_ROUNDS:-10}"; } 2>&1)
  avg=$(awk -v s="$seconds" -v n="$(cat "$TMP/count")" 'BEGIN { printf "%.1f", s * 1000 / n }')
  # A note for tests/run.sh's summary (and the CI job summary): the measured time.
  echo "# ${avg} ms per render, budget ${budget} ms" >&3
  awk -v a="$avg" -v b="$budget" 'BEGIN { exit !(a <= b) }' ||
    fail "render takes ${avg} ms on average, over the ${budget} ms budget"
}
