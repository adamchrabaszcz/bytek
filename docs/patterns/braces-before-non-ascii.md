# Braces before non-ASCII text

## Use when
A variable is followed directly by a character outside ASCII: box drawing, progress cells, symbols like `▰`, `…`, `·`.

## Pattern
Put the variable's name in braces:

```bash
bar="${bar}▰"
REPLY="${text}…"
```

Used by the progress bar (`render_bar` in `lib/render.sh`). Text with a space or ASCII punctuation after the name (`"$n changes · $time"`) needs no braces.

## Anti-pattern
The bare name:

```bash
bar="$bar▰"
```

macOS's own bash 3.2, in a UTF-8 locale, doesn't see where the name ends and reads the first bytes of the character as part of it: the result is broken bytes instead of `▰`. bash 5 and the C locale read it correctly, so it looks fine on Linux and in a quick test, and breaks on the platform Bytek is made for. The progress bar showed broken characters on macOS this way (#75). `tests/hygiene.bats` fails on any such name in `bin/` and `lib/`.
