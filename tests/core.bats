#!/usr/bin/env bats
# The renderer: every state in every frame keeps the bot aligned (4 lines, fixed box edges,
# the antenna in column 5, 3-character faces), plus sleeping, sessions, cutting and fallback.

load helpers

# Fails with a message unless $1 is a correctly aligned 4-line bot; $2 names the case.
assert_aligned() {
  local n=0 l1="" l2="" l3="" l4="" line
  while IFS= read -r line; do
    line=${line#$'\033[0m'} # the invisible reset that keeps Claude Code from trimming the line
    n=$((n + 1))
    case $n in 1) l1=$line ;; 2) l2=$line ;; 3) l3=$line ;; 4) l4=$line ;; esac
  done <<<"$1"
  [ "$n" -eq 4 ] || fail "$2: expected 4 lines, got $n"
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

@test "a state from a newer Bytek shows as idle" {
  mkdir -p "$BYTEK_HOME/state"
  printf 'format=2\nstate=editing\n' >"$BYTEK_HOME/state/default"
  run render
  assert_output --partial "$(sed -n 's/^status: //p' "$ROOT/faces/idle")"
}

@test "a face file in a newer format shows the idle face instead" {
  local data="$TMP/data"
  mkdir -p "$data"
  cp -R "$ROOT/faces" "$data/faces"
  printf 'format: 2\nframes: ◕‿◕\nstatus: from the future\n' >"$data/faces/future"
  BYTEK_ROOT=$data "$BYTEK" set future
  BYTEK_ROOT=$data run render
  refute_output --partial "from the future"
  assert_output --partial "$(sed -n 's/^status: //p' "$ROOT/faces/idle")"
}

@test "a face file may declare format 1" {
  local data="$TMP/data"
  mkdir -p "$data"
  cp -R "$ROOT/faces" "$data/faces"
  printf 'format: 1\nframes: •ᴗ•\nstatus: declared\n' >"$data/faces/declared"
  BYTEK_ROOT=$data "$BYTEK" set declared
  BYTEK_ROOT=$data run render
  assert_output --partial "declared"
}

@test "no line starts with whitespace, so trimming each line keeps the antenna above its stick" {
  # Claude Code trims the leading whitespace of each status line row (#83).
  local line trimmed=""
  "$BYTEK" set thinking
  run render
  while IFS= read -r line; do
    [[ "$line" != [[:space:]]* ]] || fail "a line starts with whitespace: '$line'"
    # What Claude Code shows: each line trimmed, the invisible reset removed.
    line=${line#"${line%%[![:space:]]*}"}
    trimmed="$trimmed${line#$'\033[0m'}"$'\n'
  done <<<"$output"
  run printf '%s' "$trimmed"
  assert_line --index 0 --partial "    ♡"
  assert_line --index 1 " ╭──┴──╮"
}
