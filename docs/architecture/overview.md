# Overview

Bytek is a bash program (`bin/bytek`) that Claude Code calls in two ways: every second to draw the status line, and on its hook events to say what the agent is doing. The two never talk to each other directly: hooks write a small state file per session, and the status line reads it.

```
Claude Code ──hook JSON──▶ bytek hook ──▶ state file ($BYTEK_HOME/state/<session>)
                                                 │
Claude Code ◀──4 lines── bytek render ◀──────────┘  + face file (faces/<state>)
```

Why it is bash and how its parts are cut: `docs/adr/` (`0002` modules, `0003` bash, `0004` bash 3.2, `0005` editing settings.json, `0006` jq).

## Modules

`bin/bytek` sets up paths, picks the locale and dispatches; the engine lives in `lib/*.sh`, one job per module (shape: `docs/patterns/module.md`).

| Module | Job | Needs |
| --- | --- | --- |
| `lib/locale.sh` | picks a UTF-8 locale so text is counted in characters | nothing |
| `lib/clock.sh` | the current time, file name stamps, durations: every `date` goes through it | nothing |
| `lib/state.sh` | reads, writes and switches a session's state file | nothing |
| `lib/render.sh` | draws the status line: frames, face files, progress bar, cutting text | clock, state |
| `lib/hooks.sh` | turns hook events into states; the debug log; following plugin updates | clock, state |
| `lib/settings.sh` | `setup` and `uninstall`: edits `settings.json` | clock |

The jq programs in `lib/*.jq` belong to the module that runs them: `hook-fields.jq` and `debug-log.jq` to hooks, `setup.jq`, `uninstall.jq` and `original-statusline.jq` to settings.

## What each command loads

| Command | Modules | jq |
| --- | --- | --- |
| `bytek render` | locale, clock, state, render | never |
| `bytek hook` | locale, clock, state, hooks | if installed |
| `bytek set` | locale, clock, state | no |
| `bytek setup`, `uninstall` | locale, clock, settings | required |
| `bytek states`, `locale`, `help` | locale | no |

## Layers

From the bottom up; a module uses only modules below it:

1. **locale, clock**: the environment (locale, time).
2. **state**: the one piece of shared data, the state file.
3. **render, hooks, settings**: the jobs; none of them uses another.
4. **bin/bytek**: paths, `die`, the small commands (`set`, `states`, `locale`), dispatch.

Data sits beside the code, read by the modules: `faces/` (one file per state), `hooks/hooks.json` (the hooks the plugin and `setup --hooks` install). The file formats are in `data-files.md`; who owns what in `bounded-contexts.md`.

## The render budget

The status line redraws every second, so a render must take well under **50 ms** on average; `tests/speed.bats` measures it through the real `bin/bytek` on macOS's bash 3.2 and Linux and fails above it (a render takes about 20 to 25 ms). That is why the render path:

- reads only local files: no network, no jq;
- avoids subprocesses: functions return through `REPLY` instead of `$( )` (`docs/patterns/reply-return-value.md`);
- loads only the modules it needs;
- gets anything slow (weather, music, git) from a cache file a provider wrote in the background (`bounded-contexts.md`, "Providers").

If a render fails, `bytek render` prints a plain `[•ᴗ•] bytek`, so the status line is never empty.
