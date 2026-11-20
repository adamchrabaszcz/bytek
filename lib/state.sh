# shellcheck shell=bash
# shellcheck disable=SC2034 # S_<key> is this module's output, read by render, hooks and bin/bytek
# state: what Bytek is doing, one file per session in $BYTEK_HOME/state/. Hooks write it,
# the status line reads it.
# Needs: clock (for lock stamps).
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

# Hooks can run at the same moment (parallel tools, subagents), and each one reads, changes
# and writes the state file: without a lock, one write overwrites another's update.
STATE_LOCK_WAIT=${BYTEK_LOCK_WAIT:-2}    # seconds to wait for the lock before going ahead without it
STATE_LOCK_STALE=${BYTEK_LOCK_STALE:-10} # seconds after which a lock counts as left behind by a crash

# Locks state file $1 for a read-change-write: a "$1.lock" directory, since mkdir is atomic on
# macOS and Linux (flock isn't on macOS). A lock older than STATE_LOCK_STALE is removed. After
# STATE_LOCK_WAIT seconds it returns 1 and the caller goes ahead unlocked: a hook must never hang.
state_lock() {
  local lock="$1.lock" tries=$((STATE_LOCK_WAIT * 20)) since
  mkdir -p "${1%/*}" 2>/dev/null
  while ! mkdir "$lock" 2>/dev/null; do
    clock_now
    since=""
    if [ -f "$lock/since" ]; then
      # Only a stamp that was really read counts: the owner may release the lock (and the next
      # owner take it) between the test and the read, and an empty stamp isn't an old one.
      read -r since <"$lock/since" 2>/dev/null
      [[ "$since" =~ ^[0-9]+$ ]] && [ $((REPLY - since)) -ge "$STATE_LOCK_STALE" ] && rm -rf "$lock"
    else
      # Its owner hasn't stamped it yet, or crashed before it could: stamp it, so it can age.
      echo "$REPLY" >"$lock/since" 2>/dev/null
    fi
    tries=$((tries - 1))
    [ "$tries" -gt 0 ] || return 1
    sleep 0.05
  done
  clock_now
  echo "$REPLY" >"$lock/since"
}

# Releases the lock on state file $1.
state_unlock() {
  rm -rf "$1.lock"
}

# Switches to a new state and clears the previous state's text.
# Usage: state_to <state> [arg] [status] [detail]
state_to() { S_state=$1 S_arg=$2 S_status=$3 S_detail=$4 S_progress=""; }
