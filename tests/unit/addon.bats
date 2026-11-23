#!/usr/bin/env bats
# lib/addon.sh: the current add-on's name, reading add-on files, setting one.
# ADDON_* are set by the module under test, and each test runs in its own subshell on purpose:
# shellcheck disable=SC2154,SC2030,SC2031

load ../helpers

setup() {
  bytek_setup
  load_module config charset addon
}

@test "the current add-on is the one named in the file, if it exists" {
  echo star >"$BYTEK_HOME/addon"
  addon_current
  assert_equal "$REPLY" star
}

@test "no file, an unknown name or anything but letters and dashes means the default" {
  local name
  addon_current
  assert_equal "$REPLY" heart
  for name in nope ../faces/idle 'star x' STAR; do
    printf '%s\n' "$name" >"$BYTEK_HOME/addon"
    addon_current
    assert_equal "$REPLY" heart
  done
}

@test "an add-on file gives its frames and meaning, comments and other keys skipped" {
  printf '# a comment\nformat: 1\nframes: a|b\nmeaning: testing\nother: x\n' >"$TMP/a"
  addon_read "$TMP/a"
  assert_equal "$ADDON_FRAMES|$ADDON_MEANING" "a|b|testing"
}

@test "an add-on file in a newer or unreadable format reads as empty" {
  local format
  for format in 2 x; do
    printf 'format: %s\nframes: a|b\nmeaning: m\n' "$format" >"$TMP/a"
    addon_read "$TMP/a"
    assert_equal "$ADDON_FRAMES$ADDON_MEANING" ""
  done
}

@test "loading falls back to the plain heart when the add-on can't be read" {
  export BYTEK_ROOT="$TMP/empty"
  addon_load
  assert_equal "$ADDON_FRAMES" "♡"
}

@test "setting an add-on writes its name; an unknown one is refused" {
  addon_set flower
  assert_equal "$(cat "$BYTEK_HOME/addon")" flower
  run addon_set nope
  assert_failure
  assert_equal "$(cat "$BYTEK_HOME/addon")" flower
}
