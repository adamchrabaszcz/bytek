#!/usr/bin/env bats
# tools/coverage-summary.sh against kcov-shaped reports and output folders.

load helpers

TOOL="$ROOT/tools/coverage-summary.sh"

EXPECTED='## Coverage: 83.9% of lines

| File | Lines | % |
| --- | --- | --- |
| `bin/bytek` | 250/300 | 83.3 |
| `tools/format-check.sh` | 18/20 | 90 |'

setup() {
  bytek_setup
  needs_jq
  # kcov writes numbers as strings.
  cat > "$TMP/coverage.json" <<'EOF'
{
  "files": [
    {"file": "/work/tools/format-check.sh", "percent_covered": "90.00", "covered_lines": "18", "total_lines": "20"},
    {"file": "/work/bin/bytek", "percent_covered": "83.33", "covered_lines": "250", "total_lines": "300"}
  ],
  "percent_covered": "83.94",
  "covered_lines": 268,
  "total_lines": 320
}
EOF
  # kcov output folders: a single run lands in <script>.<hash>/, merged runs in kcov-merged/.
  mkdir -p "$TMP/single/run.sh.56ea0005" "$TMP/merged/run.sh.1" "$TMP/merged/kcov-merged" "$TMP/none"
  cp "$TMP/coverage.json" "$TMP/single/run.sh.56ea0005/"
  cp "$TMP/coverage.json" "$TMP/merged/kcov-merged/"
  printf '{"files": [], "percent_covered": "0"}' > "$TMP/merged/run.sh.1/coverage.json"
}

@test "a report becomes a table per file with the total" {
  run "$TOOL" "$TMP/coverage.json" /work/
  assert_output "$EXPECTED"
}

@test "a kcov output folder is searched for the report" {
  run "$TOOL" "$TMP/single" /work/
  assert_output "$EXPECTED"
  run "$TOOL" --report-dir "$TMP/single"
  assert_output "$TMP/single/run.sh.56ea0005"
}

@test "a merged report is preferred" {
  run "$TOOL" --report-dir "$TMP/merged"
  assert_output "$TMP/merged/kcov-merged"
}

@test "a missing report exits 2" {
  run "$TOOL" "$TMP/missing.json"
  assert_failure 2
  run "$TOOL" "$TMP/none"
  assert_failure 2
}

@test "a report covering no files exits 1" {
  run "$TOOL" "$TMP/merged/run.sh.1/coverage.json"
  assert_failure 1
}
