# shellcheck shell=bash
# shellcheck disable=SC2034 # AWAY_* are this module's output, read by render and doctor
# away: how long the Mac has had no keyboard or mouse input, for routines with "clear idle". The
# status line starts `bytek away` in the background at most every AWAY_EVERY seconds; that reads
# the idle time from macOS's ioreg (HIDIdleTime, which keeps counting while the screen is locked,
# and which prompts sent from another device don't reset) and notes it in AWAY_FILE. Without
# ioreg (Linux) nothing is checked.
# Needs: nothing; from bin/bytek: BYTEK_HOME.

AWAY_FILE="$BYTEK_HOME/away"
AWAY_FORMAT=1 # the newest away file format this version reads
AWAY_EVERY=10 # seconds between checks

# Sets AWAY_SAMPLED (when the last check started, seconds since 1970) and AWAY_IDLE (the idle
# seconds it found) from AWAY_FILE: both 0 when it's missing or in a format this Bytek doesn't read.
away_load() {
  local line format=""
  AWAY_SAMPLED=0 AWAY_IDLE=0
  [ -f "$AWAY_FILE" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      format=*) format=${line#format=} ;;
      sampled=*) [[ "${line#sampled=}" =~ ^[0-9]+$ ]] && AWAY_SAMPLED=${line#sampled=} ;;
      idle=*) [[ "${line#idle=}" =~ ^[0-9]+$ ]] && AWAY_IDLE=${line#idle=} ;;
    esac
  done <"$AWAY_FILE"
  if ! [[ "$format" =~ ^[0-9]+$ ]] || [ "$format" -gt "$AWAY_FORMAT" ]; then
    AWAY_SAMPLED=0 AWAY_IDLE=0
  fi
}

# Returns 0 when a check is due at moment $1: none started within AWAY_EVERY seconds (or one
# that seems to come from the future, after the clock was set back).
away_due() {
  away_load
  [ $(($1 - AWAY_SAMPLED)) -ge "$AWAY_EVERY" ] || [ "$AWAY_SAMPLED" -gt "$1" ]
}

# Writes AWAY_FILE: a check at moment $1 that found $2 idle seconds. Plain printf, no temp file
# and rename: the render path stamps it too, and starts no programs. A reader that catches it
# half-written sees no check and at most starts one more.
away_write() {
  [ -d "${AWAY_FILE%/*}" ] || mkdir -p "${AWAY_FILE%/*}" || return 1
  printf 'format=%s\nsampled=%s\nidle=%s\n' "$AWAY_FORMAT" "$1" "$2" >"$AWAY_FILE"
}

# Sets REPLY to the seconds since the Mac's last keyboard or mouse input; returns 1 without ioreg.
away_idle() {
  local out re='"HIDIdleTime" = ([0-9]+)'
  command -v ioreg >/dev/null 2>&1 || return 1
  out=$(ioreg -c IOHIDSystem -d 4 -r -k HIDIdleTime 2>/dev/null) || return 1
  [[ "$out" =~ $re ]] || return 1
  REPLY=$((BASH_REMATCH[1] / 1000000000)) # nanoseconds
}
