#!/usr/bin/env bats
# Hooks: Claude Code events become states in the session's state file.

load helpers

setup() {
  bytek_setup
  needs_jq
}

# ev <now> <json fields without braces>: one event for session s1 in /repo.
ev() {
  printf '{"session_id":"s1","cwd":"/repo",%s}' "$2" | BYTEK_NOW=$1 "$BYTEK" hook
}

@test "session start is idle; a prompt starts a thinking turn" {
  ev 1000 '"hook_event_name":"SessionStart"'
  assert_state s1 state idle
  ev 1000 '"hook_event_name":"UserPromptSubmit","prompt":"hi"'
  assert_state s1 state thinking
  assert_state s1 turn_start 1000
}

@test "reading a file shows its path relative to the project" {
  ev 1001 '"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/repo/src/api.ts"}'
  assert_state s1 state reading
  assert_state s1 arg src/api.ts
}

@test "grep and glob are searching, with the pattern" {
  ev 1002 '"hook_event_name":"PreToolUse","tool_name":"Grep","tool_input":{"pattern":"TODO"}'
  assert_state s1 state searching
  assert_state s1 arg TODO
}

@test "edits count changes and distinct files" {
  ev 1000 '"hook_event_name":"UserPromptSubmit","prompt":"go"'
  ev 1003 '"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/a.ts"}'
  ev 1004 '"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/b.ts"}'
  ev 1005 '"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/repo/a.ts"}'
  assert_state s1 state editing
  assert_state s1 status "editing 2 files"
  ev 1010 '"hook_event_name":"Stop"'
  assert_state s1 arg "3 changes · 10s"
}

@test "a new prompt counts edits from zero again" {
  ev 1000 '"hook_event_name":"UserPromptSubmit","prompt":"go"'
  ev 1001 '"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/a.ts"}'
  ev 1002 '"hook_event_name":"Stop"'
  ev 1003 '"hook_event_name":"UserPromptSubmit","prompt":"again"'
  ev 1004 '"hook_event_name":"Stop"'
  assert_state s1 arg "1s"
}

@test "a test command is testing, then passed" {
  ev 1006 '"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm test -- --watch=false"}'
  assert_state s1 state testing
  ev 1007 '"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"npm test"},"tool_response":{}'
  assert_state s1 status "tests passed"
}

@test "a failing test command is an error with what failed" {
  ev 1008 '"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"go test ./..."}'
  ev 1009 '"hook_event_name":"PostToolUseFailure","tool_name":"Bash","error":"exit 1: 2 failing"'
  assert_state s1 state error
  assert_state s1 status "tests failed"
  assert_state s1 arg "exit 1: 2 failing"
}

@test "other commands show as running, with the command" {
  ev 1010 '"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status"}'
  assert_state s1 state thinking
  assert_state s1 detail '$ git status'
}

@test "a permission request waits for the user, then carries on" {
  ev 1011 '"hook_event_name":"PermissionRequest","tool_name":"Edit","tool_input":{"file_path":"/repo/.env"}'
  assert_state s1 state waiting
  assert_state s1 arg "allow Edit .env?"
  ev 1012 '"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/.env"},"tool_response":{}'
  assert_state s1 state thinking
}

@test "a permission notification waits; an idle notification changes nothing" {
  ev 1013 '"hook_event_name":"Notification","message":"Claude needs your permission to use Bash","notification_type":"permission_prompt"'
  assert_state s1 state waiting
  ev 1014 '"hook_event_name":"Notification","message":"Claude is waiting for your input","notification_type":"idle_prompt"'
  assert_state s1 state waiting
}

@test "stop is done, with the turn's changes and duration" {
  ev 1000 '"hook_event_name":"UserPromptSubmit","prompt":"go"'
  ev 1003 '"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/a.ts"}'
  ev 1004 '"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/b.ts"}'
  ev 1005 '"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/repo/a.ts"}'
  ev 1041 '"hook_event_name":"Stop"'
  assert_state s1 state "done"
  assert_state s1 arg "3 changes · 41s"
  BYTEK_NOW=1041 run render s1
  assert_output --partial "3 changes · 41s"
}

@test "MCP tools show their server" {
  ev 1050 '"hook_event_name":"PreToolUse","tool_name":"mcp__sentry__search_issues","tool_input":{}'
  assert_state s1 status "using sentry"
}

@test "hooks print nothing but the antenna reminder, and exit 0, even on bad input" {
  local event
  run hook 'not json'
  assert_success
  assert_output ""
  for event in PreToolUse PostToolUse PostToolUseFailure PermissionRequest Notification Stop SessionEnd; do
    run ev 1060 '"hook_event_name":"'"$event"'","tool_name":"Read","tool_input":{"file_path":"/repo/a.ts"}'
    assert_success
    assert_output ""
  done
  run ev 1060 '"hook_event_name":"UserPromptSubmit"'
  assert_success
  assert_output "Bytek's antenna: heart."
}

@test "session start gives Claude the antenna instructions and the current add-on" {
  "$BYTEK" addon star
  run ev 1000 '"hook_event_name":"SessionStart"'
  assert_success
  assert_line --index 0 --partial "Bytek, the status line companion, has a mood antenna."
  # shellcheck disable=SC2088 # the literal "~" is what the instructions say
  assert_output --partial "~/.claude/bytek/current/bin/bytek addon <name>"
  assert_output --partial "flow (building, one change after another)"
  assert_line --index 2 "Bytek's antenna: star."
}

@test "each prompt tells Claude the current add-on" {
  run ev 1000 '"hook_event_name":"UserPromptSubmit","prompt":"go"'
  assert_output "Bytek's antenna: heart."
  "$BYTEK" addon curious
  run ev 1001 '"hook_event_name":"UserPromptSubmit","prompt":"next"'
  assert_output "Bytek's antenna: curious."
}

@test "with the antenna reminders turned off, hooks print nothing at all" {
  mkdir -p "$BYTEK_HOME/config"
  touch "$BYTEK_HOME/config/antenna-reminders-off"
  run ev 1000 '"hook_event_name":"SessionStart"'
  assert_output ""
  run ev 1001 '"hook_event_name":"UserPromptSubmit","prompt":"go"'
  assert_output ""
}

@test "session end removes the session's state and edit list" {
  ev 1000 '"hook_event_name":"UserPromptSubmit","prompt":"hi"'
  ev 1001 '"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/a.ts"}'
  ev 1100 '"hook_event_name":"SessionEnd"'
  [ ! -f "$BYTEK_HOME/state/s1" ] || fail "state file not removed"
  [ ! -f "$BYTEK_HOME/state/s1.edits" ] || fail "edit list not removed"
}

@test "edits from hooks running at the same time all count" {
  needs_jq
  local i
  BYTEK_NOW=1000 hook '{"hook_event_name":"UserPromptSubmit","session_id":"s1"}'
  for i in $(seq 30); do
    hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"/r/f'"$i"'.ts"}}' &
  done
  wait
  BYTEK_NOW=1005 hook '{"hook_event_name":"Stop","session_id":"s1"}'
  assert_state s1 arg "30 changes · 5s"
}

@test "a hook leaves a state file from a newer Bytek alone" {
  mkdir -p "$BYTEK_HOME/state"
  printf 'format=2\nmood=curious\n' >"$BYTEK_HOME/state/s1"
  ev 1000 '"hook_event_name":"UserPromptSubmit","prompt":"hi"'
  assert_equal "$(cat "$BYTEK_HOME/state/s1")" $'format=2\nmood=curious'
}
