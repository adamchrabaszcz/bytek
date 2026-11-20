#!/usr/bin/env bats
# Companion names: bytek name, the named texts on the status line, doctor, and the hooks.

load helpers

setup() {
  bytek_setup
  export TZ=UTC
  mkdir -p "$BYTEK_HOME/config"
  printf '%s\n' "walk = daily 19:00-20:00 | icon dog | heads_up 10m" >"$BYTEK_HOME/config/routines"
  "$BYTEK" set editing lib/a.ts --status "editing 3 files"
}

# Prints the status row at "HH:MM" on 30 November 2025 (UTC), without colour codes.
row_at() {
  local at
  at=$(date -u -d "2025-11-30 $1" +%s 2>/dev/null || date -u -j -f '%Y-%m-%d %H:%M:%S' "2025-11-30 $1:00" +%s)
  printf '{}' | BYTEK_NOW=$at "$BYTEK" render | sed -n 3p | sed $'s/\033\\[[0-9]*m//g'
}

@test "with a name the dog's texts use it; without one they stay as they were" {
  run row_at 18:52
  assert_output " │ ≧ᴗ≦ │  walk in 8m · editing 3 files"
  "$BYTEK" name dog Rex
  run row_at 18:52
  assert_output " │ ≧ᴗ≦ │  Rex's walk in 8m · editing 3 files"
  run row_at 20:15
  assert_output " │ ≧ᴗ≦ │  Rex is waiting by the door · editing 3 files"
  # No named text for the due stage: the plain one stays.
  run row_at 19:30
  assert_output " │ ^ᴗ^ │╮  walk time! · editing 3 files"
  "$BYTEK" name dog
  run row_at 20:15
  assert_output " │ ≧ᴗ≦ │  waiting by the door · editing 3 files"
}

@test "escape sequences in a name don't reach the terminal" {
  printf 'dog = \033]0;pwned\a\033[2JRex\n' >"$BYTEK_HOME/config/companions"
  run row_at 18:52
  refute_output --partial $'\033'
  refute_output --partial $'\a'
  assert_output --partial "Rex's walk in 8m"
}

@test "doctor counts the names and warns about a line it can't use" {
  needs_jq
  printf '%s\n' "dog = Rex" "cat = Tom" >"$BYTEK_HOME/config/companions"
  run "$BYTEK" doctor
  assert_output --partial "warning  companion names, not a known companion: cat = Tom"
  printf 'dog = Rex\n' >"$BYTEK_HOME/config/companions"
  run "$BYTEK" doctor
  assert_output --partial "ok       companion names: 1 in"
}

@test "Claude naming a companion doesn't change what Bytek shows; anything more does" {
  needs_jq
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Read","tool_input":{"file_path":"/r/a.ts"}}'
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"~/.claude/bytek/current/bin/bytek name dog Rex"}}'
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"bytek name dog \"Rex the Second\""}}'
  assert_state s1 state reading
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"bytek name dog $(npm test)"}}'
  assert_state s1 state testing
  # A second command on the next line (line breaks reach the match as spaces).
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Read","tool_input":{"file_path":"/r/a.ts"}}'
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"bytek name dog Rex\nnpm test"}}'
  assert_state s1 state testing
}

@test "an & in a name shows as it is" {
  "$BYTEK" name dog "Tom & Jerry"
  run row_at 18:52
  assert_output " │ ≧ᴗ≦ │  Tom & Jerry's walk in 8m · editing 3 files"
}
