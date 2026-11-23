# shellcheck shell=bash
# shellcheck disable=SC2154 # S_<key> comes from lib/state.sh (state_load)
# render: draws the status line from a session's state and its face file. This is the render
# path: local files only, no jq, as few subprocesses as possible (50 ms budget).
# Needs: clock, state, config, charset, addon, routines, companions, away; from bin/bytek: BYTEK_ROOT, BYTEK_HOME, BYTEK_UTF8.

# The render's own glyphs, in the unicode charset; render_ascii swaps in the ascii ones.
RENDER_SPINNER="◜|◝|◞|◟"
RENDER_REMINDER_ICON="◷" # before a routine's reminder when no companion stands in for it (companions/)
RENDER_BAR_ON="▰"
RENDER_BAR_OFF="▱"
RENDER_CUT="…"   # ends text cut to the terminal's width
RENDER_SEP=" · " # between a routine's reminder and the work status
RENDER_TOP=" ╭──┴──╮"
RENDER_SIDE="│"
RENDER_BOTTOM=" ╰─┬─┬─╯"
RENDER_LEASH_TOP="╮" # the leash, from the box's right edge down to the companion
RENDER_LEASH_BOTTOM="╰"

RENDER_SLEEP_AFTER="${BYTEK_SLEEP_AFTER:-600}" # seconds of inactivity before Bytek falls asleep
RENDER_FACE_FORMAT=1                           # the newest face file format this version reads (docs/architecture/data-files.md)
RENDER_COMPANION_FORMAT=1                      # the newest companion file format this version reads

# Swaps the render's glyphs for plain ASCII ones (the ascii charset, lib/charset.sh). The
# spinner has no "|": that separates frames.
render_ascii() {
  RENDER_SPINNER="/|-|\\" RENDER_REMINDER_ICON="(!)" RENDER_BAR_ON="#" RENDER_BAR_OFF="-"
  RENDER_CUT="..." RENDER_SEP=" - "
  RENDER_TOP=" .--+--." RENDER_SIDE="|" RENDER_BOTTOM=" '-+-+-'"
  RENDER_LEASH_TOP="\\" RENDER_LEASH_BOTTOM="\\"
}

# Sets REPLY to text $1 with the non-ASCII marks Bytek itself writes (hooks: "3 changes ·
# lib/x.sh", "✓ tests passed") in ASCII. Text from elsewhere, like file names, stays as it is.
render_ascii_text() {
  REPLY=${1//·/-}
  REPLY=${REPLY//✓/+}
}

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
# F_format (empty when the file declares none, which means format 1); in the ascii charset,
# a "<key>_ascii" line wins over its plain one (lib/charset.sh).
render_face() {
  F_frames="" F_thought="" F_status="" F_detail="" F_format=""
  local line key val
  charset_start
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'*) continue ;; esac
    charset_key "${line%%:*}" || continue
    key=$REPLY
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
# In the ascii charset, a "<key>_ascii" line wins over its plain one. Returns 1, with nothing
# set, when the file is missing or in a newer format than this Bytek reads.
render_companion() {
  local line key val format=1
  C_icon="" C_due="" C_due_text="" C_due_face="" C_due_thought="" C_leash="" C_overdue="" C_overdue_text=""
  C_heads_up_named="" C_due_named="" C_overdue_named=""
  [ -f "$1" ] || return 1
  charset_start
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'*) continue ;; esac
    charset_key "${line%%:*}" || continue
    key=$REPLY
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
      if [ "$i" -lt "$filled" ]; then bar="${bar}${RENDER_BAR_ON}"; else bar="${bar}${RENDER_BAR_OFF}"; fi
    done
    REPLY="$bar $n/$m"
  else
    for i in 0 1 2 3 4; do
      if [ "$i" -eq $(($2 % 5)) ]; then bar="${bar}${RENDER_BAR_ON}"; else bar="${bar}${RENDER_BAR_OFF}"; fi
    done
    REPLY="$bar"
  fi
}

# Sets REPLY to $1 cut to $2 characters, ending in RENDER_CUT ("…") when cut.
render_cut() {
  # Without a UTF-8 locale lengths are bytes: cutting could split a character, so don't.
  if [ -z "$2" ] || [ "$BYTEK_UTF8" != 1 ] || [ "${#1}" -le "$2" ]; then
    REPLY=$1
    return
  fi
  if [ "$2" -le "${#RENDER_CUT}" ]; then
    REPLY=""
    return
  fi
  REPLY="${1:0:$(($2 - ${#RENDER_CUT}))}$RENDER_CUT"
}

# While a routine clears on idle (lib/away.sh), starts `bytek away` in the background when a
# check is due: at most every AWAY_EVERY seconds, only where ioreg exists. The stamp goes first,
# so the next renders don't start one too. Reads the routines and CLOCK_EPOCH; `command -v` and
# the file read are builtins, so a render without a due check starts no program.
render_away_check() {
  local i
  for ((i = 0; i < ROUTINES_COUNT; i++)); do
    [ "${ROUTINES_AWAY[i]}" -gt 0 ] && break
  done
  [ "$i" -lt "$ROUTINES_COUNT" ] && command -v ioreg >/dev/null 2>&1 && away_due "$CLOCK_EPOCH" || return 0
  away_write "$CLOCK_EPOCH" "$AWAY_IDLE" || return 0
  "$BYTEK_ROOT/bin/bytek" away </dev/null >/dev/null 2>&1 &
}

# Works out what Bytek shows for the session named in status line JSON $1, for every layout:
# R_tick, R_frame, R_thought, R_status, R_detail, R_reminder (the routine's part at the start of
# R_status), R_overdue (1 when that reminder is overdue), R_companion and R_leash (1 when the
# companion is on a leash). The texts are whole: each layout cuts them to its own width.
render_state() {
  local json=$1 session="default" now state_file face re
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
  R_tick=$now

  charset_load
  [ "$CHARSET" = ascii ] && render_ascii

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

  render_pick "$F_frames" "$R_tick"
  R_frame=$REPLY
  render_pick "$F_thought" "$R_tick"
  R_thought=$REPLY
  R_status=${S_status:-$F_status}

  R_detail=${S_detail:-$F_detail}
  case "$R_detail" in *'{spin}'*)
    render_pick "$RENDER_SPINNER" "$R_tick"
    R_detail=${R_detail//\{spin\}/"$REPLY"} # quoted: the ascii spinner has a "\"
    ;;
  esac
  case "$R_detail" in *'{progress}'*)
    render_bar "$S_progress" "$R_tick"
    R_detail=${R_detail//\{progress\}/$REPLY}
    ;;
  esac
  R_detail=${R_detail//\{arg\}/$S_arg}

  # A routine's reminder (lib/routines.sh) goes first in the status, what Claude does after it.
  # With a companion (companions/<icon>), the companion stands next to Bytek, and while due it
  # may bring its own text, face, thought and a leash. The reminders and companions switches
  # (lib/config.sh) turn either off.
  local text
  R_reminder="" R_overdue="" R_companion="" R_leash=""
  if [ "$CONFIG_reminders" != off ] && [ -f "$ROUTINES_FILE" ]; then
    routines_load
    render_away_check
    routines_reminder
    if [ -n "$ROUTINES_TEXT" ]; then
      text=$ROUTINES_TEXT
      if [ "$CONFIG_companions" != off ] && [ -n "$ROUTINES_SHOWN_ICON" ] && render_companion "$BYTEK_ROOT/companions/$ROUTINES_SHOWN_ICON"; then
        case "$ROUTINES_STAGE" in
          heads_up) R_companion=$C_icon ;;
          due)
            render_pick_padded "$C_due" "$R_tick"
            R_companion=$REPLY
            [ -n "$C_due_text" ] && text=$C_due_text
            if [ -n "$C_due_face" ]; then
              render_pick "$C_due_face" "$R_tick"
              R_frame=$REPLY
            fi
            [ -n "$C_due_thought" ] && R_thought=$C_due_thought
            [ "$C_leash" = yes ] && [ -n "$R_companion" ] && R_leash=1
            ;;
          overdue)
            render_pick_padded "$C_overdue" "$R_tick"
            R_companion=$REPLY
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
          # Quoted: from bash 5.2 an & in the replacement would stand for the matched text.
          [ -n "$named" ] && text=${named//\{name\}/"$REPLY"}
        fi
        text=${text//\{in\}/$ROUTINES_SHOWN_WHEN}
        text=${text//\{routine\}/${ROUTINES_SHOWN_NAME//_/ }}
        # A companion file may leave a stage out: then that stage keeps the ◷.
        if [ -n "$R_companion" ]; then R_reminder=$text; else R_reminder="$RENDER_REMINDER_ICON $text"; fi
      else
        R_reminder="$RENDER_REMINDER_ICON $text"
      fi
      [ "$ROUTINES_MORE" -gt 0 ] && R_reminder="$R_reminder +$ROUTINES_MORE"
      [ "$ROUTINES_STAGE" = overdue ] && R_overdue=1
      R_status="$R_reminder${R_status:+$RENDER_SEP$R_status}"
    fi
  fi
  [ "$CONFIG_thought" = off ] && R_thought=""

  if [ "$CHARSET" = ascii ]; then
    render_ascii_text "$R_status"
    R_status=$REPLY
    render_ascii_text "$R_detail"
    R_detail=$REPLY
    render_ascii_text "$R_reminder"
    R_reminder=$REPLY
  fi
}

# Sets REPLY to status $1, cut already, with an overdue reminder (render_state) in bold: the
# codes go in after cutting, so they don't count as characters.
render_bold_overdue() {
  REPLY=$1
  if [ -n "$R_overdue" ] && [ -n "$R_reminder" ] && [[ "$1" == "$R_reminder"* ]]; then
    REPLY=$'\033[1m'"$R_reminder"$'\033[22m'"${1#"$R_reminder"}"
  fi
}

# Prints the four lines of the status line for the session named in status line JSON $1, or
# the one line (render_oneline_draw, cut to COLUMNS) with the box switch off (lib/config.sh).
render_line() {
  local status detail max
  render_state "$1"
  if [ "$CONFIG_box" = off ]; then
    render_oneline_draw "$COLUMNS"
    return
  fi

  # The bot and its gaps take 10 columns; keep the text inside the terminal. Cutting from the
  # right shortens the work status first, so the reminder stays readable; the leash takes a
  # column from the status row, the companion its width from the detail row.
  if [ -n "$COLUMNS" ] && [ "$COLUMNS" -gt 12 ] 2>/dev/null; then max=$((COLUMNS - 12)); fi
  render_cut "$R_status" "${max:+$((max - ${R_leash:-0}))}"
  render_bold_overdue "$REPLY"
  status=$REPLY
  render_cut "$R_detail" "${max:+$((max - ${#R_companion}))}"
  detail=$REPLY

  # Claude Code trims the leading whitespace of each line, which would take the antenna's indent
  # and shift the lines against each other: an invisible colour reset first keeps every line as
  # it is, so the antenna stays above its stick.
  # The mood antenna (lib/addon.sh) sits on the stick, animated by the same tick.
  addon_load
  render_pick "$ADDON_FRAMES" "$R_tick"
  printf '\033[0m    %s%s\n' "$REPLY" "${R_thought:+ $R_thought}"
  printf '\033[0m%s\n' "$RENDER_TOP"
  if [ -n "$R_leash" ]; then
    # The companion on a leash: ╮ on the box's right edge, ╰ leading down to it.
    printf '\033[0m %s %s %s%s  %s\n' "$RENDER_SIDE" "$R_frame" "$RENDER_SIDE" "$RENDER_LEASH_TOP" "$status"
    printf '\033[0m%s%s%s \033[2m%s\033[0m\n' "$RENDER_BOTTOM" "$RENDER_LEASH_BOTTOM" "$R_companion" "$detail"
  elif [ -n "$R_companion" ]; then
    printf '\033[0m %s %s %s  %s\n' "$RENDER_SIDE" "$R_frame" "$RENDER_SIDE" "$status"
    printf '\033[0m%s %s \033[2m%s\033[0m\n' "$RENDER_BOTTOM" "$R_companion" "$detail"
  else
    printf '\033[0m %s %s %s  %s\n' "$RENDER_SIDE" "$R_frame" "$RENDER_SIDE" "$status"
    printf '\033[0m%s  \033[2m%s\033[0m\n' "$RENDER_BOTTOM" "$detail"
  fi
}

# Prints Bytek on one line for the session named in status line JSON $1: the face, the
# companion when one is out, the status and, after RENDER_SEP, the detail; no box, antenna or
# thought. Cut to $2 characters when given, the detail first. With $3 "plain", without the dim
# and bold codes, for apps that show the text as it is (a Touch Bar app).
render_oneline() {
  render_state "$1"
  render_oneline_draw "$2" "$3"
}

# Prints the one line from what render_state worked out; $1 and $2 as render_oneline's $2 and $3.
render_oneline_draw() {
  local head text status rest dim="" off=""
  head="($R_frame)"
  if [ -n "$R_companion" ]; then
    text=$R_companion
    while [[ "$text" == *" " ]]; do text=${text% }; done # the padding to its widest frame
    head="$head $text"
  fi
  text="$R_status${R_detail:+$RENDER_SEP$R_detail}"
  while [[ "$text" == *" " ]]; do text=${text% }; done # a spinner without its {arg}
  render_cut "$text" "${1:+$(($1 - ${#head} - 1))}"
  # The status is the first part of the cut text, the separator and detail the rest.
  status=${REPLY:0:${#R_status}} rest=${REPLY:${#R_status}}
  if [ "$2" != plain ]; then
    render_bold_overdue "$status"
    status=$REPLY dim=$'\033[2m' off=$'\033[0m'
  fi
  printf '%s%s%s\n' "$head" "${status:+ $status}" "${rest:+$dim$rest$off}"
}
