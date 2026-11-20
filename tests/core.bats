#!/usr/bin/env bats
# The renderer: every state in every frame keeps the bot aligned (4 lines, fixed box edges,
# the antenna in column 5, 3-character faces), plus sleeping, sessions, cutting and fallback.

load helpers

# Fails with a message unless $1 is a correctly aligned 4-line bot; $2 names the case.
assert_aligned() {
  local n=0 l1="" l2="" l3="" l4="" line
  while IFS= read -r line; do
    n=$((n + 1))
    case $n in 1) l1=$line ;; 2) l2=$line ;; 3) l3=$line ;; 4) l4=$line ;; esac
  done <<<"$1"
  [ "$n" -eq 4 ] || fail "$2: expected 4 lines, got $n"
  l1=${l1#$'\033[0m'} # the invisible reset that keeps Claude Code from trimming the indent
  [ "${l1:0:4}" = "    " ] || fail "$2: antenna not in column 5: '$l1'"
  [ "${l1:4:1}" != " " ] || fail "$2: antenna missing: '$l1'"
  [ "$l2" = " ╭──┴──╮" ] || fail "$2: box top shifted: '$l2'"
  [ "${l3:0:3}" = " │ " ] || fail "$2: face line start: '$l3'"
  [ "${l3:6:2}" = " │" ] || fail "$2: face not 3 characters: '$l3'"
  [ "${l4:0:8}" = " ╰─┬─┬─╯" ] || fail "$2: box bottom shifted: '$l4'"
}

@test "every state renders aligned in every frame" {
  local face state t out
  for face in "$ROOT"/faces/*; do
    state=${face##*/}
    "$BYTEK" set "$state" "src/api.ts" --progress 3/5
    for t in 0 1 2 3 4 5 6 7 8 9 10 11; do
      out=$(printf '{"session_id":"none"}' | BYTEK_NOW=$((1000 + t)) "$BYTEK" render)
      assert_aligned "$out" "$state@$t"
    done
  done
}

@test "long inactivity turns into sleeping" {
  BYTEK_NOW=1000 "$BYTEK" set idle
  BYTEK_NOW=1700 run render
  assert_output --partial "idle for 11m"
}

@test "a session's own state wins over the default one" {
  "$BYTEK" set editing src/a.ts
  "$BYTEK" set error --session abc-123
  run render abc-123
  assert_output --partial "something failed"
}

@test "narrow terminals cut long text" {
  "$BYTEK" set editing "a/very/long/path/that/does/not/fit/anywhere/in/a/narrow/window.ts"
  COLUMNS=30 run render
  assert_output --partial "…"
}

@test "a missing data folder still prints something" {
  BYTEK_ROOT=/nonexistent run render
  assert_success
  refute_output ""
}

@test "the progress bar shows filled cells and the count" {
  "$BYTEK" set testing --progress 3/5
  run render
  assert_output --partial "▰▰▰▱▱ 3/5"
}

@test "unknown progress shows one cell sweeping along" {
  "$BYTEK" set testing
  BYTEK_NOW=1002 run render
  assert_output --partial "▱▱▰▱▱"
}

@test "the output doesn't start with whitespace, so trimming keeps the antenna's column" {
  # Claude Code trims whitespace from the start of the status line's output (#83).
  "$BYTEK" set thinking
  run render
  [[ "$output" != [[:space:]]* ]] || fail "output starts with whitespace: '${output:0:10}'"
  local trimmed="${output#"${output%%[![:space:]]*}"}" first
  first=${trimmed%%$'\n'*}
  first=${first#$'\033[0m'}
  assert_equal "${first:0:5}" "    ♡"
}
