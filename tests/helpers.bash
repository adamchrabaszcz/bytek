# Shared setup for Bytek's bats tests. A test file starts with `load helpers` (`load
# ../helpers` in tests/unit/). Every test gets a fresh temp folder with its own BYTEK_HOME and
# settings file, so tests never touch the real ~/.claude and can run in any order.

# Found from this file, not from the test file, so tests in subfolders work too.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BYTEK="$ROOT/bin/bytek"

load "$ROOT/tests/bats/support/load"
load "$ROOT/tests/bats/assert/load"

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

# Loads lib/<name>.sh for each name into the test, for unit tests that call module functions
# directly. Sets what bin/bytek gives every module: BYTEK_ROOT, BYTEK_UTF8, die, and its shell
# options (nounset and pipefail off), whatever a parent exported (bashcov exports its own).
# bats needs errexit on to fail a test, so call a function whose commands may fail on purpose
# through `run`.
load_module() {
  local m
  set +o nounset +o pipefail
  export BYTEK_ROOT=$ROOT BYTEK_UTF8=1
  # shellcheck disable=SC2329 # called by the modules, not here
  die() {
    printf 'bytek: %s\n' "$1" >&2
    return 1
  }
  for m in "$@"; do
    # shellcheck source=/dev/null # one of lib/*.sh, named by the test
    . "$ROOT/lib/$m.sh"
  done
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
