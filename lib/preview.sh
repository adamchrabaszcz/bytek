# shellcheck shell=bash
# shellcheck disable=SC2034 # S_<key> are read by state_write (lib/state.sh)
# preview: `bytek preview`, every look Bytek has without waiting for real events. With no
# flags, a gallery: each state, each add-on and each companion's routine stages; with --state,
# --addon or --routine, that one combination. It renders into a temp BYTEK_HOME of its own
# (bin/bytek makes it), so the real state, add-on, routines and names are never read or changed.
# Needs: clock, state, addon, routines, companions, render; from bin/bytek: BYTEK_ROOT, BYTEK_HOME, die.

PREVIEW_STAGES="heads_up due overdue"
PREVIEW_LEAD=5 # minutes between the preview's time and a routine's, for heads_up and overdue

# Sets REPLY to an example {arg} for state $1, so the gallery looks like real work.
preview_arg() {
  case "$1" in
    reading) REPLY="README.md" ;;
    searching) REPLY="render_line" ;;
    editing) REPLY="lib/render.sh" ;;
    waiting) REPLY="Bash: tools/lint.sh" ;;
    done) REPLY="3 files changed" ;;
    error) REPLY="exit 1: tests/run.sh" ;;
    sleeping) REPLY="idle for 12m" ;;
    *) REPLY="" ;;
  esac
}

# Sets REPLY to an example routine name for companion $1 ("walk" for the dog).
preview_routine_name() {
  case "$1" in
    dog) REPLY="walk" ;;
    meal) REPLY="lunch" ;;
    *) REPLY=$1 ;;
  esac
}

# Writes the temp home for one render: state $1 with {arg} $2, add-on $3, and, when $4 is
# "companion:stage", one routine at the moment that puts it in that stage at BYTEK_NOW.
# Returns 1 with the reason in REPLY when the stage can't be reached before or after midnight.
preview_setup() {
  local companion=${4%%:*} stage=${4#*:} minute at
  state_load /dev/null
  S_state=$1 S_arg=$2 S_since=$BYTEK_NOW
  [ "$1" = testing ] && S_progress="3/5"
  state_write "$BYTEK_HOME/state/default" || die "cannot write $BYTEK_HOME/state"
  printf '%s\n' "$3" >"$BYTEK_HOME/addon"
  rm -f "$ROUTINES_FILE"
  [ -n "$4" ] || return 0
  clock_fields "$BYTEK_NOW"
  minute=$(((BYTEK_NOW - CLOCK_MIDNIGHT) / 60))
  case "$stage" in
    heads_up) at=$((minute + PREVIEW_LEAD)) ;;
    due) at=$minute ;;
    overdue) at=$((minute - PREVIEW_LEAD)) ;;
  esac
  if [ "$at" -lt 0 ] || [ "$at" -ge 1440 ]; then
    REPLY="$companion $stage needs a time at least $PREVIEW_LEAD minutes from midnight (try --time 12:00)"
    return 1
  fi
  preview_routine_name "$companion"
  mkdir -p "${ROUTINES_FILE%/*}" || die "cannot write ${ROUTINES_FILE%/*}"
  printf '%s = daily %02d:%02d | icon %s | heads_up 10m\n' "$REPLY" $((at / 60)) $((at % 60)) "$companion" >"$ROUTINES_FILE"
}

# Prints the status line for the temp home. The render runs in a subshell, since it sets
# globals the next one must not see. When stdout isn't a terminal (/bytek preview runs through
# Claude), the render's colour and bold codes are left out, so they don't show as junk.
preview_print() {
  local out code
  out=$(render_line '{}')
  if [ ! -t 1 ]; then
    for code in 0m 1m 2m 22m; do out=${out//$'\033['$code/}; done
  fi
  printf '%s\n' "$out"
}

# Prints label $5 and the status line for preview_setup's arguments $1-$4, then a blank line.
preview_show() {
  printf '%s\n' "$5"
  if preview_setup "$1" "$2" "$3" "$4"; then
    preview_print
  else
    printf '  (%s)\n' "$REPLY"
  fi
  printf '\n'
}

# Sets BYTEK_NOW to date $1 ("12-06" or "2026-12-06", default today) at time $2 ("23:00",
# default now). Without either, BYTEK_NOW is the current time (or the one already set).
preview_time() {
  local date=$1 time=$2 year month day
  clock_now
  BYTEK_NOW=$REPLY
  [ -n "$date$time" ] || return 0
  clock_fields "$BYTEK_NOW"
  [[ "$date" =~ ^[0-9]{4}- ]] || date="$CLOCK_YEAR-${date:-$CLOCK_MONTH-$CLOCK_DAY}"
  [[ "$date" =~ ^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})$ ]] || die "not a date: $1 (MM-DD or YYYY-MM-DD)"
  year=$((10#${BASH_REMATCH[1]})) month=$((10#${BASH_REMATCH[2]})) day=$((10#${BASH_REMATCH[3]}))
  [ "$month" -ge 1 ] && [ "$month" -le 12 ] || die "not a date: $1 (MM-DD or YYYY-MM-DD)"
  clock_days_in_month "$year" "$month"
  [ "$day" -ge 1 ] && [ "$day" -le "$REPLY" ] || die "not a date: $1 (MM-DD or YYYY-MM-DD)"
  if [ -n "$time" ]; then
    routines_minutes "$time" || die "not a time: $time (HH:MM)"
  else
    REPLY=$(((BYTEK_NOW - CLOCK_MIDNIGHT) / 60))
  fi
  printf -v time '%02d:%02d' $((REPLY / 60)) $((REPLY % 60))
  printf -v date '%04d-%02d-%02d' "$year" "$month" "$day"
  clock_moment "$date" "$time" || die "cannot work out $date $time"
  BYTEK_NOW=$REPLY
}

# bytek preview [--state S] [--arg TEXT] [--addon A] [--routine COMPANION:STAGE] [--name NAME]
#               [--time HH:MM] [--date MM-DD] [--width N]
preview_run() {
  local state="" arg="" addon="" routine="" name="" time="" date="" width="" f s companion one=""
  while [ $# -gt 0 ]; do
    [ $# -ge 2 ] || die "$1 needs a value (see: bytek help)"
    case "$1" in
      --state) state=$2 one=1 ;;
      --arg) arg=$2 ;;
      --addon) addon=$2 one=1 ;;
      --routine) routine=$2 one=1 ;;
      --name) name=$2 ;;
      --time) time=$2 ;;
      --date) date=$2 ;;
      --width) width=$2 ;;
      *) die "unknown option: $1 (see: bytek help)" ;;
    esac
    shift 2
  done
  [ -z "$arg" ] || [ -n "$state" ] || die "--arg goes with --state (bytek preview --state reading --arg notes.txt)"
  [ -z "$state" ] || { [[ "$state" =~ ^[a-z-]+$ ]] && [ -f "$BYTEK_ROOT/faces/$state" ]; } ||
    die "unknown state: $state (see: bytek states)"
  [ -z "$addon" ] || { [[ "$addon" =~ ^[a-z-]+$ ]] && [ -f "$BYTEK_ROOT/addons/$addon" ]; } ||
    die "unknown add-on: $addon (see: bytek addon)"
  if [ -n "$routine" ]; then
    companion=${routine%%:*}
    [[ "$routine" =~ ^[a-z-]+:(heads_up|due|overdue)$ ]] && [ -f "$BYTEK_ROOT/companions/$companion" ] ||
      die "unknown routine stage: $routine (a companion and heads_up, due or overdue: dog:due)"
  fi
  if [ -n "$width" ]; then
    [[ "$width" =~ ^[0-9]+$ ]] && [ "$width" -ge 20 ] || die "not a width: $width (20 or more columns)"
    COLUMNS=$width
  else
    unset COLUMNS # the render cuts to COLUMNS; a preview shows everything unless asked
  fi
  preview_time "$date" "$time"
  # A name goes to every companion: the preview shows the named texts wherever there are some.
  if [ -n "$name" ]; then
    for f in "$BYTEK_ROOT"/companions/*; do companions_set "${f##*/}" "$name"; done
  fi

  if [ -n "$one" ]; then
    [ -n "$state" ] || state=idle
    [ -n "$arg" ] || { preview_arg "$state" && arg=$REPLY; }
    preview_setup "$state" "$arg" "${addon:-$ADDON_DEFAULT}" "$routine" || die "$REPLY"
    preview_print
    return 0
  fi
  for f in "$BYTEK_ROOT"/faces/*; do
    s=${f##*/}
    preview_arg "$s"
    preview_show "$s" "$REPLY" "$ADDON_DEFAULT" "" "state: $s"
  done
  for f in "$BYTEK_ROOT"/addons/*; do
    preview_show idle "" "${f##*/}" "" "add-on: ${f##*/}"
  done
  for f in "$BYTEK_ROOT"/companions/*; do
    for s in $PREVIEW_STAGES; do
      preview_show idle "" "$ADDON_DEFAULT" "${f##*/}:$s" "routine: ${f##*/} $s"
    done
  done
}
