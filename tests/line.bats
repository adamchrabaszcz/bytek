#!/usr/bin/env bats
# bytek line: the one-line layout as plain text, for Touch Bar apps; the latest session or a
# given one, cut to a width, never empty.

load helpers

setup() {
  bytek_setup
  export TZ=UTC BYTEK_NOW=1764504000 # Sunday 30 November 2025, 12:00 UTC
}

@test "the session that changed last, on one plain line" {
  "$BYTEK" set reading notes.txt --session older
  "$BYTEK" set waiting "Bash: tools/lint.sh" --session newer
  touch -t 202601010000 "$BYTEK_HOME/state/older"
  touch -t 202601020000 "$BYTEK_HOME/state/newer"
  run "$BYTEK" line
  assert_success
  assert_output "(◕ᴗ◕) needs you · Bash: tools/lint.sh"
  touch -t 202601030000 "$BYTEK_HOME/state/older"
  run "$BYTEK" line
  assert_output "(•ᴗ•) reading · ▸ notes.txt"
}

@test "a given session, and the default one when there is none yet" {
  run "$BYTEK" line
  assert_output "(•ᴗ•) ready · waiting for a task"
  "$BYTEK" set reading notes.txt --session one
  "$BYTEK" set editing lib/x.sh --session two
  touch -t 202601010000 "$BYTEK_HOME/state/one"
  touch -t 202601020000 "$BYTEK_HOME/state/two"
  run "$BYTEK" line --session one
  assert_output "(•ᴗ•) reading · ▸ notes.txt"
}

@test "no codes, even with an overdue reminder or a dimmed detail" {
  "$BYTEK" set idle
  mkdir -p "$BYTEK_HOME/config"
  printf 'walk = daily 11:55 | icon dog\n' >"$BYTEK_HOME/config/routines"
  run "$BYTEK" line
  assert_output "(•ᴗ•) (•ᴥ•)? waiting by the door · ready · waiting for a task"
}

@test "the width cuts the line, and the ascii charset makes it plain ASCII" {
  "$BYTEK" set waiting "Bash: tools/lint.sh"
  run "$BYTEK" line --width 30
  assert_output "(◕ᴗ◕) needs you · Bash: tools…"
  "$BYTEK" charset ascii
  run "$BYTEK" line --width 30
  assert_output "(O_O) needs you - Bash: too..."
}

@test "a missing data folder still prints a line" {
  BYTEK_ROOT=/nonexistent run "$BYTEK" line
  assert_success
  refute_output ""
}

@test "unknown options, bad session ids and widths are refused" {
  local args
  for args in "--colour red" "--session" "--session ../x" "--width 9" "--width wide" "--width"; do
    # shellcheck disable=SC2086 # split into the options on purpose
    run "$BYTEK" line $args
    assert_failure
    [[ "$output" == "bytek: "* ]] || fail "$args: $output"
  done
}
