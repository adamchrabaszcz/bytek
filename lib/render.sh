# shellcheck shell=bash
# shellcheck disable=SC2154 # S_<key> comes from lib/state.sh (state_load)
# render: draws the status line from a session's state and its face file. This is the render
# path: local files only, no jq, as few subprocesses as possible (50 ms budget).
# Needs: clock, state, addon, routines, companions; from bin/bytek: BYTEK_ROOT, BYTEK_HOME, BYTEK_UTF8.

RENDER_SPINNER="◜|◝|◞|◟"
RENDER_REMINDER_ICON="◷"                       # before a routine's reminder when no companion stands in for it (companions/)
RENDER_SLEEP_AFTER="${BYTEK_SLEEP_AFTER:-600}" # seconds of inactivity before Bytek falls asleep
RENDER_FACE_FORMAT=1                           # the newest face file format this version reads (docs/architecture/data-files.md)
RENDER_COMPANION_FORMAT=1                      # the newest companion file format this version reads

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

# Reads companion file $1 (companions/<name>, docs/architecture/data-files.md) into C_icon,
# C_due, C_due_text, C_due_face, C_due_thought, C_leash, C_overdue, C_overdue_text, and the
# variants used when the companion has a name: C_heads_up_named, C_due_named, C_overdue_named.
# Returns 1, with nothing set, when the file is missing or in a newer format than this Bytek reads.
render_companion() {
  local line key val format=1
  C_icon="" C_due="" C_due_text="" C_due_face="" C_due_thought="" C_leash="" C_overdue="" C_overdue_text=""
  C_heads_up_named="" C_due_named="" C_overdue_named=""
  [ -f "$1" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'*) continue ;; esac
    key=${line%%:*}
    val=${line#*:}
    val=${val# }
    case "$key" in
      format) format=$val ;;
      icon | due | due_text | due_face | due_thought | leash | overdue | overdue_text | heads_up_named | due_named | overdue_named)
        printf -v "C_$key" '%s' "$val"
        ;;
    esac
  done <"$1"
  if ! [[ "$format" =~ ^[0-9]+$ ]] || [ "$format" -gt "$RENDER_COMPANION_FORMAT" ]; then
    C_icon="" C_due="" C_due_text="" C_due_face="" C_due_thought="" C_leash="" C_overdue="" C_overdue_text=""
    C_heads_up_named="" C_due_named="" C_overdue_named=""
    return 1
  fi
}

# Sets REPLY to the frame of "a|b|c" $1 for tick $2, padded with spaces to its widest frame, so
# a companion whose frames differ in width (a wagging tail) doesn't shift what follows it.
render_pick_padded() {
  # Without a UTF-8 locale lengths are bytes, and padding would shift the frames: no padding.
  if [ "$BYTEK_UTF8" != 1 ]; then
    render_pick "$1" "$2"
    return
  fi
  local IFS='|' f width=0
  set -f
  # shellcheck disable=SC2206 # splitting on IFS='|' (globbing off) is the point; no mapfile in 3.2
  local frames=($1)
  set +f
  for f in "${frames[@]}"; do [ "${#f}" -gt "$width" ] && width=${#f}; done
  render_pick "$1" "$2"
  while [ "${#REPLY}" -lt "$width" ]; do REPLY="$REPLY "; done
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

  # With routines configured, the one date call also gives the date fields they need.
  if [ -f "$ROUTINES_FILE" ]; then
    clock_fields
    now=$CLOCK_EPOCH
  else
    clock_now
    now=$REPLY
  fi
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

  # A routine's reminder (lib/routines.sh) goes first in the status, what Claude does after it.
  # With a companion (companions/<icon>), the companion stands next to Bytek at the start of the
  # detail row, and while due it may bring its own text, face, thought and a leash to the box.
  local reminder="" text companion="" leash=""
  if [ -f "$ROUTINES_FILE" ]; then
    routines_load
    routines_reminder
    if [ -n "$ROUTINES_TEXT" ]; then
      text=$ROUTINES_TEXT
      if [ -n "$ROUTINES_SHOWN_ICON" ] && render_companion "$BYTEK_ROOT/companions/$ROUTINES_SHOWN_ICON"; then
        case "$ROUTINES_STAGE" in
          heads_up) companion=$C_icon ;;
          due)
            render_pick_padded "$C_due" "$tick"
            companion=$REPLY
            [ -n "$C_due_text" ] && text=$C_due_text
            if [ -n "$C_due_face" ]; then
              render_pick "$C_due_face" "$tick"
              frame=$REPLY
            fi
            [ -n "$C_due_thought" ] && thought=$C_due_thought
            [ "$C_leash" = yes ] && [ -n "$companion" ] && leash=1
            ;;
          overdue)
            render_pick_padded "$C_overdue" "$tick"
            companion=$REPLY
            [ -n "$C_overdue_text" ] && text=$C_overdue_text
            ;;
        esac
        # With a name for the companion (lib/companions.sh), its named text for the stage wins.
        companions_name "$ROUTINES_SHOWN_ICON"
        if [ -n "$REPLY" ]; then
          local named=""
          case "$ROUTINES_STAGE" in
            heads_up) named=$C_heads_up_named ;;
            due) named=$C_due_named ;;
            overdue) named=$C_overdue_named ;;
          esac
          [ -n "$named" ] && text=${named//\{name\}/$REPLY}
        fi
        text=${text//\{in\}/$ROUTINES_SHOWN_WHEN}
        text=${text//\{routine\}/${ROUTINES_SHOWN_NAME//_/ }}
        # A companion file may leave a stage out: then that stage keeps the ◷.
        if [ -n "$companion" ]; then reminder=$text; else reminder="$RENDER_REMINDER_ICON $text"; fi
      else
        reminder="$RENDER_REMINDER_ICON $text"
      fi
      [ "$ROUTINES_MORE" -gt 0 ] && reminder="$reminder +$ROUTINES_MORE"
      status="$reminder${status:+ · $status}"
    fi
  fi

  # The bot and its gaps take 10 columns; keep the text inside the terminal. Cutting from the
  # right shortens the work status first, so the reminder stays readable; the leash takes a
  # column from the status row, the companion its width from the detail row.
  if [ -n "$COLUMNS" ] && [ "$COLUMNS" -gt 12 ] 2>/dev/null; then max=$((COLUMNS - 12)); fi
  render_cut "$status" "${max:+$((max - ${leash:-0}))}"
  status=$REPLY
  # An overdue reminder in bold, added after cutting so the codes don't count as characters.
  if [ "$ROUTINES_STAGE" = overdue ] && [ -n "$reminder" ] && [[ "$status" == "$reminder"* ]]; then
    status=$'\033[1m'"$reminder"$'\033[22m'"${status#"$reminder"}"
  fi
  render_cut "$detail" "${max:+$((max - ${#companion}))}"
  detail=$REPLY

  # Claude Code trims the leading whitespace of each line, which would take the antenna's indent
  # and shift the lines against each other: an invisible colour reset first keeps every line as
  # it is, so the antenna stays above its stick.
  # The mood antenna (lib/addon.sh) sits on the stick, animated by the same tick.
  addon_load
  render_pick "$ADDON_FRAMES" "$tick"
  printf '\033[0m    %s%s\n' "$REPLY" "${thought:+ $thought}"
  printf '\033[0m ╭──┴──╮\n'
  if [ -n "$leash" ]; then
    # The companion on a leash: ╮ on the box's right edge, ╰ leading down to it.
    printf '\033[0m │ %s │╮  %s\n' "$frame" "$status"
    printf '\033[0m ╰─┬─┬─╯╰%s \033[2m%s\033[0m\n' "$companion" "$detail"
  elif [ -n "$companion" ]; then
    printf '\033[0m │ %s │  %s\n' "$frame" "$status"
    printf '\033[0m ╰─┬─┬─╯ %s \033[2m%s\033[0m\n' "$companion" "$detail"
  else
    printf '\033[0m │ %s │  %s\n' "$frame" "$status"
    printf '\033[0m ╰─┬─┬─╯  \033[2m%s\033[0m\n' "$detail"
  fi
}
