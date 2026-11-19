#!/usr/bin/env bash
# Runs every test script in a directory (default: tests/) and fails if any of them fails.
# In GitHub Actions ($GITHUB_STEP_SUMMARY set) it also writes a table of suites to the job summary.
# Usage: tests/run.sh [dir]

dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
status=0
rows=""
for t in "$dir"/*.sh; do
  name=${t##*/}
  [ "$name" = run.sh ] && continue
  printf '%s: ' "$name"
  if out=$(bash "$t" 2>&1); then
    result="ok"
  else
    result="failed"
    status=1
  fi
  printf '%s\n' "$out"
  rows="$rows| \`$name\` | $result | $(printf '%s' "$out" | tail -1 | tr '|' '/') |
"
done

if [ -n "$GITHUB_STEP_SUMMARY" ]; then
  {
    printf '### Tests on %s, bash %s\n\n' "${RUNNER_OS:-$(uname -s)}" "${BASH_VERSION%%(*}"
    printf '| Suite | Result | Last line |\n| --- | --- | --- |\n%s\n' "$rows"
  } >> "$GITHUB_STEP_SUMMARY"
fi
exit $status
