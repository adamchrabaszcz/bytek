#!/usr/bin/env bats
# bytek done and skip: clearing a routine's reminder from the command line, and the hooks.

load helpers

setup() {
  bytek_setup
  export TZ=UTC
  mkdir -p "$BYTEK_HOME/config"
  printf 'walk = daily 13:30-14:10 | icon dog | heads_up 10m\n' >"$BYTEK_HOME/config/routines"
  "$BYTEK" set editing lib/a.ts --status "editing 3 files"
  NOW=$(date -u -d "2025-11-30 14:15" +%s 2>/dev/null || date -u -j -f '%Y-%m-%d %H:%M:%S' "2025-11-30 14:15:00" +%s)
}

@test "bytek done takes the reminder off the status line" {
  run bash -c "printf '{}' | BYTEK_NOW=$NOW '$BYTEK' render | sed -n 3p"
  assert_output --partial "waiting by the door"
  BYTEK_NOW=$NOW run "$BYTEK" "done" walk
  assert_success
  assert_output "walk at 13:30: done"
  run bash -c "printf '{}' | BYTEK_NOW=$NOW '$BYTEK' render | sed -n 3p"
  refute_output --partial "waiting by the door"
  assert_output --partial "editing 3 files"
}

@test "bytek done without a routine says how" {
  run "$BYTEK" "done"
  assert_failure
  assert_output --partial "usage: bytek done <routine>"
}

@test "Claude clearing a reminder doesn't change what Bytek shows; anything more does" {
  needs_jq
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Read","tool_input":{"file_path":"/r/a.ts"}}'
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"~/.claude/bytek/current/bin/bytek done walk"}}'
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"bytek skip wrap_up"}}'
  assert_state s1 state reading
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"bytek done walk && npm test"}}'
  assert_state s1 state testing
}

@test "a name is one word as in the config; a disabled routine points to the config" {
  printf '%s\n' "wrap_up = daily 16:30" "walk = daily 13:30 | disable" >"$BYTEK_HOME/config/routines"
  run "$BYTEK" "done" wrap up
  assert_failure
  assert_output --partial "one word, as in the config: wrap_up"
  run "$BYTEK" "done" walk
  assert_failure
  assert_output --partial "unknown routine: walk (or one with disable; see $BYTEK_HOME/config/routines)"
}
