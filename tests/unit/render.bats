#!/usr/bin/env bats
# lib/render.sh: frames, face files, the progress bar and cutting text.
# shellcheck disable=SC2154,SC2030,SC2031 # F_<key> is set by the module under test; each test sets its own BYTEK_UTF8

load ../helpers

setup() {
  bytek_setup
  load_module clock state charset render
}

@test "a frame is picked by the tick, wrapping around, keeping leading spaces" {
  render_pick "a| b|c" 1
  assert_equal "$REPLY" " b"
  render_pick "a| b|c" 5
  assert_equal "$REPLY" "c"
  render_pick "" 3
  assert_equal "$REPLY" ""
}

@test "a face file's keys are read, comments and other keys skipped" {
  printf '# a comment\nframes: •ᴗ•|-ᴗ-\nstatus: reading\nother: x\ndetail: {arg}\n' >"$TMP/face"
  render_face "$TMP/face"
  assert_equal "$F_frames|$F_status|$F_detail|$F_thought" "•ᴗ•|-ᴗ-|reading|{arg}|"
}

@test "the bar shows known progress in five cells" {
  render_bar 3/5 0
  assert_equal "$REPLY" "▰▰▰▱▱ 3/5"
  render_bar 5/5 0
  assert_equal "$REPLY" "▰▰▰▰▰ 5/5"
}

@test "unknown progress sweeps one cell along with the tick" {
  render_bar "" 2
  assert_equal "$REPLY" "▱▱▰▱▱"
  render_bar 1/0 6
  assert_equal "$REPLY" "▱▰▱▱▱"
}

@test "text is cut to the width with an ellipsis, and only when it doesn't fit" {
  render_cut "short" 10
  assert_equal "$REPLY" "short"
  render_cut "a long status" 6
  assert_equal "$REPLY" "a lon…"
  render_cut "ᴗᴗᴗᴗ" 3
  assert_equal "$REPLY" "ᴗᴗ…"
  render_cut "anything" 1
  assert_equal "$REPLY" ""
  render_cut "no width" ""
  assert_equal "$REPLY" "no width"
}

@test "without a UTF-8 locale text isn't cut, so no character is split" {
  export BYTEK_UTF8=0
  render_cut "a long status" 6
  assert_equal "$REPLY" "a long status"
}

@test "companion frames are padded to the widest, except without UTF-8, where lengths are bytes" {
  render_pick_padded "ab~|ab" 1
  assert_equal "[$REPLY]" "[ab ]"
  export BYTEK_UTF8=0
  render_pick_padded "~\\_/|≈\\_/" 0
  assert_equal "[$REPLY]" "[~\\_/]"
}

@test "in ascii, a face file's _ascii keys win; a file without them keeps its own" {
  printf 'frames: •ᴗ•\nframes_ascii: o_o\ndetail_ascii: > {arg}\ndetail: ▸ {arg}\nthought: ✎\n' >"$TMP/face"
  CHARSET=ascii render_face "$TMP/face"
  assert_equal "$F_frames|$F_detail|$F_thought" "o_o|> {arg}|✎"
  CHARSET=unicode render_face "$TMP/face"
  assert_equal "$F_frames|$F_detail|$F_thought" "•ᴗ•|▸ {arg}|✎"
}

@test "in ascii, the bar, the cut and Bytek's own marks are plain ASCII" {
  render_ascii
  render_bar 3/5 0
  assert_equal "$REPLY" "###-- 3/5"
  BYTEK_UTF8=1 render_cut "abcdefghij" 6
  assert_equal "$REPLY" "abc..."
  BYTEK_UTF8=1 render_cut "abcdefghij" 3
  assert_equal "$REPLY" ""
  render_ascii_text "3 changes · lib/ä.sh, ✓ tests passed"
  assert_equal "$REPLY" "3 changes - lib/ä.sh, + tests passed"
}
