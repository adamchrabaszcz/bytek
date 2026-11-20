# 0005. Bytek edits settings.json itself

- Status: Accepted
- Date: 2026-11-20 (recording a decision from the start of the project)

## Context
Claude Code reads its status line from `statusLine` in `~/.claude/settings.json`. A plugin can bring hooks and commands, but not the status line: from a plugin's own settings only `agent` and `subagentStatusLine` take effect. So something has to put Bytek into the user's `settings.json`.

The options: tell people to edit the JSON by hand (easy to break, and they'd have to keep their old status line somewhere), or let Bytek make the edit.

## Decision
`bytek setup` (or `/bytek setup` from the plugin) edits `settings.json`, and `bytek uninstall` takes Bytek out again. Every edit:
- backs the file up first, into `~/.claude/bytek/backup/`;
- remembers the status line Bytek replaces, once, and puts it back on uninstall;
- touches only `statusLine` (and Bytek's own hooks with `--hooks`, for installs without the plugin);
- runs a jq program from `lib/`, writes a temp file, checks it is valid JSON and only then replaces the file, keeping a symlinked `settings.json` a symlink;
- refuses to touch a file that isn't a JSON object.

## Consequences
- Installing is two commands, and uninstalling gives back exactly what was there.
- Bytek is responsible for not breaking a file that isn't its own: the steps above and `tests/setup.bats` and `tests/unit/settings.bats` keep it to that.
- `settings.json` can hold secrets, so Bytek's tools and docs never print or log it.
- If Claude Code lets plugins set the status line, this record is superseded and setup gets simpler.
