#!/usr/bin/env bats
# lib/config.sh: Bytek's own settings in config/bytek, the switches all on by default.
# shellcheck disable=SC2154 # CONFIG_<key> is set by the module under test

load ../helpers

setup() {
  bytek_setup
  load_module config
}

@test "every switch is on without a config file" {
  config_load
  assert_equal "$CONFIG_box $CONFIG_antenna $CONFIG_thought $CONFIG_companions $CONFIG_reminders" "on on on on on"
  assert_equal "$CONFIG_charset" ""
}

@test "a switch is off only when its line says off; spaces, comments and other keys allowed" {
  mkdir -p "$BYTEK_HOME/config"
  printf '# mine\n\n  thought =  off \nbox = no\nantenna=off\ncharset = ascii\nweather = rain\n' >"$CONFIG_FILE"
  config_load
  assert_equal "$CONFIG_box $CONFIG_antenna $CONFIG_thought $CONFIG_companions $CONFIG_reminders" "on off off on on"
  assert_equal "$CONFIG_charset" ascii
}

@test "writing a key replaces its line, keeps the others, and an empty value removes it" {
  mkdir -p "$BYTEK_HOME/config"
  printf '# mine\ncharset = ascii\nthought = off\n' >"$CONFIG_FILE"
  config_write box off
  assert_equal "$(cat "$CONFIG_FILE")" $'# mine\ncharset = ascii\nthought = off\nbox = off'
  config_write thought ""
  assert_equal "$(cat "$CONFIG_FILE")" $'# mine\ncharset = ascii\nbox = off'
  [ ! -e "$CONFIG_FILE.tmp" ] || fail "temp file left"
}

@test "bytek config lists, shows, sets and resets the switches" {
  run config_run
  assert_output $'box: on\nantenna: on\nthought: on\ncompanions: on\nreminders: on'
  run config_run thought off
  assert_output "thought: off"
  run config_run thought
  assert_output off
  config_run thought on >/dev/null
  [ ! -s "$CONFIG_FILE" ] || fail "on should leave no line: $(cat "$CONFIG_FILE")"
  config_write charset ascii
  config_run box off >/dev/null
  config_run antenna off >/dev/null
  run config_run reset
  assert_output $'box: on\nantenna: on\nthought: on\ncompanions: on\nreminders: on'
  assert_equal "$(cat "$CONFIG_FILE")" "charset = ascii"
}

@test "bytek config refuses unknown parts and values, and writes nothing" {
  local args
  for args in "wings" "wings off" "box maybe" "box ON" "charset ascii" "box off extra" "../x off"; do
    # shellcheck disable=SC2086 # split into the arguments on purpose
    run config_run $args
    assert_failure
    [[ "$output" == "bytek: "* ]] || fail "$args: $output"
  done
  [ ! -e "$CONFIG_FILE" ] || fail "the config file was written"
}
