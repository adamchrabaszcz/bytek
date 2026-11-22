# 0011. An ASCII charset from `_ascii` lines in the data files, switched in config/bytek

- Status: Accepted
- Date: 2026-11-22

## Context
Bytek's art uses glyphs such as `♡ ᴗ • ╭─╮`, and many of them are East Asian "ambiguous" width: one column in most terminals, two where "ambiguous characters are wide" is on (common with East Asian settings). Then the box breaks, and no choice of Unicode glyphs avoids it, because the box drawing set itself is ambiguous. People with such terminals need Bytek drawn in plain ASCII, switched on once and kept. The options considered:

- **A second set of folders** (`faces-ascii/`, `addons-ascii/`): every art file twice, and the two copies drift apart (a new face without its ASCII twin, a changed status text in one copy only).
- **An automatic character map** in the render (`ᴗ` to `_`, `♡` to `v`): no work for art authors, but a map can't make faces look right (`•ᴗ•` and `◕ᴗ◕` need different answers) and grows with every new glyph.
- **`<key>_ascii` lines next to the plain ones**, in the same file: the art author picks the ASCII look where the art is made, and a test can see what's missing.

For the switch: an environment variable is hard to set for a status line Claude Code starts; a file in `$BYTEK_HOME/config/` is how routines and companion names already work, and a command can write it.

## Decision
A data file gives a key whose value isn't plain ASCII a second line, the key with `_ascii` added (`frames_ascii: o_o|-_-`). In the ascii charset it wins over the plain line, before or after it; in unicode it is skipped; a key without one shows its plain value. The render keeps its own glyphs (box, spinner, bar, cut mark) as constants and swaps them for an ASCII set. `bytek charset [unicode|ascii]` writes `charset = ascii` to `$BYTEK_HOME/config/bytek`, a `key = value` file for Bytek's own settings, read on every render. Like the other files people write, it has no version line.

## Consequences
- Every new or changed art file needs `_ascii` lines for its non-ASCII values, with the same lengths; `tests/alignment.bats` fails without them, so outfits, weather and skins follow the same rule.
- Older Bytek versions skip the `_ascii` keys (readers ignore unknown keys), so the face, add-on and companion formats stay at 1 (`0008`).
- Text Bytek doesn't write (file names, a companion's name) isn't changed in ascii: only its own marks are. The ASCII look is plain, but straight in any terminal.
- Later settings go into `config/bytek` too, one key each, documented in `docs/architecture/data-files.md`.
