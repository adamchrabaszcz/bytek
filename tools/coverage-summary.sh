#!/usr/bin/env bash
# Turns bashcov's coverage report (SimpleCov's coverage.json, schema 1.3) into a Markdown table
# for the GitHub job summary. Needs jq.
#
#   tools/coverage-summary.sh <coverage dir | coverage.json> [--require FILE...]
#
# Fails when there is no report or it covers no files. With --require, also fails when one of
# the named files (paths relative to the repository, as in the table) is missing from the report
# or has no covered lines: a script whose tests run but whose coverage silently vanished (#59).

set +o errexit +o nounset +o pipefail # declared, not inherited (CONTRIBUTING, "Shell options")

source=${1:-}
shift
report=$source
if [ -d "$source" ]; then report="$source/coverage.json"; fi
required=()
if [ "${1:-}" = --require ]; then
  shift
  required=("$@")
fi

[ -f "$report" ] || {
  echo "coverage-summary: no coverage report in ${source:-?}" >&2
  exit 2
}
jq -e '(.coverage // {} | length) > 0' "$report" >/dev/null 2>&1 || {
  echo "coverage-summary: the report covers no files: $report" >&2
  exit 1
}

jq -r '
  def pct: . * 10 | round / 10;
  "## Coverage: \(.total.lines.percent | pct)% of lines",
  "",
  "| File | Lines | % |",
  "| --- | --- | --- |",
  (.coverage | to_entries | sort_by(.key)[] |
    "| `\(.key)` | \(.value.covered_lines)/\(.value.total_lines) | \(.value.lines_covered_percent | pct) |")
' "$report"

[ ${#required[@]} -gt 0 ] || exit 0
problems=$(jq -r '
  .coverage as $files | $ARGS.positional[]
  | if $files[.] == null then "\(.): not in the coverage report"
    elif $files[.].covered_lines == 0 then "\(.): no covered lines"
    else empty end
' --args "${required[@]}" <"$report")
if [ -n "$problems" ]; then
  printf 'coverage-summary: required files without coverage:\n%s\n' "$problems" >&2
  exit 1
fi
