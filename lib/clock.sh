# shellcheck shell=bash
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

# Sets REPLY to $1 seconds as "41s" or "3m 12s".
clock_duration() {
  if [ "$1" -lt 60 ]; then REPLY="${1}s"; else REPLY="$(($1 / 60))m $(($1 % 60))s"; fi
}
