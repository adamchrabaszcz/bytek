# 0004. Compatible with bash 3.2

- Status: Accepted
- Date: 2026-11-20 (recording a decision from the start of the project)

## Context
macOS ships bash 3.2 as `/bin/bash` and won't update it (newer versions are GPLv3). A newer bash comes only from Homebrew or similar, and many people don't have it. Bytek's scripts start with `#!/usr/bin/env bash`, so they run under whichever bash comes first on `PATH`; on a plain Mac that is 3.2. Linux has bash 5.

## Decision
Everything Bytek runs (`bin/`, `lib/`, `install.sh`, `uninstall.sh`, the tools and tests) works on bash 3.2. CI runs the tests on macOS with its own `/bin/bash`, next to Linux with bash 5.

## Consequences
- No associative arrays, `mapfile`, `${var,,}`, `wait -n`, `case` inside `$( )`, `printf '%(...)T'` or `$EPOCHSECONDS`; the workarounds are in `docs/patterns/` (for example, braces before non-ASCII text, which 3.2 misreads in a UTF-8 locale).
- Some code is longer than bash 5 would need, such as counting running jobs instead of `wait -n` in `tests/run.sh`.
- Bugs that only 3.2 has can hide on Linux and in a quick test on a newer bash: the macOS CI job and running the tests with `/bin/bash` locally catch them.
- Supersede this record if macOS ever ships a newer bash, or if Bytek requires one.
