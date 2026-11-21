#!/usr/bin/env bats
# The art stays straight: every data file uses single-width characters only, faces are 3
# characters and add-ons 1, and every look in `bytek preview` keeps the box in its columns.
# Ambiguous-width glyphs (☼ ♡ ᴗ) count as single here; #120 is their fallback.

load helpers

setup() {
  bytek_setup
  export TZ=UTC BYTEK_NOW=1764504000 # Sunday 30 November 2025, 12:00 UTC
  unset COLUMNS
}

# Prints, as U+XXXX, each character of stdin that a terminal shows wider or narrower than one
# column: East Asian wide and fullwidth, emoji, zero-width and combining characters. bash 3.2
# can't read a character's code point, so iconv turns the text into UTF-32 (4 bytes each).
odd_widths() {
  local bytes i cp
  # shellcheck disable=SC2207 # od's output is hex bytes split on spaces, nothing to glob
  bytes=($(iconv -f UTF-8 -t UTF-32BE | od -An -v -tx1))
  for ((i = 0; i + 3 < ${#bytes[@]}; i += 4)); do
    cp=$((16#${bytes[i]}${bytes[i + 1]}${bytes[i + 2]}${bytes[i + 3]}))
    if ((cp >= 0x0300 && cp <= 0x036F)) || ((cp >= 0x1100 && cp <= 0x115F)) ||
      ((cp >= 0x200B && cp <= 0x200F)) || ((cp >= 0x20D0 && cp <= 0x20FF)) ||
      ((cp >= 0x231A && cp <= 0x231B)) || ((cp >= 0x23E9 && cp <= 0x23EC)) || ((cp == 0x23F0 || cp == 0x23F3)) ||
      ((cp >= 0x25FD && cp <= 0x25FE)) || ((cp >= 0x2614 && cp <= 0x2615)) || ((cp >= 0x2648 && cp <= 0x2653)) ||
      ((cp == 0x267F || cp == 0x2693 || cp == 0x26A1 || cp == 0x26CE || cp == 0x26D4 || cp == 0x26EA)) ||
      ((cp >= 0x26AA && cp <= 0x26AB)) || ((cp >= 0x26BD && cp <= 0x26BE)) || ((cp >= 0x26C4 && cp <= 0x26C5)) ||
      ((cp >= 0x26F2 && cp <= 0x26F3)) || ((cp == 0x26F5 || cp == 0x26FA || cp == 0x26FD || cp == 0x2705)) ||
      ((cp >= 0x270A && cp <= 0x270B)) || ((cp == 0x2728 || cp == 0x274C || cp == 0x274E || cp == 0x2757)) ||
      ((cp >= 0x2753 && cp <= 0x2755)) || ((cp >= 0x2795 && cp <= 0x2797)) || ((cp == 0x27B0 || cp == 0x27BF)) ||
      ((cp >= 0x2B1B && cp <= 0x2B1C)) || ((cp == 0x2B50 || cp == 0x2B55)) ||
      ((cp >= 0x2E80 && cp <= 0xA4CF)) || ((cp >= 0xAC00 && cp <= 0xD7A3)) || ((cp >= 0xF900 && cp <= 0xFAFF)) ||
      ((cp >= 0xFE00 && cp <= 0xFE0F)) || ((cp >= 0xFE30 && cp <= 0xFE4F)) || ((cp >= 0xFF00 && cp <= 0xFF60)) ||
      ((cp >= 0xFFE0 && cp <= 0xFFE6)) || ((cp >= 0x1F000 && cp <= 0x1FAFF)) || ((cp >= 0x20000 && cp <= 0x3FFFD)); then
      printf 'U+%04X\n' "$cp"
    fi
  done
}

# Prints the "a|b|c" frames of key $2 in data file $1, one per line.
frames_of() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in "$2: "*) printf '%s\n' "${line#"$2: "}" | tr '|' '\n' ;; esac
  done <"$1"
}

@test "the width check catches wide, emoji and zero-width characters" {
  assert_equal "$(printf 'a漢b' | odd_widths)" "U+6F22"
  assert_equal "$(printf '😀' | odd_widths)" "U+1F600"
  assert_equal "$(printf 'e\314\201' | odd_widths)" "U+0301"
  assert_equal "$(printf '\342\234\250\357\270\217' | odd_widths)" $'U+2728\nU+FE0F'
  assert_equal "$(printf '•ᴗ• ♡ ☼ ╭──┴──╮ (ᵔᴥᵔ) ~\\_/ [≡] ▰▱ ◜' | odd_widths)" ""
}

@test "data files use single-width characters only" {
  local f found problems=""
  for f in "$ROOT"/faces/* "$ROOT"/addons/* "$ROOT"/companions/*; do
    found=$(grep -v '^#' "$f" | odd_widths | tr '\n' ' ')
    [ -z "$found" ] || problems="$problems${f#"$ROOT"/}: $found"$'\n'
  done
  [ -z "$problems" ] || fail "characters that aren't one column wide:"$'\n'"$problems"
}

@test "every face frame is 3 characters, every add-on frame 1" {
  local f frame problems=""
  for f in "$ROOT"/faces/*; do
    while IFS= read -r frame; do
      [ "${#frame}" -eq 3 ] || problems="$problems${f#"$ROOT"/}: '$frame' is ${#frame} characters"$'\n'
    done < <(frames_of "$f" frames)
  done
  for f in "$ROOT"/companions/*; do
    while IFS= read -r frame; do
      [ "${#frame}" -eq 3 ] || problems="$problems${f#"$ROOT"/} due_face: '$frame' is ${#frame} characters"$'\n'
    done < <(frames_of "$f" due_face)
  done
  for f in "$ROOT"/addons/*; do
    while IFS= read -r frame; do
      [ "${#frame}" -eq 1 ] || problems="$problems${f#"$ROOT"/}: '$frame' is ${#frame} characters"$'\n'
    done < <(frames_of "$f" frames)
  done
  [ -z "$problems" ] || fail "$problems"
}

@test "every look keeps the box in its columns" {
  local look="" n=0 line row=0 problems=""
  run "$BYTEK" preview
  assert_success
  while IFS= read -r line; do
    case "$line" in
      "") row=0 && continue ;;
      state:* | add-on:* | routine:*) look=$line row=0 n=$((n + 1)) && continue ;;
    esac
    row=$((row + 1))
    case $row in
      1) [ "${line:0:4}" = "    " ] && [ "${line:4:1}" != " " ] || problems="$problems$look: the antenna isn't in column 5: '$line'"$'\n' ;;
      2) [ "$line" = " ╭──┴──╮" ] || problems="$problems$look: the top isn't ' ╭──┴──╮': '$line'"$'\n' ;;
      3) [ "${line:0:3}" = " │ " ] && [ "${line:6:2}" = " │" ] || problems="$problems$look: the face row is off: '$line'"$'\n' ;;
      4) [ "${line:0:8}" = " ╰─┬─┬─╯" ] || problems="$problems$look: the bottom isn't ' ╰─┬─┬─╯': '$line'"$'\n' ;;
      *) problems="$problems$look: more than 4 rows"$'\n' ;;
    esac
  done <<<"$output"
  [ "$n" -gt 20 ] || fail "only $n looks in the preview"
  [ -z "$problems" ] || fail "$problems"
}
