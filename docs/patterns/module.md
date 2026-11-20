# A module

## Use when
Adding engine code: a new job (a provider, outfits, routines) gets a new `lib/<name>.sh`; code for an existing job goes into its module.

## Pattern
A module is a file of functions and constants, loaded with `.` by `bin/bytek`:

```bash
# shellcheck shell=bash
# clock: the current time and durations. Every reading of the clock goes through here, ...
# Needs: nothing.

# Sets REPLY to the current time in seconds since 1970, or BYTEK_NOW when it is set.
clock_now() {
  REPLY=${BYTEK_NOW:-$(date +%s)}
}
```

- The header says what the module is for and what it needs: other modules, and what `bin/bytek` provides (`BYTEK_ROOT`, `BYTEK_HOME`, `die`).
- Every function starts with the module's name and an underscore (`clock_now`), every constant with its name in capitals (`RENDER_SPINNER`).
- `bin/bytek` loads it, with a `# shellcheck source=lib/<name>.sh` line, only for the commands that use it.
- Its unit tests are `tests/unit/<name>.bats`, which load it with `load_module <name>`.

Every module in `lib/` follows it; `tests/modules.bats` checks the names, that loading prints nothing and changes no shell options, and that `bin/bytek` loads it.

## Anti-pattern
Code that runs when the file is loaded, or names without the module's prefix:

```bash
now=$(date +%s)   # runs on load, for every command, even those that never need it
set -o nounset    # changes the options of bin/bytek and every other module
load_state() {    # whose? clashes with the next "load_state" any module defines
```

Bash has one namespace for all functions and variables, and a loaded file runs in its caller's shell: an unprefixed name can silently replace another module's, and anything run on load slows every command, the status line included.
