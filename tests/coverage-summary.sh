#!/usr/bin/env bash
# Checks tools/coverage-summary.sh against a kcov-shaped report.
# Usage: tests/coverage-summary.sh

TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tools/coverage-summary.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

command -v jq >/dev/null || { echo "skip: jq not installed"; exit 0; }

# kcov writes numbers as strings.
cat > "$tmp/coverage.json" <<'EOF'
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

expected='## Coverage: 83.9% of lines

| File | Lines | % |
| --- | --- | --- |
| `bin/bytek` | 250/300 | 83.3 |
| `tools/format-check.sh` | 18/20 | 90 |'

fails=0
got=$("$TOOL" "$tmp/coverage.json" /work/)
[ "$got" = "$expected" ] || { printf 'FAIL table: expected\n%s\ngot\n%s\n' "$expected" "$got"; fails=$((fails + 1)); }

"$TOOL" "$tmp/missing.json" 2>/dev/null; code=$?
[ "$code" -eq 2 ] || { echo "FAIL missing: expected exit 2, got $code"; fails=$((fails + 1)); }

# kcov output folders: a single run lands in <script>.<hash>/, merged runs in kcov-merged/.
mkdir -p "$tmp/single/run.sh.56ea0005" "$tmp/merged/run.sh.1" "$tmp/merged/kcov-merged" "$tmp/none"
cp "$tmp/coverage.json" "$tmp/single/run.sh.56ea0005/"
cp "$tmp/coverage.json" "$tmp/merged/kcov-merged/"
printf '{"files": [], "percent_covered": "0"}' > "$tmp/merged/run.sh.1/coverage.json"

got=$("$TOOL" "$tmp/single" /work/)
[ "$got" = "$expected" ] || { printf 'FAIL single-dir: got\n%s\n' "$got"; fails=$((fails + 1)); }
got=$("$TOOL" --report-dir "$tmp/single")
[ "$got" = "$tmp/single/run.sh.56ea0005" ] || { echo "FAIL report-dir: got '$got'"; fails=$((fails + 1)); }
got=$("$TOOL" --report-dir "$tmp/merged")
[ "$got" = "$tmp/merged/kcov-merged" ] || { echo "FAIL merged-first: got '$got'"; fails=$((fails + 1)); }

"$TOOL" "$tmp/none" 2>/dev/null; code=$?
[ "$code" -eq 2 ] || { echo "FAIL no-report: expected exit 2, got $code"; fails=$((fails + 1)); }
"$TOOL" "$tmp/merged/run.sh.1/coverage.json" 2>/dev/null; code=$?
[ "$code" -eq 1 ] || { echo "FAIL empty-report: expected exit 1, got $code"; fails=$((fails + 1)); }

if [ "$fails" -eq 0 ]; then echo "ok: coverage summary lists files and the total"; else echo "$fails failure(s)"; exit 1; fi
