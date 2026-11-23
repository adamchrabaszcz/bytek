#!/usr/bin/env bats
# bytek config: a switch for each part of Bytek, all on by default, followed by the status line,
# the hooks, bytek preview and bytek doctor.

load helpers

setup() {
  bytek_setup
  export TZ=UTC BYTEK_NOW=1764504000 # Sunday 30 November 2025, 12:00 UTC
  unset COLUMNS
  "$BYTEK" set editing lib/x.sh
}

# Sets routine "walk" with the dog at $1 (HH:MM), for a reminder at 12:00.
walk_at() {
  mkdir -p "$BYTEK_HOME/config"
  printf 'walk = daily %s | icon dog | heads_up 10m\n' "$1" >"$BYTEK_HOME/config/routines"
}

@test "with nothing set, every part is on and the status line is the full box" {
  run "$BYTEK" config
  assert_output $'box: on\nantenna: on\nthought: on\ncompanions: on\nreminders: on'
  run render
  assert_line --index 0 $'\033[0m    ♡ ✎'
  assert_line --index 1 $'\033[0m ╭──┴──╮'
}

@test "box off: the status line is the one line, cut to the window" {
  "$BYTEK" config box off
  run render
  assert_output $'(≧ᴗ≦) editing\033[2m · ◜ lib/x.sh\033[0m'
  COLUMNS=12 run render
  assert_output "(≧ᴗ≦) editi…"
}

@test "antenna off: the default add-on whatever was picked, and no reminders to Claude" {
  needs_jq
  "$BYTEK" addon sun
  "$BYTEK" config antenna off
  run render
  assert_line --index 0 $'\033[0m    ♡ ✎'
  run hook '{"session_id":"s1","hook_event_name":"SessionStart"}'
  assert_output ""
  run hook '{"session_id":"s1","hook_event_name":"UserPromptSubmit","prompt":"go"}'
  assert_output ""
  "$BYTEK" config antenna on
  run render
  assert_line --index 0 $'\033[0m    ☼ ✎'
}

@test "thought off: no thought bubble, the antenna stays" {
  "$BYTEK" config thought off
  run render
  assert_line --index 0 $'\033[0m    ♡'
}

@test "companions off: a routine's reminder as text with the reminder mark" {
  walk_at 12:10
  run render
  assert_output --partial "(ᵔᴥᵔ)"
  "$BYTEK" config companions off
  run render
  assert_output --partial "◷ walk in 10m · editing"
  refute_output --partial "ᴥ"
}

@test "reminders off: no routine on the status line" {
  walk_at 12:10
  "$BYTEK" config reminders off
  run render
  refute_output --partial "walk"
  assert_line --index 2 $'\033[0m │ ≧ᴗ≦ │  editing'
}

@test "bytek preview shows a part turned off without changing the real settings" {
  run "$BYTEK" preview --state waiting --off box
  assert_output "(◕ᴗ◕) needs you · Bash: tools/lint.sh"
  run "$BYTEK" preview --off wings
  assert_failure
  assert_output --partial "unknown part: wings"
  run "$BYTEK" config box
  assert_output on
}

@test "bytek doctor names the parts turned off" {
  run "$BYTEK" doctor
  assert_output --partial "every part of Bytek is on"
  "$BYTEK" config thought off
  "$BYTEK" config reminders off
  run "$BYTEK" doctor
  assert_output --partial "turned off: thought, reminders (bytek config <part> on, or bytek config reset)"
}

@test "the charset command and the switches share config/bytek without losing each other's lines" {
  "$BYTEK" config box off
  "$BYTEK" charset ascii
  "$BYTEK" config thought off
  run "$BYTEK" config reset
  assert_equal "$(cat "$BYTEK_HOME/config/bytek")" "charset = ascii"
  run "$BYTEK" charset
  assert_output ascii
}

@test "/bytek config asks with the parts bytek config lists" {
  local part
  for part in $("$BYTEK" config | sed 's/:.*//'); do
    grep -q "\`$part\` (" "$ROOT/commands/bytek.md" || fail "commands/bytek.md doesn't offer $part"
  done
}
