#!/usr/bin/env bash
# Turns kcov's coverage.json into a Markdown table for the GitHub job summary. Needs jq.
#
#   tools/coverage-summary.sh <kcov dir | coverage.json> [path prefix to strip]
#   tools/coverage-summary.sh --report-dir <kcov dir>     prints the folder holding the report
#
# kcov writes its report to <dir>/kcov-merged/ when it merges runs and to <dir>/<script>.<hash>/
# otherwise; both are found. Fails when there is no report or it covers no files, so a
# broken coverage run can't pass unnoticed.

# Sets REPORT to the coverage.json inside kcov output dir $1 (kcov-merged first).
find_report() {
  local f
  REPORT=""
  if [ -f "$1/kcov-merged/coverage.json" ]; then REPORT="$1/kcov-merged/coverage.json"; return; fi
  for f in "$1"/*/coverage.json; do
    [ -f "$f" ] && { REPORT=$f; return; }
  done
}

if [ "$1" = --report-dir ]; then
  find_report "$2"
  [ -n "$REPORT" ] || { echo "coverage-summary: no kcov report in ${2:-?}" >&2; exit 2; }
  printf '%s\n' "${REPORT%/coverage.json}"
  exit 0
fi

if [ -d "$1" ]; then find_report "$1"; else REPORT=$1; fi
prefix=${2:-}
[ -f "$REPORT" ] || { echo "coverage-summary: no kcov report in ${1:-?}" >&2; exit 2; }
jq -e '(.files | length) > 0' "$REPORT" >/dev/null || { echo "coverage-summary: the report covers no files: $REPORT" >&2; exit 1; }

jq -r --arg prefix "$prefix" '
  def pct: tonumber * 10 | round / 10;
  "## Coverage: \(.percent_covered | pct)% of lines",
  "",
  "| File | Lines | % |",
  "| --- | --- | --- |",
  (.files | sort_by(.file)[] |
    "| `\(.file | ltrimstr($prefix))` | \(.covered_lines)/\(.total_lines) | \(.percent_covered | pct) |")
' "$REPORT"
