#!/usr/bin/env bats
# bytek charset: plain ASCII on the status line, for terminals that show ♡ ᴗ ╭ two columns wide.

load helpers

setup() {
  bytek_setup
  export TZ=UTC BYTEK_NOW=1764504000 # Sunday 30 November 2025, 12:00 UTC
}

# The status line without Bytek's dim, bold and reset codes.
plain() { render | sed $'s/\033\\[[0-9]*m//g'; }

@test "bytek charset ascii draws with plain ASCII, unicode switches back" {
  "$BYTEK" set editing lib/a.sh
  run "$BYTEK" charset ascii
  assert_success
  run plain
  assert_line --index 0 "    v /"
  assert_line --index 1 " .--+--."
  assert_line --index 2 --regexp '^ \| [<>]_[<>] \|  editing$'
  assert_line --index 3 --regexp "^ '-\+-\+-'  [/\\\\-] lib/a.sh$"
  LC_ALL=C grep -q '[^ -~]' <<<"$output" && fail "non-ASCII in: $output"
  "$BYTEK" charset unicode
  run plain
  assert_line --index 1 " ╭──┴──╮"
}

@test "bytek charset prints the current one and refuses unknown ones" {
  run "$BYTEK" charset
  assert_output unicode
  "$BYTEK" charset ascii
  run "$BYTEK" charset
  assert_output ascii
  run "$BYTEK" charset klingon
  assert_failure
  assert_output --partial "unknown charset: klingon"
  run "$BYTEK" charset
  assert_output ascii
}

@test "in ascii, the bar, the cut, the reminder and the hooks' marks are ASCII" {
  "$BYTEK" charset ascii
  "$BYTEK" set testing --progress 3/5
  run plain
  assert_line --index 3 " '-+-+-'  ###-- 3/5"
  printf 'format=1\nstate=done\narg=3 changes · lib/a.sh\n' >"$BYTEK_HOME/state/default"
  run plain
  assert_line --index 3 " '-+-+-'  3 changes - lib/a.sh"
  printf 'format=1\nstate=thinking\ndetail=✓ tests passed\n' >"$BYTEK_HOME/state/default"
  run plain
  assert_line --index 3 " '-+-+-'  + tests passed"
  mkdir -p "$BYTEK_HOME/config"
  printf 'tea = daily 12:00\n' >"$BYTEK_HOME/config/routines"
  "$BYTEK" set editing "a very long file name that goes on and on.sh"
  run bash -c "printf '{}' | COLUMNS=40 '$BYTEK' render"
  assert_line --index 2 --partial "(!) tea now - editing"
  assert_line --index 3 --partial "..."
}

@test "the dog on its leash in ascii" {
  "$BYTEK" charset ascii
  mkdir -p "$BYTEK_HOME/config"
  printf 'walk = daily 12:00 | icon dog\n' >"$BYTEK_HOME/config/routines"
  run plain
  assert_line --index 2 --regexp '^ \| (\^_\^|\^-\^) \|\\  walk time! - ready$'
  assert_line --index 3 --regexp "^ '-\+-\+-'\\\\\(\^\.\^\)"
}

@test "bytek addon lists the ascii add-ons, the current one marked" {
  "$BYTEK" charset ascii
  "$BYTEK" addon sun
  run "$BYTEK" addon
  assert_line --regexp '^\* sun +O  bright'
  assert_line --regexp '^  heart +v  warm'
}

@test "bytek doctor says which charset is used" {
  run "$BYTEK" doctor
  assert_output --partial "charset: unicode"
  "$BYTEK" charset ascii
  run "$BYTEK" doctor
  assert_output --partial "charset: ascii (bytek charset unicode switches back)"
}
