# 0006. JSON through jq, with programs in lib/*.jq

- Status: Accepted
- Date: 2026-11-20 (recording a decision from the start of the project)

## Context
Bytek reads JSON on every hook (the event, tool, file, command) and edits JSON in setup and uninstall. Bash has no JSON parser. Parsing it with patterns breaks on escaping and nesting, and is a security risk for text that ends up on the terminal. jq is small, widely available and made for this, but each call is a subprocess.

The jq programs Bytek needs are several lines long. Written inline as multi-line strings in bash they are hard to read, fight with bash's quoting, and line coverage counts only their first line.

## Decision
JSON is read and edited with jq, everywhere except the render path (which reads only Bytek's own plain-text files, so it needs no jq and stays fast). A jq program longer than one line lives in its own file in `lib/` (`hook-fields.jq`, `setup.jq`, `debug-log.jq`...) and runs with `jq -f`.

## Consequences
- jq is a dependency for hooks, setup and uninstall (README, "Install"). Without it hooks fall back to reading the event name, session and tool with patterns, and setup refuses to run.
- The programs are plain files: readable, testable with sample JSON, and where the control-character filter for outside text lives (`lib/hook-fields.jq`).
- Every hook costs one jq call, fine for hooks; the render path must never add one.
