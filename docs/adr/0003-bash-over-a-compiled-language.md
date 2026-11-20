# 0003. Bash, not a compiled language

- Status: Accepted
- Date: 2026-11-20 (recording a decision from the start of the project)

## Context
Claude Code runs the status line command every second and a hook command on every tool call. Whatever Bytek is written in starts from nothing that often, so its start-up time is most of its cost. It is installed as a Claude Code plugin straight from its git repository, on macOS first and Linux too, and most contributions are meant to be small data files (a face, an outfit), not code.

The options:
- **A compiled language (Go, Rust):** fast, typed, good tooling. But a plugin installs from source, so it would need prebuilt binaries per platform and CPU (or a build step on install), signed and notarized for macOS.
- **An interpreted runtime (Python, Node):** pleasant to write, but tens of milliseconds to start, and it depends on which interpreter version each machine happens to have.
- **bash:** on every Mac and Linux machine already, starts in a few milliseconds, no build, readable for people who only want to change a face.

## Decision
Bytek is written in bash, with jq for reading and editing JSON outside the render path (`0006`). Data (faces, outfits, routines) lives in plain files the bash engine reads.

## Consequences
- No build and no binaries: installing from git just works, on any CPU.
- A render stays far inside its 50 ms budget (`tests/speed.bats`), as long as the render path avoids subprocesses (`docs/patterns/reply-return-value.md`).
- Bash's limits are ours: no data structures beyond arrays, quoting pitfalls, and on macOS bash 3.2 (`0004`). The module layout (`0002`), ShellCheck, shfmt and the patterns in `docs/patterns/` keep it manageable.
- Testing uses bats; line coverage of bash is slow (bashcov traces every line), so it runs after a merge instead of on every pull request.
- If the engine outgrows what bash handles well, this record is superseded, not quietly ignored.
