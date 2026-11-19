#!/usr/bin/env bats
# tools/lint.sh: covers every shell file, reports findings from either tool, and the
# repository itself passes ShellCheck and shfmt.

load helpers

LINT="$ROOT/tools/lint.sh"

setup() {
  bytek_setup
  # Stand-in tools: they print a version, record their arguments and exit with $FAKE_EXIT_<NAME>.
  mkdir -p "$TMP/fake"
  for tool in shellcheck shfmt; do
    printf '#!/bin/sh\ncase "$1" in --version) echo "version: 9.9"; exit 0 ;; esac\necho "$*" >> "%s/%s.args"\nexit "${FAKE_EXIT_%s:-0}"\n' \
      "$TMP" "$tool" "$(echo "$tool" | tr '[:lower:]' '[:upper:]')" >"$TMP/fake/$tool"
    chmod +x "$TMP/fake/$tool"
  done
  export SHELLCHECK="$TMP/fake/shellcheck" SHFMT="$TMP/fake/shfmt"
}

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

@test "clean when both tools pass, each run on every file" {
  run "$LINT"
  assert_success
  assert_output --partial "lint: clean"
  grep -q 'bin/bytek' "$TMP/shellcheck.args"
  grep -q '^-d .*bin/bytek' "$TMP/shfmt.args"
}

@test "a ShellCheck finding fails the run" {
  FAKE_EXIT_SHELLCHECK=1 run "$LINT"
  assert_failure 1
  refute_output --partial "lint: clean"
}

@test "a formatting difference fails the run" {
  FAKE_EXIT_SHFMT=1 run "$LINT"
  assert_failure 1
  refute_output --partial "lint: clean"
}

@test "a missing tool is named, with how to install it" {
  SHFMT="$TMP/nowhere/shfmt" run "$LINT"
  assert_failure 2
  assert_output --partial "is not installed"
}

@test "--fix lets shfmt rewrite the files" {
  run "$LINT" --fix
  assert_success
  grep -q '^-w .*bin/bytek' "$TMP/shfmt.args"
}

@test "an unknown option prints usage" {
  run "$LINT" --nope
  assert_failure 2
  assert_output --partial "tools/lint.sh --fix"
}

@test "the repository passes the real ShellCheck and shfmt" {
  unset SHELLCHECK SHFMT
  command -v shellcheck >/dev/null && command -v shfmt >/dev/null || skip "shellcheck or shfmt not installed"
  run "$LINT"
  assert_success
  assert_output --partial "lint: clean"
}
