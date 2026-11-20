#!/usr/bin/env bats
# lib/settings.sh: editing settings.json safely. Setup and uninstall are tested end to end in
# tests/setup.bats.

load ../helpers

setup() {
  bytek_setup
  needs_jq
  load_module clock settings
  # A data root of its own, so the tests can give settings_edit their own jq programs.
  BYTEK_ROOT="$TMP/root"
  mkdir -p "$BYTEK_ROOT/lib"
  printf '. + {"edited": true}\n' >"$BYTEK_ROOT/lib/add.jq"
  printf 'error("no")\n' >"$BYTEK_ROOT/lib/fails.jq"
  printf '{"model":"x"}\n' >"$BYTEK_SETTINGS"
}

# Fails when settings_edit left a temp file (settings.json.XXXXXX) next to settings.json.
refute_temp_files() {
  local f
  for f in "$BYTEK_SETTINGS".*; do
    [ -e "$f" ] && fail "temp file left behind: $f"
  done
  return 0
}

@test "an edit is applied and leaves no temp file behind" {
  settings_edit add.jq
  assert_equal "$(jq -c . "$BYTEK_SETTINGS")" '{"model":"x","edited":true}'
  refute_temp_files
}

@test "a failed edit leaves settings.json as it was" {
  run settings_edit fails.jq
  assert_failure
  assert_equal "$(cat "$BYTEK_SETTINGS")" '{"model":"x"}'
  refute_temp_files
}

@test "a symlinked settings.json stays a symlink" {
  mv "$BYTEK_SETTINGS" "$TMP/real.json"
  ln -s "$TMP/real.json" "$BYTEK_SETTINGS"
  settings_edit add.jq
  [ -L "$BYTEK_SETTINGS" ] || fail "no longer a symlink"
  assert_equal "$(jq -c .edited "$TMP/real.json")" true
}

@test "Bytek's own commands are recognised, quoted or not, others aren't" {
  local c
  # shellcheck disable=SC2088 # a literal "~" is the point: settings.json can hold one
  for c in '/x/bin/bytek render' '"/x y/bin/bytek" hook' '~/.claude/bytek/current/bin/bytek render'; do
    [[ "$c" =~ $SETTINGS_CMD_RE ]] || fail "not recognised: $c"
  done
  for c in '/x/bin/bytek set idle' 'my-status render' '/x/bin/bytek render --other'; do
    [[ ! "$c" =~ $SETTINGS_CMD_RE ]] || fail "recognised: $c"
  done
}
