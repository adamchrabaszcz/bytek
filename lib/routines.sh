# shellcheck shell=bash
# shellcheck disable=SC2034 # ROUTINES_* are this module's output, read by doctor (and the stages, #97)
# routines: the user's reminders, from $BYTEK_HOME/config/routines (format and example in
# docs/architecture/data-files.md and examples/routines.example): when each one happens next.
# Plain bash on the render path: one `date` call for the clock fields, then arithmetic, walking
# forward day by day. Occurrences after a daylight saving change are off by the change until
# that day comes; each run counts from that day's own midnight.
# Needs: clock.

ROUTINES_FILE="${BYTEK_ROUTINES:-$BYTEK_HOME/config/routines}"
ROUTINES_HORIZON=366                        # days to look ahead for the next occurrence (a season can be months away)
ROUTINES_CLEARED_FILE="$BYTEK_HOME/cleared" # occurrences cleared with done or skip
ROUTINES_CLEARED_FORMAT=1                   # the newest cleared file format this version reads
ROUTINES_CLEARED_KEEP=172800                # seconds a cleared occurrence is kept after its start: 2 days
ROUTINES_AWAY_DEFAULT=600                   # seconds away from the Mac that clear a "clear idle" routine: 10 min

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
# ROUTINES_MONTHS ("from-to" or empty), ROUTINES_HEADS and ROUTINES_LATE (the heads_up and
# overdue options in seconds, read once here rather than on every render) and ROUTINES_OPTIONS
# (the options as written, for the later steps), ROUTINES_COUNT routines in all. Lines it can't
# read are skipped and listed in ROUTINES_ERRORS ("line 3: reason"), so one broken line never
# breaks the status line. A routine with the option "disable" is left out.
routines_load() {
  local file=${1:-$ROUTINES_FILE} line n=0 name rest field fields option options months disabled heads late icon away
  ROUTINES_NAME=() ROUTINES_KIND=() ROUTINES_DAYS=() ROUTINES_TIMES=() ROUTINES_MONTHS=() ROUTINES_OPTIONS=()
  ROUTINES_HEADS=() ROUTINES_LATE=() ROUTINES_ICON=() ROUTINES_AWAY=()
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
    months="" disabled="" options="" heads=0 late=$ROUTINES_OVERDUE icon="" away=0
    for field in "${fields[@]:1}"; do
      routines_trim "$field"
      option=$REPLY
      case "$option" in
        disable) disabled=1 ;;
        icon\ *)
          icon=${option#icon }
          [[ "$icon" =~ ^[a-z][a-z-]*$ ]] || {
            ROUTINES_ERRORS="${ROUTINES_ERRORS}line $n: $name: icon needs a name like dog or meal"$'\n'
            continue 2
          }
          options="$options|$option"
          ;;
        clear\ idle | clear\ idle\ *)
          away=$ROUTINES_AWAY_DEFAULT
          if [ "$option" != "clear idle" ] && ! routines_seconds "${option#clear idle }"; then
            ROUTINES_ERRORS="${ROUTINES_ERRORS}line $n: $name: clear idle takes a time like 10m, or nothing"$'\n'
            continue 2
          fi
          [ "$option" = "clear idle" ] || away=$REPLY
          options="$options|$option"
          ;;
        heads_up\ * | overdue\ *)
          routines_seconds "${option#* }" || {
            ROUTINES_ERRORS="${ROUTINES_ERRORS}line $n: $name: ${option%% *} needs a time like 10m, 2h or 1d"$'\n'
            continue 2
          }
          if [ "${option%% *}" = heads_up ]; then heads=$REPLY; else late=$REPLY; fi
          options="$options|$option"
          ;;
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
    ROUTINES_HEADS[ROUTINES_COUNT]=$heads
    ROUTINES_LATE[ROUTINES_COUNT]=$late
    ROUTINES_ICON[ROUTINES_COUNT]=$icon
    ROUTINES_AWAY[ROUTINES_COUNT]=$away
    ROUTINES_COUNT=$((ROUTINES_COUNT + 1))
  done <"$file"
}

# Returns 0 if month $2 is in routine $1's season (always, without one).
routines_in_season() {
  local from to
  [ -n "${ROUTINES_MONTHS[$1]}" ] || return 0
  from=${ROUTINES_MONTHS[$1]%-*} to=${ROUTINES_MONTHS[$1]#*-}
  if [ "$from" -le "$to" ]; then
    [ "$2" -ge "$from" ] && [ "$2" -le "$to" ]
  else # a season over New Year, like 10-4
    [ "$2" -ge "$from" ] || [ "$2" -le "$to" ]
  fi
}

# Sets REPLY to how many days from day $2 (weekday $3, in a month of $4 days) routine $1's next
# possible day is: 0 for this one, and to the 1st of next month when none is left in this one.
# Jumping instead of looking at each day keeps a season months away (or a monthly routine) to a
# few steps on the render path.
routines_skip() {
  local i=$1 d=$2 wd=$3 dim=$4 target lastwd
  case "${ROUTINES_KIND[i]}" in
    daily) REPLY=0 ;;
    weekdays) if [ "$wd" -le 5 ]; then REPLY=0; else REPLY=$((8 - wd)); fi ;;
    days) # the next listed weekday, at most six days away
      REPLY=0
      while [[ "${ROUTINES_DAYS[i]}" != *" $(((wd - 1 + REPLY) % 7 + 1)) "* ]]; do REPLY=$((REPLY + 1)); done
      ;;
    monthly)
      if [ "${ROUTINES_DAYS[i]}" = last-workday ]; then
        # The month's last day and its weekday, then back over a weekend.
        target=$dim lastwd=$(((wd - 1 + dim - d) % 7 + 1))
        while [ "$lastwd" -gt 5 ]; do target=$((target - 1)) lastwd=$((lastwd - 1)); done
      else
        target=${ROUTINES_DAYS[i]}
      fi
      if [ "$d" -le "$target" ] && [ "$target" -le "$dim" ]; then
        REPLY=$((target - d))
      else
        REPLY=$((dim - d + 1))
      fi
      ;;
  esac
}

# Sets REPLY to "start end" (seconds since 1970) of routine $1's first occurrence that hasn't
# ended at the moment clock_fields last set (CLOCK_*): the current one during a window, else the
# next. Empty, returning 1, when none comes within ROUTINES_HORIZON days.
routines_next() {
  local i=$1 k=0 y=$CLOCK_YEAR m=$CLOCK_MONTH d=$CLOCK_DAY wd=$CLOCK_WEEKDAY dim jump base slot start end
  clock_days_in_month "$y" "$m"
  dim=$REPLY
  while [ "$k" -le "$ROUTINES_HORIZON" ]; do
    if routines_in_season "$i" "$m"; then
      routines_skip "$i" "$d" "$wd" "$dim"
      jump=$REPLY
    else
      jump=$((dim - d + 1)) # out of season: on to the 1st of next month
    fi
    if [ "$jump" -eq 0 ]; then
      base=$((CLOCK_MIDNIGHT + k * 86400))
      for slot in ${ROUTINES_TIMES[i]}; do
        start=$((base + ${slot%-*} * 60)) end=$((base + ${slot#*-} * 60))
        if [ "$end" -ge "$CLOCK_EPOCH" ]; then
          REPLY="$start $end"
          return 0
        fi
      done
      jump=1
    fi
    k=$((k + jump)) wd=$(((wd - 1 + jump) % 7 + 1)) d=$((d + jump))
    while [ "$d" -gt "$dim" ]; do
      d=$((d - dim)) m=$((m + 1))
      [ "$m" -gt 12 ] && m=1 y=$((y + 1))
      clock_days_in_month "$y" "$m"
      dim=$REPLY
    done
  done
  REPLY=""
  return 1
}

ROUTINES_OVERDUE=1200 # seconds a reminder stays after its time (or window) has passed: 20 min

# Sets REPLY to the seconds in a duration like "10m", "2h" or "1d"; returns 1 if it isn't one.
routines_seconds() {
  [[ "$1" =~ ^([0-9]+)([mhd])$ ]] || return 1
  case ${BASH_REMATCH[2]} in
    m) REPLY=$((10#${BASH_REMATCH[1]} * 60)) ;;
    h) REPLY=$((10#${BASH_REMATCH[1]} * 3600)) ;;
    d) REPLY=$((10#${BASH_REMATCH[1]} * 86400)) ;;
  esac
}

# Sets REPLY to $1 seconds, rounded up to minutes, as "8m", "1h 30m", "2h" or "1d 3h".
routines_until() {
  local m=$((($1 + 59) / 60))
  if [ "$m" -lt 60 ]; then
    REPLY="${m}m"
  elif [ "$m" -lt 1440 ]; then
    REPLY="$((m / 60))h"
    [ $((m % 60)) -gt 0 ] && REPLY="$REPLY $((m % 60))m"
  else
    REPLY="$((m / 1440))d"
    [ $((m % 1440 / 60)) -gt 0 ] && REPLY="$REPLY $((m % 1440 / 60))h"
  fi
}

# Sets the most urgent reminder at the moment clock_fields last set: ROUTINES_TEXT ("lunch in
# 8m", "lunch now", "walk now, until 20:00", "lunch 15m ago"), ROUTINES_STAGE (heads_up, due or
# overdue) and ROUTINES_MORE (how many other routines are in a stage too). Overdue beats due beats
# a heads-up; among equals, the one that starts first. All empty (ROUTINES_MORE 0) when none is.
# A heads-up needs the routine's heads_up option; overdue lasts ROUTINES_OVERDUE, or its own
# overdue option. A time is due for its whole minute (12:30:00 to 12:30:59), a window through
# its last minute; "ago" counts full minutes from its end. An occurrence that ended before
# today's midnight isn't seen as overdue.
routines_reminder() {
  local i now=$CLOCK_EPOCH start end heads late rank stage best=0 first=0 count=0 name text minute when
  ROUTINES_TEXT="" ROUTINES_STAGE="" ROUTINES_MORE=0 ROUTINES_SHOWN_ICON="" ROUTINES_SHOWN_NAME="" ROUTINES_SHOWN_WHEN=""
  routines_cleared_load
  for ((i = 0; i < ROUTINES_COUNT; i++)); do
    heads=${ROUTINES_HEADS[i]} late=${ROUTINES_LATE[i]}
    routines_current "$i" "$now" || continue
    start=${REPLY% *} end=${REPLY#* }
    # Without a heads_up option, start - heads is the start itself: no heads-up stage.
    if [ "$now" -lt $((start - heads)) ]; then
      continue
    elif [ "$now" -lt "$start" ]; then
      rank=1 stage=heads_up
    elif [ "$now" -lt $((end + 60)) ]; then
      rank=2 stage=due
    else
      rank=3 stage=overdue
    fi
    count=$((count + 1))
    [ "$rank" -gt "$best" ] || { [ "$rank" -eq "$best" ] && [ "$start" -lt "$first" ]; } || continue
    best=$rank first=$start name=${ROUTINES_NAME[i]//_/ }
    case $stage in
      heads_up)
        routines_until $((start - now))
        text="$name in $REPLY" when=$REPLY
        ;;
      due)
        text="$name now" when=""
        if [ "$end" -gt "$start" ]; then
          minute=$((((end - CLOCK_MIDNIGHT) / 60) % 1440))
          printf -v minute '%02d:%02d' $((minute / 60)) $((minute % 60)) # -v: no subshell
          text="$text, until $minute"
        fi
        ;;
      overdue)
        routines_until $(((now - end) / 60 * 60)) # full minutes: 12:31:30 is "1m ago"
        text="$name $REPLY ago" when=$REPLY
        ;;
    esac
    ROUTINES_TEXT=$text ROUTINES_STAGE=$stage ROUTINES_SHOWN_ICON=${ROUTINES_ICON[i]} ROUTINES_SHOWN_NAME=${ROUTINES_NAME[i]} ROUTINES_SHOWN_WHEN=$when
  done
  [ "$count" -gt 0 ] && ROUTINES_MORE=$((count - 1))
  return 0
}

# Sets REPLY to "start end" of routine $1's occurrence that a reminder is about at moment $2:
# the first one not over for longer than its overdue time and not cleared (done or skip).
# Returns 1 when none comes within ROUTINES_HORIZON days. Reads ROUTINES_CLEARED
# (routines_cleared_load) and leaves CLOCK_EPOCH at $2.
routines_current() {
  local i=$1 start end
  # From $2 minus the overdue time, so an occurrence that has just passed is still found.
  CLOCK_EPOCH=$(($2 - ROUTINES_LATE[i]))
  while routines_next "$i"; do
    start=${REPLY% *} end=${REPLY#* }
    case "$ROUTINES_CLEARED" in
      *" ${ROUTINES_NAME[i]}@$start "*) CLOCK_EPOCH=$((end + 1)) ;; # cleared: the one after it
      *)
        CLOCK_EPOCH=$2
        return 0
        ;;
    esac
  done
  CLOCK_EPOCH=$2
  return 1
}

# Reads the cleared file into ROUTINES_CLEARED, " name@start " for each cleared occurrence. A
# missing file clears nothing; one without a format line this Bytek reads (a newer one) clears
# nothing and returns 1, so nobody overwrites it. A plain file read: no programs on the render path.
routines_cleared_load() {
  local line first=1 name start
  ROUTINES_CLEARED=" "
  [ -f "$ROUTINES_CLEARED_FILE" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ -n "$first" ]; then
      first=""
      [[ "$line" =~ ^format=([0-9]+)$ ]] && [ "${BASH_REMATCH[1]}" -le "$ROUTINES_CLEARED_FORMAT" ] && continue
      return 1
    fi
    name=${line%% *} start=${line#* }
    start=${start%% *}
    [[ "$name" =~ ^[a-z][a-z0-9_]*$ && "$start" =~ ^[0-9]+$ ]] && ROUTINES_CLEARED="$ROUTINES_CLEARED$name@$start "
  done <"$ROUTINES_CLEARED_FILE"
  return 0
}

# Adds routine $1's occurrence starting at $2, cleared with $3 (done, skip or idle) at moment $4,
# to the cleared file, written whole (temp file and rename) and dropping entries that started
# before ROUTINES_CLEARED_KEEP ago. Returns 1 when the file can't be written.
routines_cleared_add() {
  local line kept="" old=$(($4 - ROUTINES_CLEARED_KEEP)) tmp re='^[a-z][a-z0-9_]* ([0-9]+) '
  if [ -f "$ROUTINES_CLEARED_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      [[ "$line" =~ $re ]] && [ "${BASH_REMATCH[1]}" -ge "$old" ] && kept="$kept$line"$'\n'
    done <"$ROUTINES_CLEARED_FILE"
  fi
  mkdir -p "${ROUTINES_CLEARED_FILE%/*}" && tmp=$(mktemp "$ROUTINES_CLEARED_FILE.XXXXXX") || return 1
  if ! { printf 'format=%s\n%s%s %s %s %s\n' "$ROUTINES_CLEARED_FORMAT" "$kept" "$1" "$2" "$3" "$4" >"$tmp" &&
    mv "$tmp" "$ROUTINES_CLEARED_FILE"; }; then
    rm -f "$tmp"
    return 1
  fi
  ROUTINES_CLEARED="$ROUTINES_CLEARED$1@$2 "
}

# bytek done|skip <routine>: clears routine $2's occurrence with $1 (done or skip): the one its
# reminder shows now, else the next one that starts today. Needs routines_load and clock_fields;
# from bin/bytek: die.
routines_clear() {
  local how=$1 name=$2 i found="" now start minute
  [ -n "$name" ] || die "usage: bytek $how <routine>"
  [[ "$name" != *" "* ]] || die "a routine's name is one word, as in the config: ${name// /_}"
  for ((i = 0; i < ROUTINES_COUNT; i++)); do
    [ "${ROUTINES_NAME[i]}" = "$name" ] && found=$i
  done
  [ -n "$found" ] || die "unknown routine: $name (or one with disable; see $ROUTINES_FILE)"
  now=$CLOCK_EPOCH
  routines_cleared_load || die "$ROUTINES_CLEARED_FILE is from a newer Bytek; left as it is"
  routines_current "$found" "$now" || die "no $name coming up to clear"
  start=${REPLY% *}
  # Not showing yet (before its heads-up): only one that starts today.
  if [ "$now" -lt $((start - ROUTINES_HEADS[found])) ] && [ "$start" -ge $((CLOCK_MIDNIGHT + 86400)) ]; then
    die "no $name left today to clear"
  fi
  routines_cleared_add "$name" "$start" "$how" "$now" || die "cannot write $ROUTINES_CLEARED_FILE"
  minute=$(((start - CLOCK_MIDNIGHT) / 60))
  # A heads-up can show for tomorrow (heads_up 1d): its time of day, not minutes past today.
  minute=$(((minute % 1440 + 1440) % 1440))
  [ "$how" = skip ] && how=skipped
  printf '%s at %02d:%02d: %s\n' "${name//_/ }" $((minute / 60)) $((minute % 60)) "$how"
}

# Clears, as idle, each "clear idle" routine when the person has been away for its away time
# since its occurrence started. The Mac has had no input for $1 seconds; only the part since the
# start counts (stepping away just before lunch isn't lunch). Away during it means it happened:
# out for the walk, at lunch. Needs routines_load and clock_fields. Returns 1 when the cleared
# file can't be read (a newer Bytek's) or written.
routines_clear_away() {
  local i now=$CLOCK_EPOCH start
  routines_cleared_load || return 1
  for ((i = 0; i < ROUTINES_COUNT; i++)); do
    [ "${ROUTINES_AWAY[i]}" -gt 0 ] && [ "$1" -ge "${ROUTINES_AWAY[i]}" ] || continue
    routines_current "$i" "$now" || continue
    start=${REPLY% *}
    # Away since the start counts, not before it: min(idle, now - start) is long enough.
    [ "$now" -ge "$start" ] && [ $((now - start)) -ge "${ROUTINES_AWAY[i]}" ] || continue
    routines_cleared_add "${ROUTINES_NAME[i]}" "$start" idle "$now" || return 1
  done
  return 0
}
