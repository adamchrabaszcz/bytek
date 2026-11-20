#!/usr/bin/env bats
# lib/clock.sh: the current time, timestamps and durations.

load ../helpers

setup() {
  bytek_setup
  load_module clock
}

@test "now is BYTEK_NOW when it is set" {
  BYTEK_NOW=1000 clock_now
  assert_equal "$REPLY" 1000
}

@test "now is the system time otherwise" {
  local before after
  before=$(date +%s)
  unset BYTEK_NOW
  clock_now
  after=$(date +%s)
  [ "$REPLY" -ge "$before" ] && [ "$REPLY" -le "$after" ] || fail "now: $REPLY, not between $before and $after"
}

@test "a stamp is a sortable local time for file names" {
  clock_stamp
  [[ "$REPLY" =~ ^[0-9]{8}-[0-9]{6}$ ]] || fail "stamp: $REPLY"
}

@test "durations read as seconds, then minutes and seconds" {
  clock_duration 41
  assert_equal "$REPLY" "41s"
  clock_duration 60
  assert_equal "$REPLY" "1m 0s"
  clock_duration 192
  assert_equal "$REPLY" "3m 12s"
}

@test "the fields of a moment come from one date call, in the local time zone" {
  TZ=UTC clock_fields 1764500400 # Sunday 30 November 2025, 11:00 UTC
  assert_equal "$CLOCK_EPOCH $CLOCK_YEAR-$CLOCK_MONTH-$CLOCK_DAY $CLOCK_WEEKDAY $CLOCK_MIDNIGHT" \
    "1764500400 2025-11-30 7 1764460800"
}

@test "days in a month, leap years included" {
  local y m expected
  for expected in "2026 2 28" "2028 2 29" "2100 2 28" "2000 2 29" "2026 4 30" "2026 12 31"; do
    read -r y m expected <<<"$expected"
    clock_days_in_month "$y" "$m"
    assert_equal "$y-$m: $REPLY" "$y-$m: $expected"
  done
}
