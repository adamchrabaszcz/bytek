#!/usr/bin/env bats
# tests/run.sh: runs bats files, fails when a test fails, and writes the job summary table.

load helpers

RUN="$ROOT/tests/run.sh"

setup() {
  # Under coverage these run bats inside bats, all traced, for tests/run.sh, which the report
  # leaves out: minutes of tracing for no coverage.
  [ "${BYTEK_COVERAGE:-}" = 1 ] && skip "tests/run.sh is not in the coverage report"
  bytek_setup
  mkdir "$TMP/pass" "$TMP/mixed"
  printf '@test "fine" { true; }\n@test "noted" { echo "# 12 ms" >&3; }\n@test "later" { skip "not yet"; }\n' >"$TMP/pass/a.bats"
  printf '@test "fine" { true; }\n' >"$TMP/mixed/a.bats"
  printf '@test "broken" { false; }\n' >"$TMP/mixed/b.bats"
}

@test "passing files pass, with counts and notes in the summary" {
  GITHUB_STEP_SUMMARY="$TMP/pass.md" run "$RUN" "$TMP/pass"
  assert_success
  assert_output "a.bats: 2 passed, 1 skipped (12 ms)"
  grep -qF '| `a.bats` | ok | 2 passed, 1 skipped | 12 ms |' "$TMP/pass.md" ||
    fail "no ok row in: $(cat "$TMP/pass.md")"
}

@test "a failing test fails the run, shows its output and a failed row" {
  GITHUB_STEP_SUMMARY="$TMP/mixed.md" run "$RUN" "$TMP/mixed"
  assert_failure
  assert_output --partial "b.bats: 0 passed, 1 failed"
  assert_output --partial "not ok 1 broken"
  grep -qF '| `b.bats` | failed | 0 passed, 1 failed |' "$TMP/mixed.md" ||
    fail "no failed row in: $(cat "$TMP/mixed.md")"
}

@test "without GitHub Actions there is no summary file" {
  run env -u GITHUB_STEP_SUMMARY "$RUN" "$TMP/pass"
  assert_success
  assert_output "a.bats: 2 passed, 1 skipped (12 ms)"
}

@test "-j runs files at the same time and still reports them in file order" {
  # a.bats waits for a mark that only b.bats leaves: one at a time, a.bats would give up.
  mkdir "$TMP/together"
  printf '@test "waits" { for i in $(seq 50); do [ -f "$MARK" ] && return 0; sleep 0.1; done; false; }\n' >"$TMP/together/a.bats"
  printf '@test "marks" { touch "$MARK"; }\n' >"$TMP/together/b.bats"
  MARK="$TMP/mark" run "$RUN" -j 2 "$TMP/together"
  assert_success
  assert_output "a.bats: 1 passed
b.bats: 1 passed"
}

@test "-j needs a positive number" {
  for bad in "-j" "-j 0" "-j x" "--fast"; do
    # shellcheck disable=SC2086 # splitting "-j 0" into two arguments is the point
    run "$RUN" $bad "$TMP/pass"
    assert_failure 2
    assert_output --partial "usage: tests/run.sh [-j N] [dir]"
  done
}
