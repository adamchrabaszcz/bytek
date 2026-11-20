# shellcheck shell=bash
# shellcheck disable=SC2034 # S_<key> and STATE_EDITS/STATE_FILES are this module's output, read by render, hooks and bin/bytek
# state: what Bytek is doing, one file per session in $BYTEK_HOME/state/. Hooks write it,
# the status line reads it.
# Needs: nothing.
#
# Hooks can run at the same moment (parallel tools, subagents). There is no lock (no portable,
# reliable one in bash: docs/adr/0007-no-lock-append-edits.md): the state file holds only what
# Bytek is doing now, written whole, so the last hook wins; the turn's edits, which must add
# up, are appended as lines to a list next to it (<session>.edits).
#
# State file fields (one "key=value" per line), loaded into S_<key>:
#   state, arg (fills {arg}), status / detail (override the face's text),
#   progress (N/M), since (last event), turn_start.
STATE_KEYS="state arg status detail progress since turn_start"

# Loads state file $1 into S_<key>; a missing file gives an idle state. Keys it doesn't know
# (such as edits and files, which older versions kept here) are ignored.
state_load() {
  S_state="idle" S_arg="" S_status="" S_detail="" S_progress="" S_since="" S_turn_start=""
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

# Appends file $2 to the edit list of state file $1, one line per edit. A short append is
# atomic, so edits from hooks running at the same moment all count.
state_add_edit() {
  local file=${2//[[:cntrl:]]/}
  mkdir -p "${1%/*}" && printf '%s\n' "$file" >>"$1.edits"
}

# Sets STATE_EDITS to the number of edits in the list of state file $1, and STATE_FILES to the
# number of different files among them.
state_count_edits() {
  local line seen="|"
  STATE_EDITS=0 STATE_FILES=0
  [ -f "$1.edits" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    STATE_EDITS=$((STATE_EDITS + 1))
    case "$seen" in
      *"|$line|"*) ;;
      *)
        seen="$seen$line|"
        STATE_FILES=$((STATE_FILES + 1))
        ;;
    esac
  done <"$1.edits"
}

# Empties the edit list of state file $1 (a new turn starts, or the session ends).
state_clear_edits() {
  rm -f "$1.edits"
}

# Switches to a new state and clears the previous state's text.
# Usage: state_to <state> [arg] [status] [detail]
state_to() { S_state=$1 S_arg=$2 S_status=$3 S_detail=$4 S_progress=""; }
