#!/usr/bin/env bats
# lib/hooks.sh: which commands count as tests, and following plugin updates. The event to
# state mapping is tested end to end in tests/hooks.bats.
# shellcheck disable=SC2030,SC2031 # each test sets its environment in its own subshell, on purpose

load ../helpers

setup() {
  bytek_setup
  load_module clock state hooks
}

@test "test commands count as testing, other commands don't" {
  local c
  for c in "npm test" "cd app && pytest -q" "go test ./..." "bash tests/run.sh" "./gradlew test" "make check"; do
    [[ "$c" =~ $HOOKS_TEST_RE ]] || fail "not seen as a test run: $c"
  done
  for c in "npm install" "git status" "cat latest.txt" "make build"; do
    [[ ! "$c" =~ $HOOKS_TEST_RE ]] || fail "seen as a test run: $c"
  done
}

@test "outside the plugin the status line link is left alone" {
  unset CLAUDE_PLUGIN_ROOT
  hooks_follow_plugin_update
  [ ! -e "$BYTEK_HOME/current" ] || fail "link created"
}

@test "from the plugin, a missing or old plugin link moves to this copy" {
  export CLAUDE_PLUGIN_ROOT=$ROOT
  run hooks_follow_plugin_update # looking at a missing link fails on purpose
  assert_equal "$(cd -P "$BYTEK_HOME/current" && pwd -P)" "$ROOT"
  mkdir -p "$TMP/.claude/plugins/old"
  ln -sfn "$TMP/.claude/plugins/old" "$BYTEK_HOME/current"
  run hooks_follow_plugin_update
  assert_equal "$(cd -P "$BYTEK_HOME/current" && pwd -P)" "$ROOT"
}

@test "from the plugin, a link to a checkout or manual install stays" {
  export CLAUDE_PLUGIN_ROOT=$ROOT
  mkdir -p "$TMP/checkout"
  ln -sfn "$TMP/checkout" "$BYTEK_HOME/current"
  run hooks_follow_plugin_update
  assert_equal "$(cd -P "$BYTEK_HOME/current" && pwd -P)" "$TMP/checkout"
}
