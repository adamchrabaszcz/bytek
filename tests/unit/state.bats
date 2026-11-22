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

@test "a state file starts with its format version" {
  state_load /dev/null
  state_write "$TMP/s1"
  run head -1 "$TMP/s1"
  assert_output "format=1"
}

@test "a state file without a format line is format 1" {
  printf 'state=reading\narg=a.ts\n' >"$TMP/s1"
  state_load "$TMP/s1"
  assert_equal "$S_state|$S_arg|$STATE_NEWER" "reading|a.ts|"
}

@test "a state file in a newer or unreadable format loads as idle and is marked" {
  local format
  for format in 2 x; do
    printf 'format=%s\nstate=reading\narg=a.ts\n' "$format" >"$TMP/s1"
    state_load "$TMP/s1"
    assert_equal "$S_state|$S_arg|$STATE_NEWER" "idle||1"
  done
}

@test "the latest session is the one whose state changed last; edit lists and temp files don't count" {
  state_latest "$TMP/none"
  assert_equal "$REPLY" default
  mkdir -p "$TMP/state"
  state_latest "$TMP/state"
  assert_equal "$REPLY" default
  printf 'format=1\n' >"$TMP/state/abc-1"
  printf 'format=1\n' >"$TMP/state/def_2"
  printf 'x\n' >"$TMP/state/abc-1.edits"
  printf 'x\n' >"$TMP/state/.tmp.XYZ"
  touch -t 202601010000 "$TMP/state/def_2"
  touch -t 202601020000 "$TMP/state/abc-1"
  touch -t 202601030000 "$TMP/state/abc-1.edits" "$TMP/state/.tmp.XYZ"
  state_latest "$TMP/state"
  assert_equal "$REPLY" abc-1
  touch -t 202601040000 "$TMP/state/def_2"
  state_latest "$TMP/state"
  assert_equal "$REPLY" def_2
}
