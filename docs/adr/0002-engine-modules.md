# 0002. The engine is split into modules

- Status: Accepted
- Date: 2026-11-20

## Context
`bin/bytek` held everything in one 490-line file: the status line, hooks, state files, editing `settings.json`, the locale. The planned features (antenna, outfits, routines, companions, providers) would each add to it, and nothing could be tested on its own: every test went through the whole script.

Bash has no modules, no namespaces and no imports. The options were one file; several scripts that call each other (a process per call, too slow for a render every second); or files loaded with `.` into one shell, sharing its functions and variables.

## Decision
The engine is split into files loaded with `.` into `bin/bytek`, one job each (`lib/locale.sh`, `clock.sh`, `state.sh`, `render.sh`, `hooks.sh`, `settings.sh`). `bin/bytek` sets up paths and dispatches, and loads only the modules a command needs: the render path never loads hooks or settings.

A module defines functions and constants only: loading it runs nothing and sets no shell options (it shares its caller's). Since bash has no namespaces, every name starts with the module's: `state_load`, `RENDER_SPINNER`. A module's header names the modules it needs, and `bin/bytek` loads them in that order. Outside dependencies (the clock, later `osascript`, `shortcuts`, `ioreg`) go through one module each, so tests can replace them.

## Consequences
- A feature lands in its module, or in a new one, instead of in one growing file.
- Unit tests load a module and call its functions directly (`tests/unit/`); the integration tests still go through `bin/bytek`.
- Loading costs a few file reads per render: measured, no visible change within the 50 ms budget.
- Modules share variables (`S_<key>` from `state`, `BYTEK_UTF8` from `locale`). ShellCheck checks each file on its own, so a module that writes or reads another's variables says so with a file-level exception and its reason.
- `tests/modules.bats` keeps the rules: names, nothing run on load, every module loaded, the render path kept small.
