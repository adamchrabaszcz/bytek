#!/usr/bin/env bash
# Throwaway file for checking the AI review (#90); this pull request is never merged.

set +o errexit +o nounset +o pipefail # declared, not inherited (CONTRIBUTING, "Shell options")

# Prints the last N arguments after the first: last 2 a b c prints "b" and "c".
last() {
  local n=$1 i
  shift
  for ((i = $# - n; i <= $#; i++)); do
    printf '%s\n' "${!i}"
  done
}

last "$@"
