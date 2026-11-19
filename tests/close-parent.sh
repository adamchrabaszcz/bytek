#!/usr/bin/env bash
# Checks when tools/close-parent.sh decides to close a parent issue.
# Usage: tests/close-parent.sh

TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tools/close-parent.sh"

fails=0
expect() { # name input expected
  local got
  got=$("$TOOL" --decide "$2")
  [ "$got" = "$3" ] || { printf "FAIL %s: expected '%s', got '%s'\n" "$1" "$3" "$got"; fails=$((fails + 1)); }
}

expect last-done    "12 OPEN 3 3"   "close"
expect not-yet      "12 OPEN 2 3"   "parent #12: 2 of 3 sub-issues done"
expect closed       "12 CLOSED 3 3" "parent #12 is already closed"
expect no-parent    ""              "no parent"

out=$(REPO= "$TOOL" 5 2>&1); code=$?
[ "$code" -eq 2 ] || { echo "FAIL usage: expected exit 2 without REPO, got $code ($out)"; fails=$((fails + 1)); }

if [ "$fails" -eq 0 ]; then echo "ok: parents close only after their last sub-issue"; else echo "$fails failure(s)"; exit 1; fi
