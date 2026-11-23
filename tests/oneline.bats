#!/usr/bin/env bats
# shellcheck disable=SC2154 # F_<key> is set by render_face, the module under test
# The one-line layout (render_oneline): the face, a companion, the status and the detail on a
# single line, for narrow windows and Touch Bar apps; cut to a width, with or without codes.

load helpers

setup() {
  bytek_setup
  export TZ=UTC BYTEK_NOW=1764504000 # Sunday 30 November 2025, 12:00 UTC
  load_module clock state config charset addon routines companions away render
}

# Sets routine "walk" with the dog at $1 (HH:MM), for a reminder at 12:00.
walk_at() {
  mkdir -p "$BYTEK_HOME/config"
  printf 'walk = daily %s | icon dog | heads_up 10m\n' "$1" >"$BYTEK_HOME/config/routines"
}

@test "every state on one line in every frame and both charsets: the face in brackets, then its status" {
  local face state charset t out problems=""
  for charset in unicode ascii; do
    charset_set "$charset"
    for face in "$ROOT"/faces/*; do
      state=${face##*/}
      BYTEK_NOW=1000 "$BYTEK" set "$state" "src/api.ts" --progress 3/5
      CHARSET=$charset render_face "$face"
      for t in 0 1 2 3 4 5 6 7 8 9 10 11; do
        out=$(BYTEK_NOW=$((1000 + t)) render_oneline '{}' "" plain)
        render_pick "$F_frames" $((1000 + t))
        [[ "$out" == "($REPLY) $F_status"* ]] || problems="$problems $charset $state@$t: '$out';"
        [[ "$out" != *$'\n'* ]] || problems="$problems $charset $state@$t: more than one line;"
        if [ "$charset" = ascii ] && printf '%s' "$out" | LC_ALL=C grep -q '[^ -~]'; then
          problems="$problems $charset $state@$t: not ASCII: '$out';"
        fi
      done
    done
  done
  [ -z "$problems" ] || fail "$problems"
}

@test "the detail follows the status after a dot, dimmed unless plain" {
  "$BYTEK" set waiting "Bash: tools/lint.sh"
  assert_equal "$(render_oneline '{}' "" plain)" "(◕ᴗ◕) needs you · Bash: tools/lint.sh"
  assert_equal "$(render_oneline '{}')" $'(◕ᴗ◕) needs you\033[2m · Bash: tools/lint.sh\033[0m'
}

@test "a width cuts the detail first, then the status; the face stays" {
  local face out
  "$BYTEK" set waiting "Bash: tools/lint.sh"
  assert_equal "$(render_oneline '{}' 30 plain)" "(◕ᴗ◕) needs you · Bash: tools…"
  assert_equal "$(render_oneline '{}' 12 plain)" "(◕ᴗ◕) needs…"
  assert_equal "$(render_oneline '{}' 6 plain)" "(◕ᴗ◕)"
  assert_equal "$(render_oneline '{}' 15 plain)" "(◕ᴗ◕) needs yo…"
  assert_equal "$(render_oneline '{}' 20)" $'(◕ᴗ◕) needs you\033[2m · B…\033[0m'
  for face in "$ROOT"/faces/*; do
    "$BYTEK" set "${face##*/}" "a/very/long/path/that/does/not/fit/anywhere.ts" --progress 3/5
    out=$(render_oneline '{}' 24 plain)
    [ "${#out}" -le 24 ] || fail "${face##*/}: ${#out} characters: '$out'"
  done
}

@test "a spinner without its text leaves no space at the end" {
  "$BYTEK" set editing
  out=$(render_oneline '{}' "" plain)
  [[ "$out" == "(≧ᴗ≦) editing · "? ]] || fail "'$out'"
}

@test "a companion stands after the face, its reminder first, without its padding" {
  "$BYTEK" set idle
  walk_at 12:10
  assert_equal "$(render_oneline '{}' "" plain)" "(•ᴗ•) (ᵔᴥᵔ) walk in 10m · ready · waiting for a task"
  walk_at 12:00
  assert_equal "$(BYTEK_NOW=$((BYTEK_NOW + 1)) render_oneline '{}' "" plain)" "(ᵔᴗᵔ) (ᵔᴥᵔ) walk time! · ready · waiting for a task"
}

@test "an overdue reminder is bold, unless plain" {
  "$BYTEK" set idle
  walk_at 11:55
  assert_equal "$(render_oneline '{}')" \
    $'(•ᴗ•) (•ᴥ•)? \033[1mwaiting by the door\033[22m · ready\033[2m · waiting for a task\033[0m'
  assert_equal "$(render_oneline '{}' "" plain)" "(•ᴗ•) (•ᴥ•)? waiting by the door · ready · waiting for a task"
}

@test "a routine without a companion keeps the reminder mark, in ASCII too" {
  "$BYTEK" set idle
  mkdir -p "$BYTEK_HOME/config"
  printf 'stretch = daily 12:05 | heads_up 10m\n' >"$BYTEK_HOME/config/routines"
  assert_equal "$(render_oneline '{}' "" plain)" "(•ᴗ•) ◷ stretch in 5m · ready · waiting for a task"
  charset_set ascii
  assert_equal "$(render_oneline '{}' "" plain)" "(o_o) (!) stretch in 5m - ready - waiting for a task"
}
