#!/usr/bin/env bash
# Checks how Bytek picks a UTF-8 locale: an explicit BYTEK_LOCALE, the user's own UTF-8
# locale, the fallbacks, and what happens when there is none (no warnings, no text cut).
# Runs Bytek with a minimal environment (env -i) so the machine's own locale doesn't leak in.
# Usage: tests/locale.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BYTEK="$ROOT/bin/bytek"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fails=0
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; fails=$((fails + 1)); }

# Runs Bytek from a plain C locale plus the given variables; stderr goes to $tmp/err.
clean() { env -i PATH="$PATH" HOME="$tmp" BYTEK_HOME="$tmp/home" LANG=C "$@" 2> "$tmp/err"; }
quiet() { [ ! -s "$tmp/err" ] || fail "$1" "printed to stderr: $(head -2 "$tmp/err")"; }

# A UTF-8 locale this machine really has (C.UTF-8 on Linux, en_US.UTF-8 on macOS, ...).
works=""
for candidate in C.UTF-8 en_US.UTF-8; do
  if [ "$(env -i LANG=C LC_ALL="$candidate" /bin/bash -c 'p="ᴗ"; echo ${#p}' 2>/dev/null)" = 1 ]; then
    works=$candidate
    break
  fi
done
[ -n "$works" ] || { echo "skip: no UTF-8 locale on this machine"; exit 0; }

got=$(clean BYTEK_LOCALE="$works" "$BYTEK" locale)
[ "$got" = "$works (utf8=1)" ] || fail explicit "expected '$works (utf8=1)', got '$got'"
quiet explicit

got=$(clean LANG="$works" "$BYTEK" locale)
[ "$got" = "$works (utf8=1)" ] || fail own "the user's UTF-8 locale should be kept, got '$got'"
quiet own

got=$(clean BYTEK_LOCALE_CANDIDATES="bogus.UTF-8 $works" "$BYTEK" locale)
[ "$got" = "$works (utf8=1)" ] || fail fallback "should skip the missing locale, got '$got'"
quiet fallback

got=$(clean LC_ALL=bogus.UTF-8 BYTEK_LOCALE_CANDIDATES="$works" "$BYTEK" locale)
[ "$got" = "$works (utf8=1)" ] || fail own-missing "a missing own locale should be skipped, got '$got'"
# Linux bash warns about a missing LC_ALL from the environment once at start-up, before any
# script line runs; that one line is allowed, a second (from Bytek itself) is not.
startup=$(grep -c 'setlocale: LC_ALL: cannot change locale (bogus.UTF-8)' "$tmp/err")
[ "$startup" -le 1 ] || fail own-missing "Bytek repeated the locale warning ($startup times)"
grep -v 'setlocale: LC_ALL: cannot change locale (bogus.UTF-8)' "$tmp/err" > "$tmp/err.rest"
mv "$tmp/err.rest" "$tmp/err"
quiet own-missing

# No UTF-8 locale at all: Bytek still renders, says nothing, and doesn't cut text.
got=$(clean BYTEK_LOCALE_CANDIDATES="bogus.UTF-8" "$BYTEK" locale)
[ "$got" = "C (utf8=0)" ] || fail none "expected 'C (utf8=0)', got '$got'"
quiet none
clean BYTEK_LOCALE_CANDIDATES="bogus.UTF-8" "$BYTEK" set editing "src/ścieżka/z/polskimi/znakami/że/się/nie/mieści.ts"
quiet none-set
out=$(printf '{"session_id":"default"}' | clean BYTEK_LOCALE_CANDIDATES="bogus.UTF-8" COLUMNS=30 "$BYTEK" render)
quiet none-render
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 4 ] || fail none-render "expected 4 lines: $out"
case "$out" in *"mieści.ts"*) ;; *) fail none-render "text was cut without a UTF-8 locale: $out" ;; esac

# With a UTF-8 locale the same text is cut to the width, on a character boundary.
out=$(printf '{"session_id":"default"}' | clean BYTEK_LOCALE="$works" COLUMNS=30 "$BYTEK" render)
quiet utf8-render
case "$out" in *"…"*) ;; *) fail utf8-render "long text not cut: $out" ;; esac

if [ "$fails" -eq 0 ]; then echo "ok: picks a working UTF-8 locale ($works here) and copes without one"; else echo "$fails failure(s)"; exit 1; fi
