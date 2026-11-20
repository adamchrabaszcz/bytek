# shellcheck shell=bash
# companions: the names people give their companions (a dog called Rex), from
# $BYTEK_HOME/config/companions, one "companion = Name" per line (format in
# docs/architecture/data-files.md, example in examples/companions.example). The companions
# themselves, their art and texts, are data files in companions/. Plain file reads on the
# render path.
# Needs: nothing; from bin/bytek: BYTEK_ROOT, BYTEK_HOME, die (companions_set).

COMPANIONS_NAMES="$BYTEK_HOME/config/companions"
COMPANIONS_NAME_MAX=20 # characters: a name can't push the status row off the screen

# Sets REPLY to name $1 made safe: control characters removed, spaces at the ends trimmed, cut
# to COMPANIONS_NAME_MAX characters. The file can be edited by hand, so this runs on reading too.
companions_clean() {
  REPLY=${1//[[:cntrl:]]/}
  REPLY=${REPLY#"${REPLY%%[![:space:]]*}"}
  REPLY=${REPLY%"${REPLY##*[![:space:]]}"}
  REPLY=${REPLY:0:$COMPANIONS_NAME_MAX}
}

# Sets REPLY to the name given to companion $1 ("Rex"), empty when it has none.
companions_name() {
  local line key
  REPLY=""
  [ -f "$COMPANIONS_NAMES" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'*) continue ;; esac
    key=${line%%=*}
    key=${key//[[:space:]]/}
    if [ "$key" = "$1" ] && [[ "$line" == *=* ]]; then
      companions_clean "${line#*=}"
      return 0
    fi
  done <"$COMPANIONS_NAMES"
}

# bytek name [companion [Name]]: gives companion $1 the name $2 (the rest of the arguments), or
# takes its name away without one; with no arguments, lists the companions and their names.
companions_set() {
  local companion=$1 name f line tmp kept=""
  if [ -z "$companion" ]; then
    for f in "$BYTEK_ROOT"/companions/*; do
      companion=${f##*/}
      companions_name "$companion"
      printf '%-9s %s\n' "$companion" "${REPLY:-(no name)}"
    done
    return 0
  fi
  [[ "$companion" =~ ^[a-z][a-z-]*$ ]] && [ -f "$BYTEK_ROOT/companions/$companion" ] ||
    die "unknown companion: $companion (see: bytek name)"
  shift
  companions_clean "$*"
  name=$REPLY
  [[ "$name" != *=* ]] || die "a name can't contain ="
  # Every other line stays as it is; this companion's line is replaced (or dropped).
  if [ -f "$COMPANIONS_NAMES" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      f=${line%%=*}
      [ "${f//[[:space:]]/}" = "$companion" ] && [[ "$line" == *=* ]] && continue
      kept="$kept$line"$'\n'
    done <"$COMPANIONS_NAMES"
  fi
  [ -n "$name" ] && kept="$kept$companion = $name"$'\n'
  mkdir -p "${COMPANIONS_NAMES%/*}" || die "cannot create ${COMPANIONS_NAMES%/*}"
  tmp="$COMPANIONS_NAMES.tmp"
  if ! { printf '%s' "$kept" >"$tmp" && mv "$tmp" "$COMPANIONS_NAMES"; }; then
    die "cannot write $COMPANIONS_NAMES"
  fi
}
