#!/usr/bin/env bats
# tools/lint.sh: covers every shell file, and the repository passes ShellCheck and shfmt.

load helpers

LINT="$ROOT/tools/lint.sh"

@test "every shell script in the repository is linted" {
  local listed f first missing=""
  listed=$("$LINT" --files)
  # Any tracked file whose first line is a bash or bats shebang must be on the list.
  while IFS= read -r f; do
    [ -f "$ROOT/$f" ] || continue
    first=$(head -1 "$ROOT/$f")
    case "$first" in
      '#!'*bash* | '#!'*bats*)
        printf '%s\n' "$listed" | grep -qx "$f" || missing="$missing $f"
        ;;
    esac
  done < <(git -C "$ROOT" ls-files 2>/dev/null)
  [ -z "$missing" ] || fail "not linted:$missing"
  printf '%s\n' "$listed" | grep -qx 'bin/bytek'
}

@test "the repository passes ShellCheck and shfmt" {
  command -v shellcheck >/dev/null && command -v shfmt >/dev/null || skip "shellcheck or shfmt not installed"
  run "$LINT"
  assert_success
  assert_output --partial "lint: clean"
}

@test "an unknown option prints usage" {
  run "$LINT" --nope
  assert_failure 2
  assert_output --partial "tools/lint.sh --fix"
}
