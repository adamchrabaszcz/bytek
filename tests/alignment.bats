#!/usr/bin/env bats
# The art stays straight: every data file uses single-width characters only, faces are 3
# characters and add-ons 1, and every look in `bytek preview` keeps the box in its columns, in
# the unicode and the ascii charset (every non-ASCII value has its "_ascii" line).
# Ambiguous-width glyphs (☼ ♡ ᴗ) count as single here; the ascii charset is their fallback.

load helpers

setup() {
  bytek_setup
  export TZ=UTC BYTEK_NOW=1764504000 # Sunday 30 November 2025, 12:00 UTC
  unset COLUMNS
}

# Prints, as U+XXXX, each character of stdin that a terminal shows wider or narrower than one
# column: East Asian wide and fullwidth, emoji, zero-width and combining characters. bash 3.2
# can't read a character's code point, so iconv turns the text into UTF-32 (4 bytes each).
# Text that isn't UTF-8 prints "not UTF-8".
odd_widths() {
  local bytes i cp u32="$BATS_TEST_TMPDIR/utf32"
  iconv -f UTF-8 -t UTF-32BE >"$u32" 2>/dev/null || {
    echo "not UTF-8"
    return
  }
  # shellcheck disable=SC2207 # od's output is hex bytes split on spaces, nothing to glob
  bytes=($(od -An -v -tx1 <"$u32"))
  for ((i = 0; i + 3 < ${#bytes[@]}; i += 4)); do
    cp=$((16#${bytes[i]}${bytes[i + 1]}${bytes[i + 2]}${bytes[i + 3]}))
    if ((cp >= 0x0300 && cp <= 0x036F)) || ((cp >= 0x1100 && cp <= 0x115F)) ||
      ((cp >= 0x200B && cp <= 0x200F)) || ((cp >= 0x2060 && cp <= 0x2064)) || ((cp == 0xFEFF)) ||
      ((cp >= 0x20D0 && cp <= 0x20FF)) ||
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
  assert_equal "$(printf 'a\342\201\240b\357\273\277' | odd_widths)" $'U+2060\nU+FEFF'
  assert_equal "$(printf 'a\377b' | odd_widths)" "not UTF-8"
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

# Prints a problem for each frame of key $2 in the data files $3... that isn't $1 characters.
frame_lengths() {
  local want=$1 key=$2 f frame
  shift 2
  for f in "$@"; do
    while IFS= read -r frame; do
      [ "${#frame}" -eq "$want" ] || printf "%s %s: '%s' is %s characters\n" "${f#"$ROOT"/}" "$key" "$frame" "${#frame}"
    done < <(frames_of "$f" "$key")
  done
}

@test "every face frame is 3 characters, every add-on frame 1, in both charsets" {
  local problems
  problems=$(
    frame_lengths 3 frames "$ROOT"/faces/*
    frame_lengths 3 frames_ascii "$ROOT"/faces/*
    frame_lengths 3 due_face "$ROOT"/companions/*
    frame_lengths 3 due_face_ascii "$ROOT"/companions/*
    frame_lengths 1 frames "$ROOT"/addons/*
    frame_lengths 1 frames_ascii "$ROOT"/addons/*
  )
  [ -z "$problems" ] || fail "$problems"
}

@test "every non-ASCII value has an _ascii line, and _ascii values are plain ASCII" {
  local f content line key val problems=""
  for f in "$ROOT"/faces/* "$ROOT"/addons/* "$ROOT"/companions/*; do
    content=$'\n'$(cat "$f")
    while IFS= read -r line; do
      case "$line" in '' | '#'*) continue ;; esac
      key=${line%%:*} val=${line#*: }
      if [[ "$key" == *_ascii ]]; then
        LC_ALL=C grep -q '[^ -~]' <<<"$val" && problems="$problems${f#"$ROOT"/} $key: not plain ASCII: '$val'"$'\n'
      elif LC_ALL=C grep -q '[^ -~]' <<<"$val" && [[ "$content" != *$'\n'"${key}_ascii: "* ]]; then
        problems="$problems${f#"$ROOT"/} $key: '$val' has no ${key}_ascii line"$'\n'
      fi
    done <<<"$content"
  done
  [ -z "$problems" ] || fail "$problems"
}

# Checks that every look in preview output $1 has the box's top row $2, sides $3 and bottom
# row $4 in their columns, with the antenna in column 5.
check_boxes() {
  local top=$2 side=$3 bottom=$4 look="" n=0 line row=0 problems=""
  while IFS= read -r line; do
    case "$line" in
      "") row=0 && continue ;;
      state:* | add-on:* | routine:*) look=$line row=0 n=$((n + 1)) && continue ;;
    esac
    row=$((row + 1))
    case $row in
      1) [ "${line:0:4}" = "    " ] && [ "${line:4:1}" != " " ] || problems="$problems$look: the antenna isn't in column 5: '$line'"$'\n' ;;
      2) [ "$line" = "$top" ] || problems="$problems$look: the top isn't '$top': '$line'"$'\n' ;;
      3) [ "${line:0:3}" = " $side " ] && [ "${line:6:2}" = " $side" ] || problems="$problems$look: the face row is off: '$line'"$'\n' ;;
      4) [ "${line:0:8}" = "$bottom" ] || problems="$problems$look: the bottom isn't '$bottom': '$line'"$'\n' ;;
      *) problems="$problems$look: more than 4 rows"$'\n' ;;
    esac
  done <<<"$1"
  [ "$n" -gt 20 ] || fail "only $n looks in the preview"
  [ -z "$problems" ] || fail "$problems"
}

@test "every look keeps the box in its columns" {
  local out
  out=$("$BYTEK" preview) || fail "bytek preview failed"
  check_boxes "$out" " ╭──┴──╮" "│" " ╰─┬─┬─╯"
}

@test "every look keeps the box in its columns in ascii, and is plain ASCII" {
  local out
  out=$("$BYTEK" preview --charset ascii) || fail "bytek preview --charset ascii failed"
  check_boxes "$out" " .--+--." "|" " '-+-+-'"
  LC_ALL=C grep -n '[^ -~]' <<<"$out" && fail "non-ASCII characters in the ascii preview"
  return 0
}
