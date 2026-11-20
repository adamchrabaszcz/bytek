# shellcheck shell=bash
# shellcheck disable=SC2034 # BYTEK_UTF8 is this module's output, read by render and bin/bytek
# locale: the locale Bytek counts characters in.
# Needs: nothing.
#
# Bytek counts characters, not bytes, to cut text and align the art, which needs a UTF-8
# locale. The first one that works wins: BYTEK_LOCALE, the user's own if it is UTF-8,
# C.UTF-8, en_US.UTF-8. "Works" is tested in bash itself (one multi-byte character must count
# as one), since an unknown name can fail silently. With none, BYTEK_UTF8=0: text isn't cut,
# so no character is split in half. BYTEK_LOCALE_CANDIDATES replaces the last two (for tests).

# Exports LC_ALL and sets BYTEK_UTF8 to 1 (a UTF-8 locale works) or 0.
locale_pick() {
  local own=${LC_ALL:-${LC_CTYPE:-$LANG}} candidate probe
  case "$own" in *[Uu][Tt][Ff]-8 | *[Uu][Tt][Ff]8 | *[Uu][Tt][Ff]-8@* | *[Uu][Tt][Ff]8@*) ;; *) own="" ;; esac
  for candidate in $BYTEK_LOCALE $own ${BYTEK_LOCALE_CANDIDATES:-C.UTF-8 en_US.UTF-8}; do
    { export LC_ALL="$candidate"; } 2>/dev/null
    probe="ᴗ"
    if [ "${#probe}" -eq 1 ]; then
      BYTEK_UTF8=1
      return
    fi
  done
  { export LC_ALL=C; } 2>/dev/null
  BYTEK_UTF8=0
}
