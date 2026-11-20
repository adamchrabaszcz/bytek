# 0007. No lock on state files: edits are appended to a list

- Status: Accepted
- Date: 2026-11-20

## Context
Claude Code runs hooks at the same moment when it runs several tools or subagents at once. Each hook read the state file, changed it and wrote it back, so hooks running together overwrote each other: with 30 edits at once, 4 were counted.

A lock around the read-change-write (#46) helped but kept failing in new ways. Plain bash has no lock that is both portable and reliable:
- `flock` and `fcntl` locks are released by the system when a process dies, but macOS has no `flock` command, and using them from bash needs Perl or Python on every hook.
- `mkdir` (or `noclobber`) is atomic everywhere, Git Bash included, but a lock left by a crash has to be detected with heuristics (a timestamp or a PID written into the lock), and each of those opened a race in which two hooks both held the lock (28 of 30 counted in CI).

Looking at what actually goes wrong: what Bytek is doing now (editing, reading, waiting) is fine as "the last hook wins", since the newest event is the one to show. Only the turn's totals, the edit count and the edited files, have to add up.

## Decision
There is no lock. The state file holds only what Bytek is doing now and is written whole and atomically (temp file and rename), so the last writer wins. Each file edit is appended as one line to a list next to it, `state/<session>.edits`; appending a short line is atomic, so no edit is lost. The edit count and the number of files are read from the list; a new prompt clears it and the session's end removes it.

## Consequences
- No waiting, timeouts or stale-lock cleanup: a hook can never hang or block a tool call, and it works the same on macOS, Linux and Git Bash.
- The end-of-turn "N changes" is always exact; "editing N files" counts the list as the hook finds it, so with edits arriving at the same moment it can trail by one until the next edit.
- After two tools at once, the face shows the last hook's state.
- A totals field that must add up gets its own append-only list, never a read-change-write in the state file.
- Older state files with `edits` and `files` keys still load: unknown keys are ignored.
