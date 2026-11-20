# 0010. Bytek edits settings.json itself, including one permission

- Status: Accepted
- Date: 2026-11-20
- Supersedes: 0005

## Context
`0005` decided that `bytek setup` edits `settings.json` itself, since a plugin can't set the status line, and that it touches only `statusLine` and Bytek's own hooks.

Claude now sets the mood antenna as the work changes, by running `bytek addon <name>` (#101). Each run is a Bash command, and without auto mode Claude Code asks for permission every time, many times a session. A plugin can't add permission rules either; only `settings.json` can.

## Decision
Everything in `0005` stands: setup backs the file up first, remembers the status line it replaces, edits through a jq program and a checked temp file, keeps a symlink a symlink, and refuses a file that isn't a JSON object. What setup touches is now:

- `statusLine`;
- Bytek's own hooks, with `--hooks` (installs without the plugin);
- one permission rule in `permissions.allow`: `Bash(~/.claude/bytek/current/bin/bytek addon *)`, added once next to the user's rules.

Claude Code splits compound commands and checks each part, so the rule allows `bytek addon <name>` and nothing joined to it, and its `*` comes after the subcommand, so it can't let other options in. `bytek uninstall` removes exactly that rule, and an `allow` list or `permissions` object left empty by it.

## Consequences
- Claude can change the antenna as often as the work changes, without prompts.
- Bytek now adds a permission to people's settings: it has to stay this narrow, and any other rule needs a new record.
- An `allow` list that was already empty before setup is removed on uninstall, and so is the rule itself if the user had added exactly the same one; nothing else of the user's changes.
- A `permissions` object or `allow` list that isn't the usual shape is left alone: no rule is added, and the status line is still set.
