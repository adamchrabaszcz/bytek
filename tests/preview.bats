#!/usr/bin/env bats
# bytek preview: every look without real events, rendered into a temp home of its own.

load helpers

setup() {
  bytek_setup
  export TZ=UTC BYTEK_NOW=1764504000 # Sunday 30 November 2025, 12:00 UTC
  export TMPDIR="$TMP/tmp"
  mkdir -p "$TMPDIR"
  unset COLUMNS
}

@test "the gallery shows every state, add-on and companion stage" {
  local f s problems=""
  run "$BYTEK" preview
  assert_success
  for f in "$ROOT"/faces/*; do
    [[ "$output" == *"state: ${f##*/}"$'\n'* ]] || problems="$problems state ${f##*/};"
  done
  for f in "$ROOT"/addons/*; do
    [[ "$output" == *"add-on: ${f##*/}"$'\n'* ]] || problems="$problems add-on ${f##*/};"
  done
  for f in "$ROOT"/companions/*; do
    for s in heads_up due overdue; do
      [[ "$output" == *"routine: ${f##*/} $s"$'\n'* ]] || problems="$problems ${f##*/} $s;"
    done
  done
  [ -z "$problems" ] || fail "missing:$problems"
  [[ "$output" != *"needs a time"* ]] || fail "a stage couldn't be shown at 12:00"
}

@test "each look in the gallery is a whole status line" {
  local labels boxes
  run "$BYTEK" preview
  assert_success
  labels=$(grep -cE '^(state|add-on|routine): ' <<<"$output")
  boxes=$(grep -c '╭──┴──╮' <<<"$output")
  assert_equal "$boxes" "$labels"
}

@test "a state with its example text, or the text given" {
  run "$BYTEK" preview --state editing
  assert_success
  assert_output --partial "│ ≧ᴗ≦ │  editing"
  assert_output --partial "lib/render.sh"
  run "$BYTEK" preview --state reading --arg notes.txt
  assert_output --partial "▸ notes.txt"
  run "$BYTEK" preview --state testing
  assert_output --partial "▰▰▰▱▱ 3/5"
}

@test "an add-on on the antenna" {
  run "$BYTEK" preview --addon sun
  assert_success
  assert_line --index 0 --partial "☼"
  assert_output --partial "ready"
}

@test "a companion's stages, with a name" {
  run "$BYTEK" preview --routine dog:due
  assert_success
  assert_output --partial "│╮  walk time!"
  run "$BYTEK" preview --routine dog:heads_up --name Rex
  assert_output --partial "Rex's walk in 5m"
  run "$BYTEK" preview --routine dog:overdue --name Rex
  assert_output --partial "Rex is waiting by the door"
}

@test "the time and date move the preview's clock" {
  run "$BYTEK" preview --routine meal:overdue --time 00:02
  assert_failure
  assert_output --partial "meal overdue needs a time at least 5 minutes from midnight"
  run "$BYTEK" preview --routine meal:overdue --date 12-06 --time 23:00
  assert_success
  assert_output --partial "lunch 5m ago"
  run "$BYTEK" preview --routine meal:heads_up --date 2026-02-28 --time 07:30
  assert_output --partial "lunch in 5m"
}

@test "the width cuts the text like a terminal that wide" {
  run "$BYTEK" preview --routine dog:due --width 30
  assert_success
  assert_output --partial "walk time! · rea…"
  run "$BYTEK" preview --width 12
  assert_failure
  assert_output --partial "not a width: 12"
}

@test "unknown options, states, add-ons and stages are refused" {
  local args
  for args in "--colour red" "--state dancing" "--state ../faces/idle" "--addon rocket" \
    "--routine dog:asleep" "--routine cat:due" "--routine dog" "--date 02-30" "--date tomorrow" \
    "--time 25:00" "--state" "--arg notes.txt" "--addon sun --arg notes.txt"; do
    # shellcheck disable=SC2086 # split into the options on purpose
    run "$BYTEK" preview $args
    assert_failure
    [[ "$output" == "bytek: "* ]] || fail "$args: $output"
  done
}

@test "the real state, add-on, routines and names stay as they are, no temp folder left" {
  local before
  "$BYTEK" set editing secret.txt
  "$BYTEK" addon star
  mkdir -p "$BYTEK_HOME/config"
  printf 'tea = daily 12:00 | icon meal\n' >"$BYTEK_HOME/config/routines"
  printf 'dog = Precious\n' >"$BYTEK_HOME/config/companions"
  before=$(cd "$BYTEK_HOME" && find . -type f -exec cat {} + | cksum)
  run "$BYTEK" preview
  assert_success
  run "$BYTEK" preview --routine dog:due --name Rex
  assert_success
  refute_output --partial "secret.txt"
  refute_output --partial "tea "
  refute_output --partial "Precious"
  assert_equal "$(cd "$BYTEK_HOME" && find . -type f -exec cat {} + | cksum)" "$before"
  assert_equal "$(ls -A "$TMPDIR")" ""
}
