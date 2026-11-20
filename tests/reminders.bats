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

# Writes a routines config of lines $@.
routines() { printf '%s\n' "$@" >"$BYTEK_HOME/config/routines"; }

# Prints rows 3 and 4 at "HH:MM[:SS]" on 30 November 2025 (UTC), $2 columns wide.
rows_at() {
  local t=$1 at
  [[ "$t" =~ :[0-9]{2}:[0-9]{2}$ ]] || t="$t:00"
  at=$(date -u -d "2025-11-30 $t" +%s 2>/dev/null || date -u -j -f '%Y-%m-%d %H:%M:%S' "2025-11-30 $t" +%s)
  printf '{}' | BYTEK_NOW=$at COLUMNS=${2:-80} "$BYTEK" render | sed -n '3,4p' | sed $'s/\033\\[[0-9]*m//g'
}

@test "a companion stands next to Bytek on the detail row, Claude's detail after it" {
  routines "walk = daily 19:00-20:00 | icon dog | heads_up 10m"
  run rows_at 18:52
  assert_line --index 0 " │ ≧ᴗ≦ │  walk in 8m · editing 3 files"
  assert_line --index 1 " ╰─┬─┬─╯ (ᵔᴥᵔ) ◜ lib/a.ts"
}

@test "while due, the companion brings its text, face and leash" {
  routines "walk = daily 19:00-20:00 | icon dog | heads_up 10m"
  run rows_at 19:30:00
  assert_line --index 0 " │ ^ᴗ^ │╮  walk time! · editing 3 files"
  assert_line --index 1 " ╰─┬─┬─╯╰(ᵔᴥᵔ)~ ◜ lib/a.ts"
  run rows_at 19:30:01
  assert_line --index 0 " │ ᵔᴗᵔ │╮  walk time! · editing 3 files"
  assert_line --index 1 " ╰─┬─┬─╯╰(ᵔᴥᵔ)  ◝ lib/a.ts" # the wagging tail keeps the detail in place
}

@test "overdue, the companion has its own words; a meal is named after its routine" {
  routines "walk = daily 19:00-20:00 | icon dog" "dinner = daily 12:30 | icon meal"
  run rows_at 20:15
  assert_line --index 0 " │ ≧ᴗ≦ │  waiting by the door · editing 3 files"
  assert_line --index 1 " ╰─┬─┬─╯ (•ᴥ•)? ◜ lib/a.ts"
  run rows_at 12:30
  assert_line --index 0 " │ ≧ᴗ≦ │  dinner time! · editing 3 files"
}

@test "a narrow terminal cuts Claude's detail, not the companion" {
  "$BYTEK" set editing src/a/rather/long/path/to/a/file/somewhere.ts --status "editing 3 files"
  routines "walk = daily 19:00-20:00 | icon dog"
  run rows_at 19:30 40
  assert_line --index 1 --partial " ╰─┬─┬─╯╰(ᵔᴥᵔ)~ "
  assert_line --index 1 --partial "…"
}

@test "without a companion, or with an unknown one, the reminder keeps its ◷" {
  routines "lunch = daily 12:30 | heads_up 10m" "walk = daily 19:00-20:00 | icon nosuch"
  run rows_at 12:22
  assert_line --index 0 " │ ≧ᴗ≦ │  ◷ lunch in 8m · editing 3 files"
  assert_line --index 1 " ╰─┬─┬─╯  ◜ lib/a.ts"
  run rows_at 19:30
  assert_line --index 0 --partial "◷ walk now, until 20:00"
}

@test "a stage the companion file leaves out keeps the ◷" {
  local data="$TMP/data"
  mkdir -p "$data"
  cp -R "$ROOT/faces" "$ROOT/addons" "$ROOT/companions" "$data/"
  printf 'due: (o)\n' >"$data/companions/bare" # no icon: nothing for the heads-up
  routines "walk = daily 19:00-20:00 | icon bare | heads_up 10m"
  BYTEK_ROOT=$data run rows_at 18:52
  assert_line --index 0 " │ ≧ᴗ≦ │  ◷ walk in 8m · editing 3 files"
  assert_line --index 1 " ╰─┬─┬─╯  ◜ lib/a.ts"
}
