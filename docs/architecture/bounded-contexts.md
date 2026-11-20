# Bounded contexts

Each part of Bytek owns its data and talks to the others only through a file with a fixed format (`data-files.md`). That keeps the hooks, which run on every tool call, and the status line, which runs every second, independent: either can fail without breaking the other.

## State

**Owns:** the state files, `$BYTEK_HOME/state/<session>`, and what a state is (`S_<key>` fields).
**Code:** `lib/state.sh`.
**Contract:** the state file format. Writers go through `state_write` (atomic, control characters removed); readers through `state_load` (a missing file is idle, unknown keys are ignored). Nothing else reads or writes state files.

## Hooks

**Owns:** turning Claude Code's events into states; the debug log (`hooks.log`, off unless `$BYTEK_HOME/debug` exists); keeping `$BYTEK_HOME/current` pointed at the newest plugin copy.
**Code:** `lib/hooks.sh`, `lib/hook-fields.jq`, `lib/debug-log.jq`, `hooks/hooks.json`.
**In:** hook JSON on stdin, from Claude Code; untrusted, so every field goes through the control-character filter in `hook-fields.jq`.
**Out:** a state file per session. Never stdout (some hooks' output reaches Claude's context), and always exit 0 (a failing hook must not block a tool call).

## Render

**Owns:** what the status line shows: the four lines, the face for each state, animation by tick, cutting text to the terminal's width, falling asleep after inactivity.
**Code:** `lib/render.sh`, `faces/`.
**In:** status line JSON on stdin (only `session_id` is used), the session's state file (or `default`), the face file for its state.
**Out:** four lines on stdout. Reads only local files, no jq, within the 50 ms budget (`overview.md`).

## Settings

**Owns:** Bytek's place in `~/.claude/settings.json` (`statusLine`, and Bytek's hooks for installs without the plugin), the backups, and the status line Bytek replaced.
**Code:** `lib/settings.sh`, `lib/setup.jq`, `lib/uninstall.jq`, `lib/original-statusline.jq`.
**Contract:** touches nothing in `settings.json` but its own entries; backs the file up first; never prints it (it can hold secrets). Why Bytek edits the file at all: `docs/adr/0005-bytek-edits-settings-json.md`.

## Providers (planned)

**Will own:** anything slow or outside Bytek that the status line shows: weather, music, git, the user's routines.
**Contract:** a provider runs in the background, never on the render path, and leaves a cache file under `$BYTEK_HOME/cache/`; the render path only reads that file and shows nothing when it is missing or old. Cache contents are untrusted and go through the same control-character filter as hook fields. Personal settings (places, times) come from `$BYTEK_HOME/config/`, never from the repository.

No provider exists yet; the first one defines the cache file format in `data-files.md` and gets its own module.

## Who may use what

| | state files | face files | settings.json | cache files |
| --- | --- | --- | --- | --- |
| hooks | write | | | |
| render | read | read | | read |
| settings | | | write (backup first) | |
| providers | | | | write |
| `bytek set` | write | checks the state exists | | |
