# shellcheck shell=bash
# shellcheck disable=SC2034 # CLOCK_* is this module's output, read by routines
# clock: the current time and durations. Every reading of the clock goes through here, so
# tests can set the time (BYTEK_NOW) and differences between `date` versions stay in one place.
# Needs: nothing.

# Sets REPLY to the current time in seconds since 1970, or BYTEK_NOW when it is set.
clock_now() {
  REPLY=${BYTEK_NOW:-$(date +%s)}
}

# Sets REPLY to the current local time for file names: "20261120-104500".
clock_stamp() {
  REPLY=$(date +%Y%m%d-%H%M%S)
}

# Sets the local date and time of moment $1 (seconds since 1970; default: now, or BYTEK_NOW)
# from one `date` call: CLOCK_EPOCH, CLOCK_YEAR, CLOCK_MONTH, CLOCK_DAY, CLOCK_WEEKDAY
# (1 Monday … 7 Sunday) and CLOCK_MIDNIGHT (that day's 00:00, in seconds). macOS's date reads a
# moment with -r, GNU's with -d @; the first call finds out which this one is.
clock_fields() {
  local at=${1:-$BYTEK_NOW} out hour minute second
  if [ -z "$at" ]; then
    out=$(date '+%s %Y %m %d %u %H %M %S')
  elif [ "$CLOCK_DATE_FLAG" = gnu ] || { [ -z "$CLOCK_DATE_FLAG" ] && date -d @0 +%s >/dev/null 2>&1; }; then
    CLOCK_DATE_FLAG=gnu
    out=$(date -d "@$at" '+%s %Y %m %d %u %H %M %S')
  else
    CLOCK_DATE_FLAG=bsd
    out=$(date -r "$at" '+%s %Y %m %d %u %H %M %S')
  fi
  read -r CLOCK_EPOCH CLOCK_YEAR CLOCK_MONTH CLOCK_DAY CLOCK_WEEKDAY hour minute second <<<"$out"
  # 10#: "08" is eight, not a bad octal number.
  CLOCK_YEAR=$((10#$CLOCK_YEAR)) CLOCK_MONTH=$((10#$CLOCK_MONTH)) CLOCK_DAY=$((10#$CLOCK_DAY))
  CLOCK_MIDNIGHT=$((CLOCK_EPOCH - 10#$hour * 3600 - 10#$minute * 60 - 10#$second))
}

# Sets REPLY to the number of days in month $2 of year $1.
clock_days_in_month() {
  case $2 in
    2) if (($1 % 4 == 0 && ($1 % 100 != 0 || $1 % 400 == 0))); then REPLY=29; else REPLY=28; fi ;;
    4 | 6 | 9 | 11) REPLY=30 ;;
    *) REPLY=31 ;;
  esac
}

# Sets REPLY to $1 seconds as "41s" or "3m 12s".
clock_duration() {
  if [ "$1" -lt 60 ]; then REPLY="${1}s"; else REPLY="$(($1 / 60))m $(($1 % 60))s"; fi
}
