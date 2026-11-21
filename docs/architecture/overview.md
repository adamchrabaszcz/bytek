# Overview

Bytek is a bash program (`bin/bytek`) that Claude Code calls in two ways: every second to draw the status line, and on its hook events to say what the agent is doing. The two never talk to each other directly: hooks write a small state file per session, and the status line reads it.

```
Claude Code ──hook JSON──▶ bytek hook ──▶ state file ($BYTEK_HOME/state/<session>)
                                                 │
Claude Code ◀──4 lines── bytek render ◀──────────┘  + face file (faces/<state>)
```

Why it is bash and how its parts are cut: `docs/adr/` (`0002` modules, `0003` bash, `0004` bash 3.2, `0010` editing settings.json, `0006` jq).

## Modules

`bin/bytek` sets up paths, picks the locale and dispatches; the engine lives in `lib/*.sh`, one job per module (shape: `docs/patterns/module.md`).

| Module | Job | Needs |
| --- | --- | --- |
| `lib/locale.sh` | picks a UTF-8 locale so text is counted in characters | nothing |
| `lib/clock.sh` | the current time, file name stamps, durations: every `date` goes through it | nothing |
| `lib/state.sh` | reads, writes and switches a session's state file; its edit list | nothing |
| `lib/routines.sh` | the user's routines: reads `config/routines`, works out when each happens next; `bytek done` and `skip` | clock |
| `lib/addon.sh` | the mood antenna: the current add-on and `bytek addon` | nothing |
| `lib/companions.sh` | the names given to companions: reads `config/companions`, and `bytek name` | nothing |
| `lib/away.sh` | how long the Mac has had no input (ioreg), for routines with `clear idle`; `bytek away` | nothing |
| `lib/render.sh` | draws the status line: frames, face files, progress bar, cutting text, routine reminders | clock, state, addon, routines, companions, away |
| `lib/hooks.sh` | turns hook events into states; the antenna reminder; the debug log; following plugin updates | clock, state, addon |
| `lib/settings.sh` | `setup` and `uninstall`: edits `settings.json` | clock |
| `lib/preview.sh` | `bytek preview`: every state, add-on and routine stage, rendered into a temp home of its own | clock, state, addon, routines, companions, render |
| `lib/doctor.sh` | `bytek doctor`: checks an installation, says what to fix; never prints `settings.json` | settings, routines, companions, away |

The jq programs in `lib/*.jq` belong to the module that runs them: `hook-fields.jq` and `debug-log.jq` to hooks, `setup.jq`, `uninstall.jq`, `original-statusline.jq` and `saved-statusline.jq` to settings.

## What each command loads

| Command | Modules | jq |
| --- | --- | --- |
| `bytek render` | locale, clock, state, addon, routines, render | never |
| `bytek addon` | locale, addon | no |
| `bytek hook` | locale, clock, state, addon, hooks | if installed |
| `bytek set` | locale, clock, state | no |
| `bytek preview` | locale, clock, state, addon, routines, companions, away, render, preview | never |
| `bytek setup`, `uninstall` | locale, clock, settings | required |
| `bytek doctor` | locale, clock, settings, routines, doctor | if installed |
| `bytek states`, `locale`, `help` | locale | no |

## Layers

From the bottom up; a module uses only modules below it:

1. **locale, clock**: the environment (locale, time).
2. **state, addon, routines**: shared data: the state file, the mood antenna Claude picks, the user's routines.
3. **render, hooks, settings**: the jobs; none of them uses another.
4. **doctor, preview**: doctor checks an installation, using settings to recognise Bytek in `settings.json`; preview draws every look through render.
5. **bin/bytek**: paths, `die`, the small commands (`set`, `states`, `locale`), dispatch.

Data sits beside the code, read by the modules: `faces/` (one file per state), `addons/` (the mood antenna), `companions/` (next to Bytek for a routine), `hooks/hooks.json` (the hooks the plugin and `setup --hooks` install). The file formats are in `data-files.md`; who owns what in `bounded-contexts.md`.

## The render budget

The status line redraws every second, so a render must take well under **50 ms** on average (about 25 to 30 ms on a Mac). Starting a program is what makes bash slow, so `tests/speed.bats` counts them: a render may start `dirname`, `cat` and `date`, once each, and fails, naming it, on anything more. It also measures the time through the real `bin/bytek`: on CI as a note only, because shared runners vary too much (29 to 54 ms on macOS for the same code), and as a failing check on your machine. That is why the render path:

- reads only local files: no network, no jq;
- avoids subprocesses: functions return through `REPLY` instead of `$( )` (`docs/patterns/reply-return-value.md`);
- loads only the modules it needs;
- gets anything slow (weather, music, git) from a cache file a provider wrote in the background (`bounded-contexts.md`, "Providers").

If a render fails, `bytek render` prints a plain `[•ᴗ•] bytek`, so the status line is never empty.
