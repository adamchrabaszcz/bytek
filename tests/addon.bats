#!/usr/bin/env bats
# The mood antenna: bytek addon sets and lists add-ons, the status line shows the current one.

load helpers

# Prints the symbol on the antenna stick at tick $1.
antenna() {
  local out
  out=$(printf '{}' | BYTEK_NOW=${1:-1000} "$BYTEK" render)
  out=${out%%$'\n'*}
  out=${out#$'\033[0m'}
  printf '%s' "${out:4:1}"
}

@test "without a chosen add-on the antenna is the heart" {
  assert_equal "$(antenna 1000)" "♡"
}

@test "bytek addon sets the antenna, which animates with the tick" {
  run "$BYTEK" addon star
  assert_success
  assert_equal "$(cat "$BYTEK_HOME/addon")" star
  assert_equal "$(antenna 1000)$(antenna 1001)" "✦✧"
}

@test "bytek addon alone lists every add-on with its meaning and marks the current one" {
  local addons=("$ROOT"/addons/*)
  "$BYTEK" addon music
  run "$BYTEK" addon
  assert_success
  assert_equal "${#lines[@]}" "${#addons[@]}"
  assert_line --regexp '^\* music +♪  in the flow'
  assert_line --regexp '^  heart +♡  warm'
}

@test "an unknown add-on is refused and changes nothing" {
  "$BYTEK" addon star
  run "$BYTEK" addon nope
  assert_failure 1
  assert_output --partial "unknown add-on: nope"
  run "$BYTEK" addon ../faces/idle
  assert_failure 1
  assert_equal "$(cat "$BYTEK_HOME/addon")" star
}

@test "an add-on file naming no add-on, or a path, shows the heart" {
  local name
  for name in nope ../faces/idle '' 'star; rm -rf /'; do
    printf '%s\n' "$name" >"$BYTEK_HOME/addon"
    assert_equal "$(antenna 1000)" "♡"
  done
}

@test "an add-on in a newer format shows the heart instead" {
  local data="$TMP/data"
  mkdir -p "$data"
  cp -R "$ROOT/faces" "$ROOT/addons" "$data/"
  printf 'format: 2\nframes: Ω\n' >"$data/addons/future"
  echo future >"$BYTEK_HOME/addon"
  BYTEK_ROOT=$data run "$BYTEK" render </dev/null
  assert_line --index 0 --partial "    ♡"
}

@test "Claude setting the antenna doesn't change what Bytek shows" {
  needs_jq
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Read","tool_input":{"file_path":"/r/a.ts"}}'
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"~/.claude/bytek/current/bin/bytek addon star"}}'
  assert_state s1 state reading
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"ls addons"}}'
  assert_state s1 state thinking
}

@test "a command that only starts with bytek addon still shows" {
  needs_jq
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"~/.claude/bytek/current/bin/bytek addon star && npm test"}}'
  assert_state s1 state testing
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Read","tool_input":{"file_path":"/r/a.ts"}}'
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"bytek addon star; rm -rf build"}}'
  assert_state s1 state thinking
}
