# Bytek

[![test](https://github.com/adamchrabaszcz/bytek/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/adamchrabaszcz/bytek/actions/workflows/test.yml) [![codecov](https://codecov.io/gh/adamchrabaszcz/bytek/graph/badge.svg)](https://codecov.io/gh/adamchrabaszcz/bytek)

```
    ♡
 ╭──┴──╮
 │ •ᴗ• │  editing 3 files
 ╰─┬─┬─╯  ◜ api.ts
```

A small ASCII companion for the [Claude Code](https://claude.com/claude-code) status line.
Bytek shows what the agent is doing (reading, thinking, editing, testing, waiting for you),
wears outfits for the weather and time of day, and can nudge you about your own routines.

## The name

**Bytek** (pronounced "BYE-tek") is *byte* plus the Polish diminutive *-ek*: a little byte.
In Polish, *bytek* also means "a little being".

## Install

Needs bash (the macOS default 3.2 is fine) and [jq](https://jqlang.org) for setup and hooks.

**As a Claude Code plugin** (recommended):

```
/plugin marketplace add adamchrabaszcz/bytek
/plugin install bytek@bytek
/bytek setup
```

`/bytek setup` makes Bytek your status line: it backs up `~/.claude/settings.json` to `~/.claude/bytek/backup/`, remembers any status line you had, and sets a one-second refresh so Bytek can animate. The plugin brings its own hooks, so Bytek follows what Claude is doing from the next prompt.

**Without the plugin system:**

```sh
git clone https://github.com/adamchrabaszcz/bytek && cd bytek
./install.sh
```

This copies Bytek to `~/.claude/bytek/app` and adds the status line and hooks to your settings (backed up first).

## Uninstall

- Plugin: `/bytek uninstall`, then `/plugin uninstall bytek@bytek`.
- Manual install: `./uninstall.sh` (add `--purge` to also delete `~/.claude/bytek` with your config and state).

Both put back the status line you had before (or none) and remove only Bytek's hooks; anything else in your settings stays as it is.

## Debugging

`touch ~/.claude/bytek/debug` makes the hooks log each event to `~/.claude/bytek/hooks.log`; `rm ~/.claude/bytek/debug` stops it. The log keeps the event's shape and metadata (event, tool, file path, command) but never your prompts, file contents or edit text, and tool output only as its key names. It is readable by you only and is cut back to half when it passes 1 MB (`BYTEK_DEBUG_LOG_MAX` in bytes changes the limit). Still: check it before attaching it to an issue.

## Security

See [SECURITY.md](SECURITY.md) for how to report a vulnerability.

## Status

Early work in progress. The roadmap is tracked in the issues.

## Contributing

New faces, outfits, companions and routines are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
