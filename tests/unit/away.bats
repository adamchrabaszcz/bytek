#!/usr/bin/env bats
# lib/away.sh: the Mac's idle time from ioreg (a stand-in here), and when to check it.
# AWAY_* are set by the module under test, and each test runs in its own subshell on purpose:
# shellcheck disable=SC2154,SC2030,SC2031

load ../helpers

setup() {
  bytek_setup
  load_module away
  mkdir -p "$TMP/bin"
}

# A stand-in ioreg on PATH that reports $1 nanoseconds without input.
fake_ioreg() {
  printf '#!/bin/sh\necho "  |   \\"HIDIdleTime\\" = %s"\n' "$1" >"$TMP/bin/ioreg"
  chmod +x "$TMP/bin/ioreg"
  export PATH="$TMP/bin:$PATH"
}

@test "the idle time comes from ioreg's HIDIdleTime, in seconds" {
  fake_ioreg 720400000000
  away_idle
  assert_equal "$REPLY" 720
}

@test "without ioreg there's no idle time" {
  PATH="$TMP/bin" run away_idle
  assert_failure
}

@test "a check is due without one in the last 10 seconds, or one from the future" {
  away_due 1000
  away_write 1000 0
  run away_due 1009
  assert_failure
  away_due 1010
  away_due 900
}

@test "the away file is versioned: a newer one reads as no check" {
  away_write 1000 720
  away_load
  assert_equal "$AWAY_SAMPLED $AWAY_IDLE" "1000 720"
  printf 'format=2\nsampled=1000\nidle=720\n' >"$BYTEK_HOME/away"
  away_load
  assert_equal "$AWAY_SAMPLED $AWAY_IDLE" "0 0"
}
