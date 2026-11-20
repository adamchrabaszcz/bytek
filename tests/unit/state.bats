#!/usr/bin/env bats
# lib/state.sh: loading, writing and switching a session's state, and its edit list.
# S_<key> and STATE_EDITS/STATE_FILES are set by the module under test, and each test runs in
# its own subshell on purpose:
# shellcheck disable=SC2154,SC2030,SC2031

load ../helpers

setup() {
  bytek_setup
  load_module state
}

@test "a missing state file loads as idle with nothing else set" {
  state_load "$TMP/none"
  assert_equal "$S_state" idle
  assert_equal "$S_arg$S_status$S_detail$S_progress$S_since$S_turn_start" ""
}

@test "every field survives a write and a load" {
  state_to editing "src/a.ts" "editing 2 files" "detail"
  S_progress=3/5 S_since=1000 S_turn_start=990
  state_write "$TMP/state/s1"
  state_load /dev/null
  state_load "$TMP/state/s1"
  assert_equal "$S_state|$S_arg|$S_status|$S_detail" "editing|src/a.ts|editing 2 files|detail"
  assert_equal "$S_progress|$S_since|$S_turn_start" "3/5|1000|990"
}

@test "writing drops control characters and turns line breaks into spaces" {
  state_load /dev/null
  S_arg=$'a\nb\tc\033[31md'
  state_write "$TMP/s1"
  run cat "$TMP/s1"
  assert_line "arg=a b c[31md"
}

@test "unknown keys in a state file are ignored, the edits and files older versions kept too" {
  printf 'state=reading\nevil=1\nedits=3\nfiles=|a|\n' >"$TMP/s1"
  state_load "$TMP/s1"
  assert_equal "$S_state" reading
  [ -z "${S_evil:-}${S_edits:-}${S_files:-}" ] || fail "an unknown key was loaded"
}

@test "switching state clears the previous state's text and progress" {
  state_to testing "" "running" "detail"
  S_progress=1/2
  state_to thinking
  assert_equal "$S_state|$S_arg|$S_status|$S_detail|$S_progress" "thinking||||"
}

@test "edits are counted, and different files among them" {
  state_add_edit "$TMP/state/s1" src/a.ts
  state_add_edit "$TMP/state/s1" src/b.ts
  state_add_edit "$TMP/state/s1" src/a.ts
  state_count_edits "$TMP/state/s1"
  assert_equal "$STATE_EDITS|$STATE_FILES" "3|2"
}

@test "no edit list counts as no edits; clearing it starts from zero" {
  state_count_edits "$TMP/state/s1"
  assert_equal "$STATE_EDITS|$STATE_FILES" "0|0"
  state_add_edit "$TMP/state/s1" src/a.ts
  state_clear_edits "$TMP/state/s1"
  state_count_edits "$TMP/state/s1"
  assert_equal "$STATE_EDITS|$STATE_FILES" "0|0"
}

@test "an edit's file name can't carry control characters into the list" {
  state_add_edit "$TMP/state/s1" $'a\033[31m.ts\nb.ts'
  run cat "$TMP/state/s1.edits"
  assert_output "a[31m.tsb.ts"
}
