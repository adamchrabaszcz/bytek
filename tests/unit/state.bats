#!/usr/bin/env bats
# lib/state.sh: loading, writing and switching a session's state.
# S_<key> is set by the module under test, STATE_LOCK_WAIT read by it, and each test runs in
# its own subshell on purpose:
# shellcheck disable=SC2154,SC2034,SC2030,SC2031

load ../helpers

setup() {
  bytek_setup
  load_module clock state
}

@test "a missing state file loads as idle with nothing else set" {
  state_load "$TMP/none"
  assert_equal "$S_state" idle
  assert_equal "$S_arg$S_status$S_detail$S_progress$S_since$S_turn_start$S_edits$S_files" ""
}

@test "every field survives a write and a load" {
  state_to editing "src/a.ts" "editing 2 files" "detail"
  S_progress=3/5 S_since=1000 S_turn_start=990 S_edits=2 S_files="|a|b|"
  state_write "$TMP/state/s1"
  state_load /dev/null
  state_load "$TMP/state/s1"
  assert_equal "$S_state|$S_arg|$S_status|$S_detail" "editing|src/a.ts|editing 2 files|detail"
  assert_equal "$S_progress|$S_since|$S_turn_start|$S_edits|$S_files" "3/5|1000|990|2||a|b|"
}

@test "writing drops control characters and turns line breaks into spaces" {
  state_load /dev/null
  S_arg=$'a\nb\tc\033[31md'
  state_write "$TMP/s1"
  run cat "$TMP/s1"
  assert_line "arg=a b c[31md"
}

@test "unknown keys in a state file are ignored" {
  printf 'state=reading\nevil=1\n' >"$TMP/s1"
  state_load "$TMP/s1"
  assert_equal "$S_state" reading
  [ -z "${S_evil:-}" ] || fail "S_evil was set"
}

@test "switching state clears the previous state's text and progress" {
  state_to testing "" "running" "detail"
  S_progress=1/2
  state_to thinking
  assert_equal "$S_state|$S_arg|$S_status|$S_detail|$S_progress" "thinking||||"
}

@test "a lock is taken once, and free again after unlock" {
  state_lock "$TMP/state/s1"
  [ -d "$TMP/state/s1.lock" ] || fail "no lock"
  STATE_LOCK_WAIT=1
  run state_lock "$TMP/state/s1"
  assert_failure
  state_unlock "$TMP/state/s1"
  state_lock "$TMP/state/s1"
}

@test "a lock left behind by a crash is taken over" {
  mkdir -p "$TMP/state/s1.lock"
  echo 1000 >"$TMP/state/s1.lock/since"
  BYTEK_NOW=2000 state_lock "$TMP/state/s1"
  assert_equal "$(cat "$TMP/state/s1.lock/since")" 2000
}

@test "a held lock makes the caller give up, so it can go ahead without it" {
  # How long it tries is fixed by the code (STATE_LOCK_WAIT seconds of attempts), not measured.
  STATE_LOCK_WAIT=1
  state_lock "$TMP/state/s1"
  run state_lock "$TMP/state/s1"
  assert_failure
  [ -d "$TMP/state/s1.lock" ] || fail "the holder's lock was removed"
}
