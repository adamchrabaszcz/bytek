#!/usr/bin/env bash
# Renders every state across all its frames and checks that the bot never shifts:
# 4 lines, fixed box edges, the antenna in column 5 and 3-character faces.
# Usage: tests/core.sh

export LC_ALL=en_US.UTF-8
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BYTEK="$ROOT/bin/bytek"
export BYTEK_HOME
BYTEK_HOME=$(mktemp -d)
trap 'rm -rf "$BYTEK_HOME"' EXIT

fails=0
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; fails=$((fails + 1)); }

check_render() { # name output
  local name=$1 out=$2 n=0 l1="" l2="" l3="" l4="" line
  while IFS= read -r line; do
    n=$((n + 1))
    case $n in 1) l1=$line ;; 2) l2=$line ;; 3) l3=$line ;; 4) l4=$line ;; esac
  done <<< "$out"
  [ "$n" -eq 4 ]                   || fail "$name" "expected 4 lines, got $n"
  [ "${l1:0:4}" = "    " ]         || fail "$name" "antenna not in column 5: '$l1'"
  [ "${l1:4:1}" != " " ]           || fail "$name" "antenna missing: '$l1'"
  [ "$l2" = " ╭──┴──╮" ]           || fail "$name" "box top shifted: '$l2'"
  [ "${l3:0:3}" = " │ " ]          || fail "$name" "face line start: '$l3'"
  [ "${l3:6:2}" = " │" ]           || fail "$name" "face not 3 characters: '$l3'"
  [ "${l4:0:8}" = " ╰─┬─┬─╯" ]     || fail "$name" "box bottom shifted: '$l4'"
}

for face in "$ROOT"/faces/*; do
  state=${face##*/}
  "$BYTEK" set "$state" "src/api.ts" --progress 3/5 || fail "$state" "set failed"
  for t in 0 1 2 3 4 5 6 7 8 9 10 11; do
    out=$(printf '{"session_id":"none"}' | BYTEK_NOW=$((1000 + t)) "$BYTEK" render)
    check_render "$state@$t" "$out"
  done
done

# Long inactivity turns into sleeping.
BYTEK_NOW=1000 "$BYTEK" set idle
out=$(printf '{}' | BYTEK_NOW=1700 "$BYTEK" render)
case "$out" in *"idle for 11m"*) ;; *) fail sleeping "expected 'idle for 11m' in: $out" ;; esac

# Per-session state wins over the default one.
"$BYTEK" set error --session abc-123
out=$(printf '{"session_id":"abc-123"}' | "$BYTEK" render)
case "$out" in *"something failed"*) ;; *) fail session "per-session state not used: $out" ;; esac

# Narrow terminals cut long text.
"$BYTEK" set editing "a/very/long/path/that/does/not/fit/anywhere/in/a/narrow/window.ts"
out=$(printf '{}' | COLUMNS=30 "$BYTEK" render)
case "$out" in *"…"*) ;; *) fail truncate "expected … in: $out" ;; esac

# A broken data directory still prints something.
out=$(printf '{}' | BYTEK_ROOT=/nonexistent "$BYTEK" render)
[ -n "$out" ] || fail fallback "no output when data is missing"

if [ "$fails" -eq 0 ]; then echo "ok: all states render aligned"; else echo "$fails failure(s)"; exit 1; fi
