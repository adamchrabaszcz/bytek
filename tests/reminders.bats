#!/usr/bin/env bats
# Routine reminders on the status line: first in the status row, what Claude does after it.

load helpers

setup() {
  bytek_setup
  export TZ=UTC
  mkdir -p "$BYTEK_HOME/config"
  printf '%s\n' "lunch = daily 12:30 | heads_up 10m" "walk = daily 19:00-20:00 | heads_up 10m" \
    "wrap_up = daily 12:35 | heads_up 30m" >"$BYTEK_HOME/config/routines"
  "$BYTEK" set editing lib/a.ts --status "editing 3 files"
}

# Prints the status row at "HH:MM" on 30 November 2025 (UTC), in a terminal $2 columns wide.
row_at() {
  local at
  at=$(date -u -d "2025-11-30 $1" +%s 2>/dev/null || date -u -j -f '%Y-%m-%d %H:%M:%S' "2025-11-30 $1:00" +%s)
  printf '{}' | BYTEK_NOW=$at COLUMNS=${2:-80} "$BYTEK" render | sed -n 3p
}

@test "a heads-up goes first in the status, with how many more" {
  run row_at 12:22
  assert_output --partial "│  ◷ lunch in 8m +1 · editing 3 files"
}

@test "a window shows until when" {
  run row_at 19:30
  assert_output --partial "│  ◷ walk now, until 20:00 · editing 3 files"
}

@test "an overdue reminder is bold, the status after it isn't" {
  run row_at 12:45
  assert_output --partial $'│  \033[1m◷ lunch 15m ago +1\033[22m · editing 3 files'
}

@test "a narrow terminal shortens the status, not the reminder" {
  run row_at 12:45 40
  assert_output --partial $'\033[1m◷ lunch 15m ago +1\033[22m · editin…'
}

@test "nothing pending, or no routines at all: the status row is as before" {
  run row_at 15:00
  assert_output --partial "│  editing 3 files"
  refute_output --partial "◷"
  rm "$BYTEK_HOME/config/routines"
  run row_at 12:45
  assert_output --partial "│  editing 3 files"
}
