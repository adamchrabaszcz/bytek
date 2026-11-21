#!/usr/bin/env bats
# The render path stays cheap: the status line redraws every second. What makes a render slow in
# bash is starting programs, so the check that fails counts them, the same on every machine.
# Every state renders once through the real bin/bytek, with the example routines configured at a
# moment when a companion is due (the most expensive reminder to draw), each program on PATH
# replaced by a stand-in that writes down its call. The time per render (budget
# BYTEK_RENDER_BUDGET_MS, default 50 ms) is measured too: a note on CI, where shared runners vary
# from run to run (29 to 54 ms on macOS for the same code), and a failing check on your machine.
# Skipped under coverage (BYTEK_COVERAGE=1): bashcov's tracing slows everything down and starts
# programs of its own.

load helpers

# The programs a render may start, each at most once: dirname (bin/bytek finding its folder), cat
# (reading Claude Code's JSON from stdin) and date (lib/clock.sh). A new one needs a reason here.
SPEED_ALLOWED="cat date dirname"

setup() {
  bytek_setup
  mkdir -p "$BYTEK_HOME/config"
  cp "$ROOT/examples/routines.example" "$BYTEK_HOME/config/routines"
  # A fixed moment, so every run measures the same thing whenever CI happens to run: Sunday
  # 30 Nov 2025, 19:30 UTC, when the example's walk is due with the dog on its leash (the most
  # expensive reminder to draw) and the other routines are worked out too.
  export TZ=UTC BYTEK_NOW=1764531000
  # A check of the Mac's idle time just ran (lib/away.sh), so no render starts one in the
  # background: that runs every 10 s, apart from the render.
  printf 'format=1\nsampled=%s\nidle=0\n' "$BYTEK_NOW" >"$BYTEK_HOME/away"
}

# Writes a stand-in to $1 for every program on PATH, the first of each name, that notes its name
# in $BYTEK_CALLS and runs the real one. Written with printf, so setting up starts no processes.
stand_ins() {
  local dir f name IFS=:
  mkdir -p "$1"
  for dir in $PATH; do
    for f in "$dir"/*; do
      name=${f##*/}
      [[ "$name" =~ ^[A-Za-z0-9._+-]+$ ]] && [ -f "$f" ] && [ -x "$f" ] && [ ! -e "$1/$name" ] || continue
      printf '#!/bin/sh\nprintf "%%s\\n" %s >>"$BYTEK_CALLS"\nexec "%s" "$@"\n' "$name" "$f" >"$1/$name"
    done
  done
  chmod +x "$1"/*
}

# Renders every state $1 times with a long text that gets cut; writes the number to $TMP/count.
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

@test "a render starts only the programs it may, each at most once" {
  [ "${BYTEK_COVERAGE:-}" = 1 ] && skip "programs not counted under coverage"
  local face calls name extra=""
  stand_ins "$TMP/bin"
  export BYTEK_CALLS="$TMP/calls"
  # The stand-ins work: otherwise every render would seem to start nothing.
  PATH="$TMP/bin" date >/dev/null
  assert_equal "$(cat "$BYTEK_CALLS")" date
  for face in "$ROOT"/faces/*; do
    "$BYTEK" set "${face##*/}" "src/a.ts" --progress 3/5
    : >"$BYTEK_CALLS"
    # Through this bash, not bin/bytek's `env bash`: that start belongs to the status line.
    printf '{}' | PATH="$TMP/bin" COLUMNS=60 "$BASH" "$BYTEK" render >/dev/null
    calls=$(sort "$BYTEK_CALLS" | uniq -c | awk '{ printf "%s%s×%s", (NR > 1 ? ", " : ""), $2, $1 }')
    while IFS= read -r name; do
      case " $SPEED_ALLOWED " in *" $name "*) ;; *) extra="$extra $name" ;; esac
    done <"$BYTEK_CALLS"
    if [ -n "$extra" ] || [ "$(sort "$BYTEK_CALLS" | uniq -d)" ]; then
      fail "rendering ${face##*/} started: $calls (allowed, once each: $SPEED_ALLOWED)"
    fi
  done
}

@test "a render takes less than the budget on average (a note on CI)" {
  [ "${BYTEK_COVERAGE:-}" = 1 ] && skip "render budget not checked under coverage"
  local budget=${BYTEK_RENDER_BUDGET_MS:-50} seconds avg TIMEFORMAT=%3R
  # bash's own `time` gives milliseconds on bash 3.2 too, without extra tools.
  seconds=$({ time render_all "${BYTEK_SPEED_ROUNDS:-10}"; } 2>&1)
  avg=$(awk -v s="$seconds" -v n="$(cat "$TMP/count")" 'BEGIN { printf "%.1f", s * 1000 / n }')
  # A note for tests/run.sh's summary (and the CI job summary): the measured time.
  echo "# ${avg} ms per render, budget ${budget} ms" >&3
  [ "${CI:-}" = true ] && return 0
  awk -v a="$avg" -v b="$budget" 'BEGIN { exit !(a <= b) }' ||
    fail "render takes ${avg} ms on average, over the ${budget} ms budget"
}
