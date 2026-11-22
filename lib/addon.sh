# shellcheck shell=bash
# addon: the mood antenna, what sits on top of Bytek's antenna. Claude picks one now and then
# to show the session's vibe (docs/mood-antenna.md); the current one's name is in
# $BYTEK_HOME/addon, the add-ons themselves in addons/<name>. On the render path: plain file
# reads only, no subprocess.
# Needs: charset; from bin/bytek: BYTEK_ROOT, BYTEK_HOME, die (addon_set).

ADDON_DEFAULT=heart
ADDON_FALLBACK="♡"     # when even the default add-on file is missing
ADDON_FALLBACK_ASCII=v # the same, in the ascii charset
ADDON_FORMAT=1         # the newest add-on file format this version reads

# Sets REPLY to the current add-on's name: the one in $BYTEK_HOME/addon if it names an
# existing add-on, else the default. Only letters and "-" count as a name, so the file can't
# point outside addons/.
addon_current() {
  local name=""
  [ -f "$BYTEK_HOME/addon" ] && read -r name <"$BYTEK_HOME/addon"
  if [[ "$name" =~ ^[a-z-]+$ ]] && [ -f "$BYTEK_ROOT/addons/$name" ]; then
    REPLY=$name
  else
    REPLY=$ADDON_DEFAULT
  fi
}

# Reads add-on file $1 into ADDON_FRAMES ("a|b") and ADDON_MEANING. A file in a newer format
# than this Bytek reads (an optional "format: N", missing means 1) reads as empty, so it isn't
# misread (docs/adr/0008-versioned-file-formats.md). In the ascii charset, "frames_ascii" wins
# over "frames" (lib/charset.sh).
addon_read() {
  local line key val format=1
  ADDON_FRAMES="" ADDON_MEANING=""
  [ -f "$1" ] || return 0
  charset_start
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'*) continue ;; esac
    charset_key "${line%%:*}" || continue
    key=$REPLY
    val=${line#*:}
    val=${val# }
    case "$key" in
      format) format=$val ;;
      frames) ADDON_FRAMES=$val ;;
      meaning) ADDON_MEANING=$val ;;
    esac
  done <"$1"
  if ! [[ "$format" =~ ^[0-9]+$ ]] || [ "$format" -gt "$ADDON_FORMAT" ]; then
    ADDON_FRAMES="" ADDON_MEANING=""
  fi
}

# Sets ADDON_FRAMES to the current add-on's frames, or the fallback heart.
addon_load() {
  addon_current
  addon_read "$BYTEK_ROOT/addons/$REPLY"
  if [ -z "$ADDON_FRAMES" ]; then
    if [ "$CHARSET" = ascii ]; then ADDON_FRAMES=$ADDON_FALLBACK_ASCII; else ADDON_FRAMES=$ADDON_FALLBACK; fi
  fi
}

# bytek addon [name]: with a name, makes it the current add-on; without, lists them all.
addon_set() {
  local f name current dir="$BYTEK_HOME"
  if [ -z "$1" ]; then
    addon_current
    current=$REPLY
    for f in "$BYTEK_ROOT"/addons/*; do
      name=${f##*/}
      addon_read "$f"
      if [ "$name" = "$current" ]; then printf '* '; else printf '  '; fi
      # Only the ASCII name is padded: printf pads by bytes, and the symbols are several.
      printf '%-9s %s  %s\n' "$name" "${ADDON_FRAMES%%|*}" "$ADDON_MEANING"
    done
    return 0
  fi
  [[ "$1" =~ ^[a-z-]+$ ]] && [ -f "$BYTEK_ROOT/addons/$1" ] || die "unknown add-on: $1 (see: bytek addon)"
  if ! { mkdir -p "$dir" && printf '%s\n' "$1" >"$dir/addon.tmp" && mv "$dir/addon.tmp" "$dir/addon"; }; then
    die "cannot write $dir/addon"
  fi
}
