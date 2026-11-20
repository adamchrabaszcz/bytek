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
