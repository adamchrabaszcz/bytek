#!/usr/bin/env bash
# Turns kcov's coverage.json into a Markdown table for the GitHub job summary. Needs jq.
#
#   tools/coverage-summary.sh <coverage.json> [path prefix to strip]

json=$1 prefix=${2:-}
[ -f "$json" ] || { echo "coverage-summary: no such file: $json" >&2; exit 2; }

jq -r --arg prefix "$prefix" '
  def pct: tonumber * 10 | round / 10;
  "## Coverage: \(.percent_covered | pct)% of lines",
  "",
  "| File | Lines | % |",
  "| --- | --- | --- |",
  (.files | sort_by(.file)[] |
    "| `\(.file | ltrimstr($prefix))` | \(.covered_lines)/\(.total_lines) | \(.percent_covered | pct) |")
' "$json"
