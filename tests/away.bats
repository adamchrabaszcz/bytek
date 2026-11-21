#!/usr/bin/env bats
# Clearing on idle: the status line starts `bytek away` in the background, which clears a "clear
# idle" routine when the Mac has had no input for long enough. ioreg is a stand-in here.

load helpers

setup() {
  bytek_setup
  export TZ=UTC
  mkdir -p "$BYTEK_HOME/config" "$TMP/bin"
  printf 'walk = daily 13:30-14:10 | icon dog | heads_up 10m | clear idle\n' >"$BYTEK_HOME/config/routines"
  "$BYTEK" set editing lib/a.ts --status "editing 3 files"
  NOW=$(date -u -d "2025-11-30 13:45" +%s 2>/dev/null || date -u -j -f '%Y-%m-%d %H:%M:%S' "2025-11-30 13:45:00" +%s)
  # 12 minutes without input.
  printf '#!/bin/sh\necho "  |   \\"HIDIdleTime\\" = 720000000000"\n' >"$TMP/bin/ioreg"
  chmod +x "$TMP/bin/ioreg"
  export PATH="$TMP/bin:$PATH"
}

row() {
  printf '{}' | BYTEK_NOW=$NOW "$BYTEK" render | sed -n 3p
}

@test "bytek away clears a due walk after 10 minutes away" {
  run row
  assert_output --partial "walk time!"
  BYTEK_NOW=$NOW run "$BYTEK" away
  assert_success
  run row
  refute_output --partial "walk"
  assert_output --partial "editing 3 files"
}

@test "the status line starts the check in the background, then not again for 10 seconds" {
  row >/dev/null
  # The check runs apart from the render: wait for its result (up to 10 s), not a fixed time.
  local i=0
  while [ ! -f "$BYTEK_HOME/cleared" ] && [ "$i" -lt 100 ]; do
    sleep 0.1
    i=$((i + 1))
  done
  run cat "$BYTEK_HOME/cleared"
  assert_output --partial "walk "
  rm "$BYTEK_HOME/cleared"
  printf '{}' | BYTEK_NOW=$((NOW + 5)) "$BYTEK" render >/dev/null
  run cat "$BYTEK_HOME/away"
  assert_output --partial "sampled=$NOW"
}

@test "without ioreg nothing is checked, and doctor says so" {
  needs_jq
  rm "$TMP/bin/ioreg"
  PATH="$TMP/bin:/usr/bin:/bin" run "$BYTEK" doctor # macOS keeps ioreg in /usr/sbin
  assert_output --partial "clear idle needs macOS (ioreg)"
}
