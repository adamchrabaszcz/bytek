#!/usr/bin/env bash
# Runs every bats test file in a directory (default: tests/) with the bats vendored in
# tests/bats/, one file at a time, and fails if any test fails. Prints one line per file, and
# the full bats output for a file with failures. In GitHub Actions ($GITHUB_STEP_SUMMARY set)
# it also writes a table of files, results and notes (lines a test writes as "# ..." to fd 3).
# Usage: tests/run.sh [dir]

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="${1:-$here}"
bats="$here/bats/core/bin/bats"
[ -x "$bats" ] || { echo "tests/run.sh: bats is missing; run: git submodule update --init" >&2; exit 2; }

status=0
rows=""
for t in "$dir"/*.bats; do
  [ -f "$t" ] || continue
  name=${t##*/}
  out=$("$bats" --tap "$t" 2>&1) && result=ok || { result=failed; status=1; }
  passed=$(printf '%s\n' "$out" | grep -E '^ok ' | grep -vc '# skip')
  skipped=$(printf '%s\n' "$out" | grep -E '^ok .*# skip' -c)
  failed=$(printf '%s\n' "$out" | grep -c '^not ok ')
  counts="$passed passed"
  [ "$failed" -gt 0 ] && counts="$counts, $failed failed"
  [ "$skipped" -gt 0 ] && counts="$counts, $skipped skipped"
  # A note is what a passing file says on fd 3; a failing file's "# ..." lines are its errors.
  note=""
  [ "$result" = ok ] && note=$(printf '%s\n' "$out" | sed -n 's/^# \(.*\)/\1/p' | head -1 | tr '|' '/')
  printf '%s: %s%s\n' "$name" "$counts" "${note:+ ($note)}"
  [ "$result" = ok ] || printf '%s\n' "$out" | sed 's/^/    /'
  rows="$rows| \`$name\` | $result | $counts | $note |
"
done

if [ -n "$GITHUB_STEP_SUMMARY" ]; then
  {
    printf '### Tests on %s, bash %s\n\n' "${RUNNER_OS:-$(uname -s)}" "${BASH_VERSION%%(*}"
    printf '| File | Result | Tests | Notes |\n| --- | --- | --- | --- |\n%s\n' "$rows"
  } >> "$GITHUB_STEP_SUMMARY"
fi
exit $status
