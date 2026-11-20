#!/usr/bin/env bats
# lib/locale.sh: picking a locale that counts characters.
# shellcheck disable=SC2030,SC2031 # each test sets its environment in its own subshell, on purpose

load ../helpers

setup() {
  bytek_setup
  load_module locale
}

@test "a working UTF-8 locale is picked and counts characters" {
  unset BYTEK_LOCALE
  export LC_ALL=C LC_CTYPE="" LANG="" BYTEK_LOCALE_CANDIDATES="no_SUCH.UTF-8 en_US.UTF-8"
  locale_pick
  assert_equal "$BYTEK_UTF8|$LC_ALL" "1|en_US.UTF-8"
}

@test "BYTEK_LOCALE comes first" {
  export BYTEK_LOCALE=en_US.UTF-8 LC_ALL=C BYTEK_LOCALE_CANDIDATES="no_SUCH.UTF-8"
  locale_pick
  assert_equal "$BYTEK_UTF8|$LC_ALL" "1|en_US.UTF-8"
}

@test "with no working UTF-8 locale it falls back to C and counts bytes" {
  unset BYTEK_LOCALE
  export LC_ALL=C LC_CTYPE="" LANG="" BYTEK_LOCALE_CANDIDATES="no_SUCH.UTF-8"
  locale_pick 2>/dev/null
  assert_equal "$BYTEK_UTF8|$LC_ALL" "0|C"
}
