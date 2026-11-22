# shellcheck shell=bash
# shellcheck disable=SC2034 # CHARSET is this module's output, read by render, addon, preview and doctor
# charset: which characters Bytek draws with. "unicode", the default, draws with glyphs such as
# ♡ ᴗ ╭─╮, some of them East Asian "ambiguous" width: one column in most terminals, two where
# "ambiguous characters are wide" is on, which breaks the box. "ascii" draws with plain ASCII:
# data files give it as "<key>_ascii" lines, the render has its own set. Chosen with
# `bytek charset`, kept in $BYTEK_HOME/config/bytek as "charset = ascii". Plain file reads on
# the render path.
# Needs: nothing; from bin/bytek: BYTEK_HOME, die (charset_set).

CHARSET_FILE="$BYTEK_HOME/config/bytek"
CHARSET_NAMES="unicode ascii"

# Sets CHARSET to the one named in CHARSET_FILE, or unicode when it names none Bytek knows.
charset_load() {
  local line key val
  CHARSET=unicode
  [ -f "$CHARSET_FILE" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'*) continue ;; esac
    key=${line%%=*}
    key=${key//[[:space:]]/}
    [ "$key" = charset ] && [[ "$line" == *=* ]] || continue
    val=${line#*=}
    val=${val//[[:space:]]/}
    case " $CHARSET_NAMES " in *" $val "*) CHARSET=$val ;; esac
  done <"$CHARSET_FILE"
}

# For readers of data files: call before reading a file's first line, for charset_key.
charset_start() {
  CHARSET_SEEN=" "
}

# For readers of data files: sets REPLY to the key that data file key $1 fills in the current
# charset, or returns 1 when its line is to be skipped. In ascii, "frames_ascii" fills frames,
# and a plain "frames" no longer does once it has; elsewhere "_ascii" lines are skipped.
charset_key() {
  case "$1" in
    *_ascii)
      [ "$CHARSET" = ascii ] || return 1
      REPLY=${1%_ascii}
      CHARSET_SEEN="$CHARSET_SEEN$REPLY "
      ;;
    *)
      case "$CHARSET_SEEN" in *" $1 "*) return 1 ;; esac
      REPLY=$1
      ;;
  esac
}

# bytek charset [unicode|ascii]: with a name, draws with that charset from the next render;
# without, prints the current one. Every other line of CHARSET_FILE stays as it is.
charset_set() {
  local line key kept=""
  if [ -z "$1" ]; then
    charset_load
    printf '%s\n' "$CHARSET"
    return 0
  fi
  case " $CHARSET_NAMES " in *" $1 "*) ;; *) die "unknown charset: $1 (unicode or ascii)" ;; esac
  if [ -f "$CHARSET_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      key=${line%%=*}
      [ "${key//[[:space:]]/}" = charset ] && [[ "$line" == *=* ]] && continue
      kept="$kept$line"$'\n'
    done <"$CHARSET_FILE"
  fi
  mkdir -p "${CHARSET_FILE%/*}" || die "cannot create ${CHARSET_FILE%/*}"
  if ! { printf '%scharset = %s\n' "$kept" "$1" >"$CHARSET_FILE.tmp" && mv "$CHARSET_FILE.tmp" "$CHARSET_FILE"; }; then
    die "cannot write $CHARSET_FILE"
  fi
}
