# shellcheck shell=bash
# shellcheck disable=SC2034 # S_<key> is this module's output, read by render, hooks and bin/bytek
# state: what Bytek is doing, one file per session in $BYTEK_HOME/state/. Hooks write it,
# the status line reads it.
# Needs: nothing.
#
# State file fields (one "key=value" per line), loaded into S_<key>:
#   state, arg (fills {arg}), status / detail (override the face's text),
#   progress (N/M), since (last event), turn_start, edits, files ("|a|b|").
STATE_KEYS="state arg status detail progress since turn_start edits files"

# Loads state file $1 into S_<key>; a missing file gives an idle state.
state_load() {
  S_state="idle" S_arg="" S_status="" S_detail="" S_progress="" S_since=""
  S_turn_start="" S_edits="" S_files=""
  [ -f "$1" ] || return 0
  local line key val
  while IFS= read -r line || [ -n "$line" ]; do
    key=${line%%=*}
    val=${line#*=}
    case " $STATE_KEYS " in
      *" $key "*) printf -v "S_$key" '%s' "$val" ;;
    esac
  done <"$1"
}

# Writes all S_<key> fields to $1 atomically (temp file + rename). Control characters are
# removed here too (bytek set takes text from the command line), so no value can carry
# terminal escape sequences into the status line.
state_write() {
  local dir=${1%/*} tmp key val
  mkdir -p "$dir" || return 1
  tmp=$(mktemp "$dir/.tmp.XXXXXX") || return 1
  for key in $STATE_KEYS; do
    eval "val=\$S_$key"
    val=${val//[$'\n\t']/ }
    printf '%s=%s\n' "$key" "${val//[[:cntrl:]]/}"
  done >"$tmp" && mv "$tmp" "$1"
}

# Switches to a new state and clears the previous state's text.
# Usage: state_to <state> [arg] [status] [detail]
state_to() { S_state=$1 S_arg=$2 S_status=$3 S_detail=$4 S_progress=""; }
