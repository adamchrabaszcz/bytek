# shellcheck shell=bash
# shellcheck disable=SC2034 # ROUTINES_* are this module's output, read by doctor (and the stages, #97)
# routines: the user's reminders, from $BYTEK_HOME/config/routines (format and example in
# docs/architecture/data-files.md and examples/routines.example): when each one happens next.
# Plain bash on the render path: one `date` call for the clock fields, then arithmetic, walking
# forward day by day. Occurrences after a daylight saving change are off by the change until
# that day comes; each run counts from that day's own midnight.
# Needs: clock.

ROUTINES_FILE="${BYTEK_ROUTINES:-$BYTEK_HOME/config/routines}"
ROUTINES_HORIZON=366 # days to look ahead for the next occurrence (a season can be months away)

# Sets REPLY to the minutes after midnight of "HH:MM" $1; returns 1 if it isn't a time.
routines_minutes() {
  [[ "$1" =~ ^([01][0-9]|2[0-3]):([0-5][0-9])$ ]] || return 1
  REPLY=$((10#${BASH_REMATCH[1]} * 60 + 10#${BASH_REMATCH[2]}))
}

# Sets REPLY to $1 without spaces at either end.
routines_trim() {
  REPLY=${1#"${1%%[![:space:]]*}"}
  REPLY=${REPLY%"${REPLY##*[![:space:]]}"}
}

# Sets REPLY to "start-end" in minutes for "HH:MM" or "HH:MM-HH:MM" $1 (a time: start = end);
# returns 1 with the reason in REPLY when it isn't one.
routines_slot() {
  local start
  if [[ "$1" == *-* ]]; then
    routines_minutes "${1%-*}" || { REPLY="not a time: ${1%-*}" && return 1; }
    start=$REPLY
    routines_minutes "${1#*-}" || { REPLY="not a time: ${1#*-}" && return 1; }
    [ "$REPLY" -gt "$start" ] || { REPLY="window ends before it starts: $1 (windows can't cross midnight)" && return 1; }
    REPLY="$start-$REPLY"
  else
    routines_minutes "$1" || { REPLY="not a time: $1" && return 1; }
    REPLY="$REPLY-$REPLY"
  fi
}

# Parses one schedule ("daily 10:30, 15:00", "tue,thu 18:30", "monthly last-workday 10:00") into
# ROUTINE_KIND, ROUTINE_DAYS and ROUTINE_TIMES (sorted "start-end" minutes); returns 1 with the
# reason in REPLY.
routines_schedule() {
  local word rest slot slots="" sorted="" next placed s day days list
  routines_trim "$1"
  word=${REPLY%%[[:space:]]*} rest=${REPLY#"$word"}
  ROUTINE_DAYS=""
  case "$word" in
    daily | weekdays) ROUTINE_KIND=$word ;;
    monthly)
      routines_trim "$rest"
      ROUTINE_KIND=monthly ROUTINE_DAYS=${REPLY%%[[:space:]]*} rest=${REPLY#"$ROUTINE_DAYS"}
      if [ "$ROUTINE_DAYS" != last-workday ] &&
        ! { [[ "$ROUTINE_DAYS" =~ ^[0-9]+$ ]] && [ "$ROUTINE_DAYS" -ge 1 ] && [ "$ROUTINE_DAYS" -le 31 ]; }; then
        REPLY="monthly needs a day 1-31 or last-workday: $ROUTINE_DAYS" && return 1
      fi
      ROUTINE_DAYS=$((10#${ROUTINE_DAYS//last-workday/0}))
      [ "$ROUTINE_DAYS" = 0 ] && ROUTINE_DAYS="last-workday"
      ;;
    *)
      ROUTINE_KIND=days
      # read -a splits without expanding a "*" or "?" into file names from the current folder.
      IFS=, read -r -a days <<<"$word"
      for day in "${days[@]}"; do
        case "$day" in
          mon) ROUTINE_DAYS="$ROUTINE_DAYS 1" ;; tue) ROUTINE_DAYS="$ROUTINE_DAYS 2" ;;
          wed) ROUTINE_DAYS="$ROUTINE_DAYS 3" ;; thu) ROUTINE_DAYS="$ROUTINE_DAYS 4" ;;
          fri) ROUTINE_DAYS="$ROUTINE_DAYS 5" ;; sat) ROUTINE_DAYS="$ROUTINE_DAYS 6" ;;
          sun) ROUTINE_DAYS="$ROUTINE_DAYS 7" ;;
          *) REPLY="unknown schedule: $word (daily, weekdays, monthly or days like mon,wed)" && return 1 ;;
        esac
      done
      ROUTINE_DAYS="$ROUTINE_DAYS "
      ;;
  esac
  IFS=", " read -r -a list <<<"$rest"
  for slot in "${list[@]}"; do
    routines_slot "$slot" || return 1
    slots="$slots $REPLY"
  done
  [ -n "$slots" ] || { REPLY="no time given" && return 1; }
  # Earliest first, so the first one that hasn't ended is the next: an insertion sort, plenty
  # for the handful of times a routine has.
  for slot in $slots; do
    placed="" next=""
    for s in $sorted; do
      if [ -z "$placed" ] && [ "${slot%-*}" -lt "${s%-*}" ]; then
        next="$next $slot"
        placed=1
      fi
      next="$next $s"
    done
    [ -n "$placed" ] || next="$next $slot"
    sorted=$next
  done
  ROUTINE_TIMES=${sorted# }
}

# Reads the routines config into ROUTINES_NAME, ROUTINES_KIND, ROUTINES_DAYS, ROUTINES_TIMES,
# ROUTINES_MONTHS ("from-to" or empty) and ROUTINES_OPTIONS (the other options, for the later
# steps), ROUTINES_COUNT routines in all. Lines it can't read are skipped and listed in
# ROUTINES_ERRORS ("line 3: reason"), so one broken line never breaks the status line. A
# routine with the option "disable" is left out.
routines_load() {
  local file=${1:-$ROUTINES_FILE} line n=0 name rest field fields option options months disabled
  ROUTINES_NAME=() ROUTINES_KIND=() ROUTINES_DAYS=() ROUTINES_TIMES=() ROUTINES_MONTHS=() ROUTINES_OPTIONS=()
  ROUTINES_COUNT=0 ROUTINES_ERRORS=""
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    # The file can come from anywhere: tabs become spaces and other control characters go, so
    # nothing in it can reach the terminal as an escape sequence (doctor, and #97's reminders).
    line=${line//$'\t'/ }
    line=${line//[[:cntrl:]]/}
    routines_trim "$line"
    line=$REPLY
    case "$line" in '' | '#'*) continue ;; esac
    if [[ "$line" != *=* ]]; then
      ROUTINES_ERRORS="${ROUTINES_ERRORS}line $n: no \"name = schedule\""$'\n'
      continue
    fi
    routines_trim "${line%%=*}"
    name=$REPLY
    if ! [[ "$name" =~ ^[a-z][a-z0-9_]*$ ]]; then
      ROUTINES_ERRORS="${ROUTINES_ERRORS}line $n: not a name: $name (lowercase letters, digits, _)"$'\n'
      continue
    fi
    case " ${ROUTINES_NAME[*]} " in *" $name "*)
      ROUTINES_ERRORS="${ROUTINES_ERRORS}line $n: $name is already defined"$'\n'
      continue
      ;;
    esac
    rest=${line#*=}
    IFS='|' read -r -a fields <<<"$rest"
    if ! routines_schedule "${fields[0]}"; then
      ROUTINES_ERRORS="${ROUTINES_ERRORS}line $n: $name: $REPLY"$'\n'
      continue
    fi
    months="" disabled="" options=""
    for field in "${fields[@]:1}"; do
      routines_trim "$field"
      option=$REPLY
      case "$option" in
        disable) disabled=1 ;;
        months\ *)
          months=${option#months }
          months=${months// /}
          [[ "$months" =~ ^([1-9]|1[0-2])(-([1-9]|1[0-2]))?$ ]] || {
            ROUTINES_ERRORS="${ROUTINES_ERRORS}line $n: $name: months needs 1-12 or a range like 4-10"$'\n'
            continue 2
          }
          [[ "$months" == *-* ]] || months="$months-$months"
          ;;
        '') ;;
        *) options="$options|$option" ;;
      esac
    done
    [ -n "$disabled" ] && continue
    ROUTINES_NAME[ROUTINES_COUNT]=$name
    ROUTINES_KIND[ROUTINES_COUNT]=$ROUTINE_KIND
    ROUTINES_DAYS[ROUTINES_COUNT]=$ROUTINE_DAYS
    ROUTINES_TIMES[ROUTINES_COUNT]=$ROUTINE_TIMES
    ROUTINES_MONTHS[ROUTINES_COUNT]=$months
    ROUTINES_OPTIONS[ROUTINES_COUNT]=${options#|}
    ROUTINES_COUNT=$((ROUTINES_COUNT + 1))
  done <"$file"
}

# Returns 0 if routine $1 happens on the day $2-$3-$4 (year, month, day) with weekday $5
# (1 Monday … 7 Sunday) in a month of $6 days.
routines_on_day() {
  local i=$1 m=$3 d=$4 wd=$5 dim=$6 from to last lastwd
  if [ -n "${ROUTINES_MONTHS[i]}" ]; then
    from=${ROUTINES_MONTHS[i]%-*} to=${ROUTINES_MONTHS[i]#*-}
    if [ "$from" -le "$to" ]; then
      [ "$m" -ge "$from" ] && [ "$m" -le "$to" ] || return 1
    else # a season over New Year, like 10-4
      [ "$m" -ge "$from" ] || [ "$m" -le "$to" ] || return 1
    fi
  fi
  case "${ROUTINES_KIND[i]}" in
    daily) return 0 ;;
    weekdays) [ "$wd" -le 5 ] ;;
    days) [[ "${ROUTINES_DAYS[i]}" == *" $wd "* ]] ;;
    monthly)
      if [ "${ROUTINES_DAYS[i]}" = last-workday ]; then
        # The month's last day and its weekday, then back over a weekend.
        last=$dim lastwd=$(((wd - 1 + dim - d) % 7 + 1))
        while [ "$lastwd" -gt 5 ]; do last=$((last - 1)) lastwd=$((lastwd - 1)); done
        [ "$d" -eq "$last" ]
      else
        [ "$d" -eq "${ROUTINES_DAYS[i]}" ]
      fi
      ;;
  esac
}

# Sets REPLY to "start end" (seconds since 1970) of routine $1's first occurrence that hasn't
# ended at the moment clock_fields last set (CLOCK_*): the current one during a window, else the
# next. Empty, returning 1, when none comes within ROUTINES_HORIZON days.
routines_next() {
  local i=$1 k y=$CLOCK_YEAR m=$CLOCK_MONTH d=$CLOCK_DAY wd=$CLOCK_WEEKDAY dim base slot start end
  clock_days_in_month "$y" "$m"
  dim=$REPLY
  for ((k = 0; k <= ROUTINES_HORIZON; k++)); do
    if routines_on_day "$i" "$y" "$m" "$d" "$wd" "$dim"; then
      base=$((CLOCK_MIDNIGHT + k * 86400))
      for slot in ${ROUTINES_TIMES[i]}; do
        start=$((base + ${slot%-*} * 60)) end=$((base + ${slot#*-} * 60))
        if [ "$end" -ge "$CLOCK_EPOCH" ]; then
          REPLY="$start $end"
          return 0
        fi
      done
    fi
    wd=$((wd % 7 + 1)) d=$((d + 1))
    if [ "$d" -gt "$dim" ]; then
      d=1 m=$((m + 1))
      [ "$m" -gt 12 ] && m=1 y=$((y + 1))
      clock_days_in_month "$y" "$m"
      dim=$REPLY
    fi
  done
  REPLY=""
  return 1
}
