#!/usr/bin/env bats
# tools/coverage-summary.sh against bashcov-shaped reports (SimpleCov's coverage.json).

bats_require_minimum_version 1.5.0
load helpers

TOOL="$ROOT/tools/coverage-summary.sh"

EXPECTED='## Coverage: 83.8% of lines

| File | Lines | % |
| --- | --- | --- |
| `bin/bytek` | 250/300 | 83.3 |
| `tools/format-check.sh` | 18/20 | 90 |'

setup() {
  bytek_setup
  needs_jq
  mkdir -p "$TMP/coverage" "$TMP/empty"
  cat >"$TMP/coverage/coverage.json" <<'EOF'
{
  "meta": { "simplecov_version": "1.3.2" },
  "total": { "lines": { "covered": 268, "missed": 52, "total": 320, "percent": 83.75 } },
  "coverage": {
    "tools/format-check.sh": { "covered_lines": 18, "total_lines": 20, "lines_covered_percent": 90.0 },
    "bin/bytek": { "covered_lines": 250, "total_lines": 300, "lines_covered_percent": 83.33333 },
    "tools/release-marks.sh": { "covered_lines": 0, "total_lines": 0, "lines_covered_percent": 100.0 }
  }
}
EOF
  jq 'del(.coverage."tools/release-marks.sh")' "$TMP/coverage/coverage.json" >"$TMP/report.json"
  printf '{"coverage": {}, "total": {"lines": {"percent": 0}}}' >"$TMP/empty/coverage.json"
}

@test "a report becomes a table per file with the total" {
  run "$TOOL" "$TMP/report.json"
  assert_success
  assert_output "$EXPECTED"
}

@test "a coverage folder is read from its coverage.json" {
  run "$TOOL" "$TMP/coverage"
  assert_success
  assert_output --partial '| `bin/bytek` | 250/300 | 83.3 |'
}

@test "a missing report exits 2" {
  run "$TOOL" "$TMP/missing.json"
  assert_failure 2
  run "$TOOL" "$TMP/nowhere"
  assert_failure 2
}

@test "a report covering no files exits 1" {
  run "$TOOL" "$TMP/empty"
  assert_failure 1
}

@test "--require passes when every named file has covered lines" {
  run "$TOOL" "$TMP/report.json" --require bin/bytek tools/format-check.sh
  assert_success
  assert_output "$EXPECTED"
}

@test "--require fails for a file missing from the report" {
  run --separate-stderr "$TOOL" "$TMP/report.json" --require bin/bytek tools/close-parent.sh
  assert_failure 1
  assert_equal "$stderr" $'coverage-summary: required files without coverage:\ntools/close-parent.sh: not in the coverage report'
}

@test "--require fails for a file with no covered lines" {
  run --separate-stderr "$TOOL" "$TMP/coverage" --require bin/bytek tools/release-marks.sh
  assert_failure 1
  assert_equal "${stderr_lines[1]}" "tools/release-marks.sh: no covered lines"
}
