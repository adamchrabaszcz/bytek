#!/usr/bin/env bats
# How Bytek picks a UTF-8 locale: an explicit BYTEK_LOCALE, the user's own UTF-8 locale, the
# fallbacks, and what happens with none (no warnings, no text cut). Bytek runs in a minimal
# environment (env -i) so the machine's own locale doesn't leak in.

bats_require_minimum_version 1.5.0
load helpers

setup() {
  bytek_setup
  # A UTF-8 locale this machine really has (C.UTF-8 on Linux, en_US.UTF-8 on older macOS...).
  WORKS=""
  local candidate
  for candidate in C.UTF-8 en_US.UTF-8; do
    if [ "$(env -i LANG=C LC_ALL="$candidate" /bin/bash -c 'p="ᴗ"; echo ${#p}' 2>/dev/null)" = 1 ]; then
      WORKS=$candidate
      break
    fi
  done
  [ -n "$WORKS" ] || skip "no UTF-8 locale on this machine"
}

# Runs Bytek from a plain C locale plus the given variables.
clean() { env -i PATH="$PATH" HOME="$TMP" BYTEK_HOME="$BYTEK_HOME" LANG=C "$@"; }

@test "an explicit BYTEK_LOCALE is used" {
  run --separate-stderr clean BYTEK_LOCALE="$WORKS" "$BYTEK" locale
  assert_output "$WORKS (utf8=1)"
  assert_equal "$stderr" ""
}

@test "the user's own UTF-8 locale is kept" {
  run --separate-stderr clean LANG="$WORKS" "$BYTEK" locale
  assert_output "$WORKS (utf8=1)"
  assert_equal "$stderr" ""
}

@test "a missing fallback locale is skipped" {
  run --separate-stderr clean BYTEK_LOCALE_CANDIDATES="bogus.UTF-8 $WORKS" "$BYTEK" locale
  assert_output "$WORKS (utf8=1)"
  assert_equal "$stderr" ""
}

@test "a missing own locale is skipped, warning at most once (bash start-up)" {
  run --separate-stderr clean LC_ALL=bogus.UTF-8 BYTEK_LOCALE_CANDIDATES="$WORKS" "$BYTEK" locale
  assert_output "$WORKS (utf8=1)"
  # Linux bash warns once about a missing LC_ALL before any script line runs; Bytek adds none.
  local warnings others
  warnings=$(printf '%s\n' "$stderr" | grep -c 'cannot change locale (bogus.UTF-8)' || true)
  others=$(printf '%s\n' "$stderr" | grep -v 'cannot change locale (bogus.UTF-8)' | grep -c . || true)
  [ "$warnings" -le 1 ] || fail "Bytek repeated the locale warning ($warnings times)"
  assert_equal "$others" 0
}

@test "with no UTF-8 locale Bytek stays quiet, renders and doesn't cut text" {
  run --separate-stderr clean BYTEK_LOCALE_CANDIDATES="bogus.UTF-8" "$BYTEK" locale
  assert_output "C (utf8=0)"
  assert_equal "$stderr" ""
  clean BYTEK_LOCALE_CANDIDATES="bogus.UTF-8" "$BYTEK" set editing "src/ścieżka/z/polskimi/znakami/że/się/nie/mieści.ts"
  run --separate-stderr bash -c "printf '{\"session_id\":\"default\"}' | env -i PATH='$PATH' HOME='$TMP' BYTEK_HOME='$BYTEK_HOME' LANG=C BYTEK_LOCALE_CANDIDATES=bogus.UTF-8 COLUMNS=30 '$BYTEK' render"
  assert_equal "$stderr" ""
  assert_equal "${#lines[@]}" 4
  assert_output --partial "mieści.ts"
}

@test "with a UTF-8 locale long text is cut to the width" {
  "$BYTEK" set editing "src/ścieżka/z/polskimi/znakami/że/się/nie/mieści.ts"
  run --separate-stderr bash -c "printf '{\"session_id\":\"default\"}' | env -i PATH='$PATH' HOME='$TMP' BYTEK_HOME='$BYTEK_HOME' LANG=C BYTEK_LOCALE='$WORKS' COLUMNS=30 '$BYTEK' render"
  assert_equal "$stderr" ""
  assert_output --partial "…"
}
