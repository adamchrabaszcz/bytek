# Shared setup for Bytek's bats tests. A test file starts with `load helpers`.
# Every test gets a fresh temp folder with its own BYTEK_HOME and settings file, so tests
# never touch the real ~/.claude and can run in any order.

ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
BYTEK="$ROOT/bin/bytek"

load "bats/support/load"
load "bats/assert/load"

setup() {
  bytek_setup
}

bytek_setup() {
  export LC_ALL=en_US.UTF-8
  TMP=$(cd -P "$BATS_TEST_TMPDIR" && pwd -P) # resolved: macOS temp folders sit behind a symlink
  export BYTEK_HOME="$TMP/home"
  export BYTEK_SETTINGS="$TMP/settings.json"
  mkdir -p "$BYTEK_HOME"
}

# Skips the test when jq is missing (hooks, setup and the tools need it).
needs_jq() {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
}

# Renders the status line for session $1 (default "default"); extra env via the caller.
render() {
  printf '{"session_id":"%s"}' "${1:-default}" | "$BYTEK" render
}

# Sends hook JSON to bytek hook.
hook() {
  printf '%s' "$1" | "$BYTEK" hook
}

# Prints field $2 of session $1's state file.
state_of() {
  sed -n "s/^$2=//p" "$BYTEK_HOME/state/$1"
}

# Fails unless field $2 of session $1's state equals $3.
assert_state() {
  local got
  got=$(state_of "$1" "$2")
  [ "$got" = "$3" ] || fail "state $2: expected '$3', got '$got'"
}
