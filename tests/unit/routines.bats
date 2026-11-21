#!/usr/bin/env bats
# lib/routines.sh: reading the routines config and finding each routine's next occurrence,
# at fixed moments in UTC.
# ROUTINES_* are set by the module under test, and each test runs in its own subshell on purpose:
# shellcheck disable=SC2154,SC2030,SC2031

load ../helpers

setup() {
  bytek_setup
  export TZ=UTC
  load_module clock routines
}

# Prints seconds since 1970 for "YYYY-MM-DD HH:MM" or "YYYY-MM-DD HH:MM:SS" in UTC (GNU date, or
# macOS's, which fills in the current seconds unless they're given).
at() {
  local t=$1
  [[ "$t" =~ :[0-9]{2}:[0-9]{2}$ ]] || t="$t:00"
  date -u -d "$t" +%s 2>/dev/null || date -u -j -f '%Y-%m-%d %H:%M:%S' "$t" +%s
}

# Loads config lines $@ (one routine per argument).
config() {
  printf '%s\n' "$@" >"$TMP/routines"
  routines_load "$TMP/routines"
}

# Fails unless routine number $1's next occurrence, from moment "$2", runs from "$3" to "$4"
# ("YYYY-MM-DD HH:MM"; $4 defaults to $3).
assert_next() {
  clock_fields "$(at "$2")"
  routines_next "$1" || fail "no occurrence after $2"
  assert_equal "$REPLY" "$(at "$3") $(at "${4:-$3}")"
}

@test "daily times: the next one today, else the first tomorrow" {
  config "stretch = daily 15:00, 10:30"
  assert_next 0 "2025-11-30 11:00" "2025-11-30 15:00"
  assert_next 0 "2025-11-30 15:01" "2025-12-01 10:30"
}

@test "a window is current while it lasts, then the next day's" {
  config "walk = daily 19:00-20:00"
  assert_next 0 "2025-11-30 19:30" "2025-11-30 19:00" "2025-11-30 20:00"
  assert_next 0 "2025-11-30 20:01" "2025-12-01 19:00" "2025-12-01 20:00"
}

@test "weekdays skip the weekend; named days only those days" {
  config "wrap_up = weekdays 16:30" "training = tue,thu 18:30"
  assert_next 0 "2025-11-29 09:00" "2025-12-01 16:30" # Saturday → Monday
  assert_next 1 "2025-11-26 19:00" "2025-11-27 18:30" # Wednesday → Thursday
  assert_next 1 "2025-11-27 19:00" "2025-12-02 18:30" # Thursday after → Tuesday
}

@test "monthly on a day; a day a month doesn't have is skipped" {
  config "rent = monthly 15 09:00" "late = monthly 31 09:00"
  assert_next 0 "2025-11-20 10:00" "2025-12-15 09:00"
  assert_next 1 "2025-11-01 10:00" "2025-12-31 09:00" # November has no 31st
}

@test "the last workday of a month, also when the month ends on a weekend" {
  config "invoice = monthly last-workday 10:00"
  assert_next 0 "2025-11-20 09:00" "2025-11-28 10:00" # 30 Nov 2025 is a Sunday → Friday 28th
  assert_next 0 "2025-11-28 11:00" "2025-12-31 10:00"
  assert_next 0 "2026-02-01 09:00" "2026-02-27 10:00" # 28 Feb 2026 is a Saturday
}

@test "a season, also one running over New Year" {
  config "training = tue,thu 18:30 | months 4-10" "gym = mon 18:00 | months 10-4"
  assert_next 0 "2025-11-30 11:00" "2026-04-02 18:30"
  assert_next 1 "2026-06-15 09:00" "2026-10-05 18:00"
  assert_next 1 "2026-12-31 09:00" "2027-01-04 18:00"
}

@test "over the end of a year, and a leap day" {
  config "lunch = daily 12:30" "leap = monthly 29 09:00"
  assert_next 0 "2025-12-31 13:00" "2026-01-01 12:30"
  assert_next 1 "2027-02-01 09:00" "2027-03-29 09:00" # 2027 has no 29 February
  assert_next 1 "2028-02-01 09:00" "2028-02-29 09:00"
}

@test "comments, blank lines and options are read; disabled routines are left out" {
  config "# my routines" "" "lunch = daily 12:30 | icon bowl | heads_up 10m" "old = daily 08:00 | disable"
  assert_equal "$ROUTINES_COUNT|${ROUTINES_NAME[*]}|${ROUTINES_OPTIONS[0]}" "1|lunch|icon bowl|heads_up 10m"
  assert_equal "$ROUTINES_ERRORS" ""
}

@test "broken lines are skipped and named, the others still load" {
  config "lunch = daily 12:30" "no equals sign" "Bad = daily 10:00" "x = sometimes 10:00" \
    "y = daily 25:00" "z = daily 22:00-01:00" "w = monthly 32 09:00" "v = daily 10:00 | months 13" \
    "lunch = daily 13:00" "u = daily"
  assert_equal "$ROUTINES_COUNT" 1
  run printf '%s' "$ROUTINES_ERRORS"
  assert_line --partial 'line 2: no "name = schedule"'
  assert_line --partial "line 3: not a name: Bad"
  assert_line --partial "line 4: x: unknown schedule: sometimes"
  assert_line --partial "line 5: y: not a time: 25:00"
  assert_line --partial "line 6: z: window ends before it starts"
  assert_line --partial "line 7: w: monthly needs a day 1-31"
  assert_line --partial "line 8: v: months needs 1-12"
  assert_line --partial "line 9: lunch is already defined"
  assert_line --partial "line 10: u: no time given"
}

@test "no config file means no routines" {
  routines_load "$TMP/none"
  assert_equal "$ROUTINES_COUNT|$ROUTINES_ERRORS" "0|"
}

@test "a * or ? in the config isn't matched against files in the current folder" {
  mkdir "$TMP/project"
  touch "$TMP/project/10:00" "$TMP/project/r"
  cd "$TMP/project"
  config "a = daily *" "b = mo? 10:00"
  assert_equal "$ROUTINES_COUNT" 0
  run printf '%s' "$ROUTINES_ERRORS"
  assert_line --partial "line 1: a: not a time: *"
  assert_line --partial "line 2: b: unknown schedule: mo?"
}

@test "tabs separate like spaces in the config" {
  config $'lunch\t=\tdaily\t12:30'
  assert_equal "$ROUTINES_COUNT|${ROUTINES_NAME[0]}|${ROUTINES_TIMES[0]}" "1|lunch|750-750"
}

# Fails unless the reminder at moment "$1" is stage $2 with text $3 and $4 more (default 0).
assert_reminder() {
  clock_fields "$(at "$1")"
  routines_reminder
  assert_equal "$ROUTINES_STAGE|$ROUTINES_TEXT|$ROUTINES_MORE" "$2|$3|${4:-0}"
}

@test "a reminder goes from heads-up to due to overdue, then away" {
  config "lunch = daily 12:30 | heads_up 10m"
  assert_reminder "2025-11-30 12:19" "" ""
  assert_reminder "2025-11-30 12:22" heads_up "lunch in 8m"
  assert_reminder "2025-11-30 12:30" due "lunch now"
  assert_reminder "2025-11-30 12:45" overdue "lunch 15m ago"
  assert_reminder "2025-11-30 12:51" "" ""
}

@test "a window is due while it lasts, with its end" {
  config "walk = daily 19:00-20:00 | heads_up 10m"
  assert_reminder "2025-11-30 19:30" due "walk now, until 20:00"
  assert_reminder "2025-11-30 20:15" overdue "walk 15m ago"
}

@test "without heads_up there is no heads-up; overdue can be set per routine" {
  config "stretch = daily 15:00 | overdue 5m"
  assert_reminder "2025-11-30 14:55" "" ""
  assert_reminder "2025-11-30 15:04" overdue "stretch 4m ago"
  assert_reminder "2025-11-30 15:06" "" ""
}

@test "with several, the most urgent shows and the others are counted" {
  config "lunch = daily 12:30 | heads_up 10m" "wrap_up = daily 12:35 | heads_up 30m" "plain = daily 12:40"
  assert_reminder "2025-11-30 12:10" heads_up "wrap up in 25m"
  assert_reminder "2025-11-30 12:22" heads_up "lunch in 8m" 1
  assert_reminder "2025-11-30 12:36" overdue "lunch 6m ago" 1
  assert_reminder "2025-11-30 12:45" overdue "lunch 15m ago" 2
}

@test "long heads-ups read in hours and days" {
  config "invoice = monthly last-workday 10:00 | heads_up 2d"
  assert_reminder "2025-11-27 08:30" heads_up "invoice in 1d 1h"
  assert_reminder "2025-11-28 08:30" heads_up "invoice in 1h 30m"
}

@test "a time is due for its whole minute, then overdue in full minutes" {
  config "lunch = daily 12:30 | heads_up 10m"
  assert_reminder "2025-11-30 12:29:30" heads_up "lunch in 1m"
  assert_reminder "2025-11-30 12:30:30" due "lunch now"
  assert_reminder "2025-11-30 12:30:59" due "lunch now"
  assert_reminder "2025-11-30 12:31:00" overdue "lunch 1m ago"
  assert_reminder "2025-11-30 12:31:59" overdue "lunch 1m ago"
}

@test "a window is due through its last minute" {
  config "walk = daily 19:00-20:00"
  assert_reminder "2025-11-30 20:00:30" due "walk now, until 20:00"
  assert_reminder "2025-11-30 20:01:00" overdue "walk 1m ago"
}

@test "a mistyped heads_up or overdue makes the line broken, so doctor names it" {
  config "a = daily 10:00 | heads_up 10min" "b = daily 10:00 | overdue 1hour" "c = daily 10:00 | heads_up 10" \
    "d = daily 10:00 | heads_up 2h | overdue 30m"
  assert_equal "$ROUTINES_COUNT|${ROUTINES_NAME[*]}|${ROUTINES_HEADS[0]}|${ROUTINES_LATE[0]}" "1|d|7200|1800"
  run printf '%s' "$ROUTINES_ERRORS"
  assert_line --partial "line 1: a: heads_up needs a time like 10m, 2h or 1d"
  assert_line --partial "line 2: b: overdue needs a time like 10m, 2h or 1d"
  assert_line --partial "line 3: c: heads_up needs a time like 10m, 2h or 1d"
}

@test "the icon picks a companion; one that isn't a name makes the line broken" {
  config "walk = daily 19:00 | icon dog" "bad = daily 10:00 | icon ../x"
  assert_equal "$ROUTINES_COUNT|${ROUTINES_ICON[0]}" "1|dog"
  run printf '%s' "$ROUTINES_ERRORS"
  assert_line --partial "line 2: bad: icon needs a name like dog or meal"
}

# Clears routine $2 with $1 (done or skip) at moment "$3", through routines_clear.
clear_at() {
  clock_fields "$(at "$3")"
  routines_clear "$1" "$2"
}

# Prints the reminder text at moment "$1".
reminder_at() {
  clock_fields "$(at "$1")"
  routines_reminder
  printf '%s' "$ROUTINES_TEXT"
}

@test "done clears the occurrence showing now; the next one shows as usual" {
  config "walk = daily 13:30-14:10, 18:00-18:40 | heads_up 10m"
  assert_equal "$(reminder_at "2025-11-30 14:15")" "walk 5m ago"
  run clear_at "done" walk "2025-11-30 14:15"
  assert_success
  assert_output "walk at 13:30: done"
  assert_equal "$(reminder_at "2025-11-30 14:15")" ""
  assert_equal "$(reminder_at "2025-11-30 17:55")" "walk in 5m"
}

@test "skip before the heads-up clears the next one today; nothing left today is refused" {
  config "walk = daily 13:30, 18:00 | heads_up 10m"
  run clear_at skip walk "2025-11-30 15:00"
  assert_output "walk at 18:00: skipped"
  assert_equal "$(reminder_at "2025-11-30 17:55")" ""
  assert_equal "$(reminder_at "2025-12-01 13:25")" "walk in 5m"
  run clear_at skip walk "2025-11-30 19:00"
  assert_failure
  assert_output --partial "no walk left today to clear"
}

@test "clearing twice moves on to the following occurrence" {
  config "walk = daily 13:30, 18:00 | heads_up 10m"
  run clear_at "done" walk "2025-11-30 13:25"
  assert_output "walk at 13:30: done"
  run clear_at "done" walk "2025-11-30 13:26"
  assert_output "walk at 18:00: done"
}

@test "an unknown routine is refused and nothing is written" {
  config "walk = daily 13:30"
  run clear_at "done" lunch "2025-11-30 13:30"
  assert_failure
  assert_output --partial "unknown routine: lunch"
  [ ! -e "$BYTEK_HOME/cleared" ]
}

@test "the cleared file is versioned, and entries older than two days drop out" {
  config "walk = daily 13:30" "lunch = daily 12:30"
  clear_at "done" lunch "2025-11-27 12:30" >/dev/null
  clear_at "done" walk "2025-11-29 13:30" >/dev/null
  clear_at "done" walk "2025-11-30 13:30" >/dev/null
  run cat "$BYTEK_HOME/cleared"
  assert_line --index 0 "format=1"
  refute_output --partial "lunch"
  assert_line --index 1 --partial "walk $(at "2025-11-29 13:30") done"
  assert_line --index 2 --partial "walk $(at "2025-11-30 13:30") done"
}

@test "a cleared file from a newer Bytek clears nothing and is left as it is" {
  config "walk = daily 13:30"
  printf 'format=2\nwalk %s done 0\n' "$(at "2025-11-30 13:30")" >"$BYTEK_HOME/cleared"
  assert_equal "$(reminder_at "2025-11-30 13:30")" "walk now"
  run clear_at "done" walk "2025-11-30 13:30"
  assert_failure
  assert_output --partial "from a newer Bytek"
  run head -1 "$BYTEK_HOME/cleared"
  assert_output "format=2"
}

@test "clear idle: 10 minutes away by default, or the time given; anything else is a broken line" {
  config "walk = daily 13:30 | clear idle" "lunch = daily 12:30 | clear idle 15m" "tea = daily 16:00" \
    "nap = daily 14:00 | clear idle 15min"
  assert_equal "${ROUTINES_AWAY[*]}" "600 900 0"
  assert_equal "$ROUTINES_ERRORS" "line 4: nap: clear idle takes a time like 10m, or nothing"$'\n'
}

@test "away long enough while a clear idle routine is due or overdue clears it as idle" {
  config "walk = daily 13:30-14:10 | heads_up 10m | clear idle" "tea = daily 13:30-14:10"
  clock_fields "$(at "2025-11-30 13:25")"
  routines_clear_away 1200
  assert_equal "$(reminder_at "2025-11-30 13:25")" "walk in 5m" # not started yet: kept
  clock_fields "$(at "2025-11-30 13:45")"
  routines_clear_away 300
  assert_equal "$(reminder_at "2025-11-30 13:45")" "walk now, until 14:10" # 5 minutes: kept
  clock_fields "$(at "2025-11-30 13:45")"
  routines_clear_away 600
  assert_equal "$(reminder_at "2025-11-30 13:45")" "tea now, until 14:10" # walk cleared, tea has no clear idle
  run cat "$BYTEK_HOME/cleared"
  assert_line --index 1 "walk $(at "2025-11-30 13:30") idle $(at "2025-11-30 13:45")"
}
