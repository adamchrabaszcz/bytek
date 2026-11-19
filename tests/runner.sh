#!/usr/bin/env bash
# Checks tests/run.sh: it fails when a suite fails and writes the job summary table.
# Usage: tests/runner.sh

RUN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fails=0
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; fails=$((fails + 1)); }

mkdir "$tmp/pass" "$tmp/mixed"
printf 'echo "ok: fine"\n' > "$tmp/pass/a.sh"
printf 'echo "ok: fine"\n' > "$tmp/mixed/a.sh"
printf 'echo "FAIL x: broken"; exit 1\n' > "$tmp/mixed/b.sh"

GITHUB_STEP_SUMMARY="$tmp/pass.md" bash "$RUN" "$tmp/pass" >/dev/null \
  || fail pass "exited non-zero with only passing suites"
grep -q '^| `a.sh` | ok | ok: fine |$' "$tmp/pass.md" || fail pass-summary "no ok row in: $(cat "$tmp/pass.md")"

GITHUB_STEP_SUMMARY="$tmp/mixed.md" bash "$RUN" "$tmp/mixed" >/dev/null \
  && fail mixed "exited 0 with a failing suite"
grep -q '^| `b.sh` | failed | FAIL x: broken |$' "$tmp/mixed.md" || fail mixed-summary "no failed row in: $(cat "$tmp/mixed.md")"

out=$(env -u GITHUB_STEP_SUMMARY bash "$RUN" "$tmp/pass")
case "$out" in "a.sh: ok: fine") ;; *) fail output "unexpected console output: $out" ;; esac

if [ "$fails" -eq 0 ]; then echo "ok: runner reports suites and failures"; else echo "$fails failure(s)"; exit 1; fi
