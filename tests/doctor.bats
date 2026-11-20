#!/usr/bin/env bats
# bytek doctor: checks an installation, says what to fix, exits 1 on a problem, and never
# prints anything from settings.json.

load helpers

setup() {
  bytek_setup
  needs_jq
  # A user's settings with a value doctor must never show.
  printf '{"theme":"dark","env":{"API_TOKEN":"s3cret-value"}}\n' >"$BYTEK_SETTINGS"
}

@test "a healthy setup passes, without showing anything from settings.json" {
  "$BYTEK" setup --hooks >/dev/null
  run "$BYTEK" doctor
  assert_success
  assert_output --partial "ok       the status line runs Bytek"
  assert_output --partial "ok       hooks run Bytek on"
  assert_output --partial "ok       $BYTEK_HOME/current leads to Bytek"
  assert_output --partial "ok       $BYTEK_HOME/state is writable"
  assert_output --partial "a render takes"
  refute_output --partial "problem"
  refute_output --partial "s3cret"
}

@test "hooks from the enabled plugin count" {
  "$BYTEK" setup >/dev/null
  jq '.enabledPlugins = {"bytek@bytek": true}' "$BYTEK_SETTINGS" >"$TMP/s" && mv "$TMP/s" "$BYTEK_SETTINGS"
  run "$BYTEK" doctor
  assert_success
  assert_output --partial "ok       hooks come from the Bytek plugin"
}

@test "a status line that doesn't run Bytek is a problem, with the fix" {
  run "$BYTEK" doctor
  assert_failure 1
  assert_output --partial "problem  the status line doesn't run Bytek"
  assert_output --partial "→ run: bytek setup"
  refute_output --partial "s3cret"
}

@test "no hooks, neither from the plugin nor in settings.json, is a problem" {
  "$BYTEK" setup >/dev/null
  run "$BYTEK" doctor
  assert_failure 1
  assert_output --partial "problem  no hooks run Bytek"
}

@test "a current link that leads nowhere is a problem" {
  "$BYTEK" setup --hooks >/dev/null
  ln -sfn "$TMP/gone" "$BYTEK_HOME/current"
  run "$BYTEK" doctor
  assert_failure 1
  assert_output --partial "problem  $BYTEK_HOME/current doesn't lead to Bytek"
}

@test "a state folder Bytek can't write to is a problem" {
  "$BYTEK" setup --hooks >/dev/null
  chmod 500 "$BYTEK_HOME/state"
  [ -w "$BYTEK_HOME/state" ] && skip "running as a user who can write anywhere"
  run "$BYTEK" doctor
  chmod 700 "$BYTEK_HOME/state"
  assert_failure 1
  assert_output --partial "problem  $BYTEK_HOME/state isn't writable"
}

@test "settings.json that isn't JSON is a problem" {
  printf 'not json' >"$BYTEK_SETTINGS"
  run "$BYTEK" doctor
  assert_failure 1
  assert_output --partial "isn't a JSON object"
}

@test "without a UTF-8 locale it warns but doesn't fail" {
  "$BYTEK" setup --hooks >/dev/null
  run env LC_ALL=C LANG= LC_CTYPE= BYTEK_LOCALE_CANDIDATES=no_SUCH.UTF-8 "$BYTEK" doctor
  assert_success
  assert_output --partial "warning  no UTF-8 locale"
}

@test "a routines config is checked: its routines counted, broken lines named" {
  "$BYTEK" setup --hooks >/dev/null
  mkdir -p "$BYTEK_HOME/config"
  printf 'lunch = daily 12:30\nwalk = daily 25:00\n' >"$BYTEK_HOME/config/routines"
  run "$BYTEK" doctor
  assert_success # a broken routine is a warning: the others still work
  assert_output --partial "warning  routines, line 2: walk: not a time: 25:00"
  printf 'lunch = daily 12:30\n' >"$BYTEK_HOME/config/routines"
  run "$BYTEK" doctor
  assert_output --partial "ok       routines: 1 in $BYTEK_HOME/config/routines"
}
