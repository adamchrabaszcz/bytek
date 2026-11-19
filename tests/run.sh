#!/usr/bin/env bash
# Runs every test script in tests/ and fails if any of them fails.
# Usage: tests/run.sh

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
status=0
for t in "$dir"/*.sh; do
  [ "${t##*/}" = run.sh ] && continue
  printf '%s: ' "${t##*/}"
  bash "$t" || status=1
done
exit $status
