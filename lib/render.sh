# shellcheck shell=bash
# shellcheck disable=SC2154 # S_<key> comes from lib/state.sh (state_load)
# render: draws the status line from a session's state and its face file. This is the render
# path: local files only, no jq, as few subprocesses as possible (50 ms budget).
# Needs: clock, state; from bin/bytek: BYTEK_ROOT, BYTEK_HOME, BYTEK_UTF8.

RENDER_ANTENNA="♡"
RENDER_SPINNER="◜|◝|◞|◟"
RENDER_SLEEP_AFTER="${BYTEK_SLEEP_AFTER:-600}" # seconds of inactivity before Bytek falls asleep
RENDER_FACE_FORMAT=1                           # the newest face file format this version reads (docs/architecture/data-files.md)

# Splits a "a|b|c" frame list and sets REPLY to the element for tick $2.
# Leading spaces inside a frame are kept (used for bouncing marks).
render_pick() {
  local IFS='|' n
  set -f
  # shellcheck disable=SC2206 # splitting on IFS='|' (globbing off) is the point; no mapfile in 3.2
  local frames=($1)
  set +f
  n=${#frames[@]}
  if [ "$n" -eq 0 ]; then
    REPLY=""
    return
  fi
  REPLY=${frames[$(($2 % n))]}
}

# Reads "key: value" lines from face file $1 into F_frames, F_thought, F_status, F_detail and
# F_format (empty when the file declares none, which means format 1).
render_face() {
  F_frames="" F_thought="" F_status="" F_detail="" F_format=""
  local line key val
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'*) continue ;; esac
    key=${line%%:*}
    val=${line#*:}
    val=${val# }
    case "$key" in
      frames | thought | status | detail | format) printf -v "F_$key" '%s' "$val" ;;
    esac
  done <"$1"
}

# Sets REPLY to a 5-cell bar: "▰▰▰▱▱ 3/5" for N/M in $1, or a cell sweeping with tick $2
# when the progress is unknown.
render_bar() {
  local n=${1%/*} m=${1#*/} filled i bar=""
  if [[ "$1" =~ ^[0-9]+/[0-9]+$ ]] && [ "$m" -gt 0 ]; then
    filled=$((n * 5 / m))
    for i in 0 1 2 3 4; do
      if [ "$i" -lt "$filled" ]; then bar="${bar}▰"; else bar="${bar}▱"; fi
    done
    REPLY="$bar $n/$m"
  else
    for i in 0 1 2 3 4; do
      if [ "$i" -eq $(($2 % 5)) ]; then bar="${bar}▰"; else bar="${bar}▱"; fi
    done
    REPLY="$bar"
  fi
}

# Sets REPLY to $1 cut to $2 characters, ending in "…" when cut.
render_cut() {
  # Without a UTF-8 locale lengths are bytes: cutting could split a character, so don't.
  if [ -z "$2" ] || [ "$BYTEK_UTF8" != 1 ] || [ "${#1}" -le "$2" ]; then
    REPLY=$1
    return
  fi
  if [ "$2" -le 1 ]; then
    REPLY=""
    return
  fi
  REPLY="${1:0:$(($2 - 1))}…"
}

# Prints the four lines of the status line for the session named in status line JSON $1.
render_line() {
  local json=$1 session="default" now tick state_file face status detail thought max re
  re='"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_-]+)"'
  [[ "$json" =~ $re ]] && session=${BASH_REMATCH[1]}

  clock_now
  now=$REPLY
  tick=$now

  state_file="$BYTEK_HOME/state/$session"
  [ -f "$state_file" ] || state_file="$BYTEK_HOME/state/default"
  state_load "$state_file"

  # Idle or finished for long enough: Bytek falls asleep.
  if [ -n "$S_since" ] && { [ "$S_state" = idle ] || [ "$S_state" = "done" ]; } &&
    [ $((now - S_since)) -ge "$RENDER_SLEEP_AFTER" ]; then
    S_state=sleeping S_status="" S_arg="idle for $(((now - S_since) / 60))m"
  fi

  face="$BYTEK_ROOT/faces/$S_state"
  [ -f "$face" ] || face="$BYTEK_ROOT/faces/idle"
  render_face "$face"
  # A face file in a newer format than this Bytek knows isn't misread: show idle instead.
  if ! [[ "${F_format:-1}" =~ ^[0-9]+$ ]] || [ "${F_format:-1}" -gt "$RENDER_FACE_FORMAT" ]; then
    render_face "$BYTEK_ROOT/faces/idle"
  fi

  render_pick "$F_frames" "$tick"
  local frame=$REPLY
  render_pick "$F_thought" "$tick"
  thought=$REPLY
  status=${S_status:-$F_status}

  detail=${S_detail:-$F_detail}
  case "$detail" in *'{spin}'*)
    render_pick "$RENDER_SPINNER" "$tick"
    detail=${detail//\{spin\}/$REPLY}
    ;;
  esac
  case "$detail" in *'{progress}'*)
    render_bar "$S_progress" "$tick"
    detail=${detail//\{progress\}/$REPLY}
    ;;
  esac
  detail=${detail//\{arg\}/$S_arg}

  # The bot and its gaps take 10 columns; keep the text inside the terminal.
  if [ -n "$COLUMNS" ] && [ "$COLUMNS" -gt 12 ] 2>/dev/null; then max=$((COLUMNS - 12)); fi
  render_cut "$status" "$max"
  status=$REPLY
  render_cut "$detail" "$max"
  detail=$REPLY

  printf '    %s%s\n' "$RENDER_ANTENNA" "${thought:+ $thought}"
  printf ' ╭──┴──╮\n'
  printf ' │ %s │  %s\n' "$frame" "$status"
  printf ' ╰─┬─┬─╯  \033[2m%s\033[0m\n' "$detail"
}
