#!/usr/bin/env bash
# Runs every bats test file in a directory (default: tests/) with the bats vendored in
# tests/bats/ and fails if any test fails. Prints one line per file, in file order, and the
# full bats output for a file with failures. In GitHub Actions ($GITHUB_STEP_SUMMARY set) it
# also writes a table of files, results and notes (lines a test writes as "# ..." to fd 3).
# Usage: tests/run.sh [-j N] [dir]
#   -j N   run up to N files at a time (default 1: the speed test wants a quiet machine).
#          Files don't share state: each test gets its own temp folder (tests/helpers.bash).

set +o errexit +o nounset +o pipefail # declared, not inherited (CONTRIBUTING, "Shell options")

usage() {
  echo "usage: tests/run.sh [-j N] [dir]" >&2
  exit 2
}

parallel=1
case "${1:-}" in
  -j)
    [[ "${2:-}" =~ ^[1-9][0-9]*$ ]] || usage
    parallel=$2
    shift 2
    ;;
  -*) usage ;;
esac

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="${1:-$here}"
bats="$here/bats/core/bin/bats"
[ -x "$bats" ] || {
  echo "tests/run.sh: bats is missing; run: git submodule update --init" >&2
  exit 2
}

results=$(mktemp -d "${TMPDIR:-/tmp}/bytek-run.XXXXXX") || exit 2
trap 'rm -rf "$results"' EXIT

# Runs one file, leaving its TAP output in $results/<name>.out and then "ok" or "failed" in
# .result; .result appears (renamed into place) only once the file is done.
run_file() {
  local name=${1##*/} result=ok
  "$bats" --tap "$1" >"$results/$name.out" 2>&1 || result=failed
  echo "$result" >"$results/$name.tmp" && mv "$results/$name.tmp" "$results/$name.result"
}

# Starts the files in the background, at most $parallel at a time (bash 3.2 has no `wait -n`,
# so a free slot is found by counting the running jobs), while the loop below reports them.
(
  for t in "$dir"/*.bats; do
    [ -f "$t" ] || continue
    while [ "$(jobs -pr | wc -l)" -ge "$parallel" ]; do sleep 0.1; done
    run_file "$t" &
  done
  wait
) &
launcher=$!

# Reports each file in file order, as soon as it is done. The launcher waits for every file,
# so if it's gone and a result is still missing, that file never finished.
status=0
rows=""
for t in "$dir"/*.bats; do
  [ -f "$t" ] || continue
  name=${t##*/}
  until [ -f "$results/$name.result" ] || ! kill -0 "$launcher" 2>/dev/null; do sleep 0.1; done
  if [ -f "$results/$name.result" ]; then
    result=$(cat "$results/$name.result")
  else
    result=failed
    echo "tests/run.sh: $name never finished" >>"$results/$name.out"
  fi
  out=$(cat "$results/$name.out" 2>/dev/null)
  [ "$result" = ok ] || status=1
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
wait

if [ -n "$GITHUB_STEP_SUMMARY" ]; then
  {
    printf '### Tests on %s, bash %s\n\n' "${RUNNER_OS:-$(uname -s)}" "${BASH_VERSION%%(*}"
    printf '| File | Result | Tests | Notes |\n| --- | --- | --- | --- |\n%s\n' "$rows"
  } >>"$GITHUB_STEP_SUMMARY"
fi
exit $status
