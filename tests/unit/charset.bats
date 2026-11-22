#!/usr/bin/env bats
# lib/charset.sh: which characters Bytek draws with, and the "_ascii" keys of data files.

load ../helpers

setup() {
  bytek_setup
  load_module charset
}

@test "unicode without a config file" {
  charset_load
  assert_equal "$CHARSET" unicode
}

@test "the charset line of the config file, spaces and comments allowed" {
  mkdir -p "$BYTEK_HOME/config"
  printf '# drawing\n\n  charset =  ascii  \n' >"$CHARSET_FILE"
  charset_load
  assert_equal "$CHARSET" ascii
}

@test "an unknown charset reads as unicode" {
  mkdir -p "$BYTEK_HOME/config"
  printf 'charset = klingon\n' >"$CHARSET_FILE"
  charset_load
  assert_equal "$CHARSET" unicode
}

@test "in unicode, _ascii keys are skipped and plain keys read" {
  CHARSET=unicode
  charset_start
  run charset_key frames_ascii
  assert_failure
  charset_key frames
  assert_equal "$REPLY" frames
}

@test "in ascii, an _ascii key fills its plain key, before or after it" {
  CHARSET=ascii
  charset_start
  charset_key frames
  assert_equal "$REPLY" frames
  charset_key frames_ascii
  assert_equal "$REPLY" frames
  charset_start
  charset_key thought_ascii
  assert_equal "$REPLY" thought
  run charset_key thought
  assert_failure
  charset_key status
  assert_equal "$REPLY" status
}

@test "bytek charset sets the charset, keeps the other lines and prints the current one" {
  mkdir -p "$BYTEK_HOME/config"
  printf '# mine\nweather = rain\ncharset = unicode\n' >"$CHARSET_FILE"
  charset_set ascii
  assert_equal "$(cat "$CHARSET_FILE")" $'# mine\nweather = rain\ncharset = ascii'
  run charset_set
  assert_output ascii
  charset_set unicode
  assert_equal "$(grep -c charset "$CHARSET_FILE")" 1
}

@test "bytek charset refuses an unknown charset and writes nothing" {
  run charset_set klingon
  assert_failure
  assert_output --partial "unknown charset: klingon (unicode or ascii)"
  run charset_set "unicode ascii"
  assert_failure
  run charset_set ""
  assert_success
  assert_output unicode
  [ ! -e "$CHARSET_FILE" ] || fail "the config file was written"
}
