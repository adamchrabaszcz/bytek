#!/usr/bin/env bats
# Every script declares its shell options before its first command, instead of inheriting
# them: bashcov (and anything that exports SHELLOPTS) passes the parent shell's options on to
# every script it starts (CONTRIBUTING, "Shell options").

load helpers

@test "every script declares errexit, nounset and pipefail before its first command" {
  local f first missing=""
  # Modules (lib/*.sh) are loaded into bin/bytek and share its options, so they set none.
  while IFS= read -r f; do
    [ -f "$ROOT/$f" ] || continue
    first=$(grep -v -E '^[[:space:]]*(#|$)' "$ROOT/$f" | head -1)
    [[ "$first" =~ ^set\ [-+]o\ errexit\ [-+]o\ nounset\ [-+]o\ pipefail ]] || missing="$missing"$'\n'"$f: $first"
  done < <(git -C "$ROOT" ls-files 'bin/*' '*.sh' ':!lib/*.sh' 2>/dev/null)
  [ -z "$missing" ] || fail "no shell options declared first:$missing"
}

@test "Bytek runs normally when a parent exports strict shell options" {
  # What bashcov does: the parent's options, exported, reach every bash script it starts.
  run env SHELLOPTS=errexit:nounset:pipefail "$BYTEK" set idle
  assert_success
  run bash -c "printf '{}' | SHELLOPTS=errexit:nounset:pipefail '$BYTEK' render"
  assert_success
  assert_output --partial "╭──┴──╮"
}

@test "unit tests run modules with Bytek's shell options when a parent exports strict ones" {
  # bashcov exports its options; unit tests load modules into the test shell, where bin/bytek's
  # options must apply, as in a real run (#81).
  run env SHELLOPTS=nounset "$ROOT/tests/run.sh" "$ROOT/tests/unit"
  assert_success
}
