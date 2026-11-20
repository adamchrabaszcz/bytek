# Data files

Every file Bytek reads or writes, field by field. `$BYTEK_HOME` is `~/.claude/bytek` unless set.

## Format versions

Files that outlive a Bytek version carry a format version, so a newer Bytek can recognise an older file and an older Bytek doesn't misread a newer one (`docs/adr/0008-versioned-file-formats.md`):

| File | Current format | Without a version | Newer than this Bytek knows |
| --- | --- | --- | --- |
| state file | `format=1`, its first line | format 1 | loads as idle; hooks leave the file alone |
| face file | `format: 1`, optional | format 1 | the idle face is shown instead |
| add-on file | `format: 1`, optional | format 1 | the plain heart is shown instead |
| saved status line | `{"format": 1, "statusLine": ...}` | the status line itself (saved before formats existed) | uninstall puts nothing back and keeps the file |

Changing a format means a new version number, and reading the older one (a migration) for as long as such files can still exist. Removing a field, or giving one a new meaning, is a breaking change: a `!` in its commit type and a `BREAKING CHANGE:` footer (CONTRIBUTING, "Commits"). Adding a field older versions can ignore needs neither.

## State file: `$BYTEK_HOME/state/<session>`

One per Claude Code session (`<session>` is the session id: letters, digits, `_`, `-`); `default` is used when a session has none yet. Written by hooks and `bytek set`, read by the status line. Plain text, one `key=value` per line: first `format=1`, then in this order:

| Key | Meaning | Example |
| --- | --- | --- |
| `state` | the face to show; a file name in `faces/` | `editing` |
| `arg` | fills `{arg}` in the face's detail | `src/api.ts` |
| `status` | replaces the face's status text when set | `editing 3 files` |
| `detail` | replaces the face's detail text when set | `$ npm run build` |
| `progress` | `N/M` for `{progress}`; empty shows a sweeping cell | `3/5` |
| `since` | when the state last changed, seconds since 1970 | `1763635200` |
| `turn_start` | when the prompt was sent, for the turn's duration | `1763635100` |

Values are one line: line breaks and tabs become spaces and control characters are removed when the file is written. Unknown keys are ignored when it is read (older versions also kept `edits` and `files` here), and a missing file reads as `idle`. Files untouched for 7 days are removed at the next session start; a session's file is removed when it ends.

The file is written whole (temp file and rename) and never locked: when hooks run at the same moment, the last one's state wins (`docs/adr/0007-no-lock-append-edits.md`).

An `idle` or `done` state older than `BYTEK_SLEEP_AFTER` seconds (default 600) is shown as `sleeping`.

## Edit list: `$BYTEK_HOME/state/<session>.edits`

The files edited in the current turn, one path per line, one line per edit (a file edited twice is there twice), with control characters removed. Hooks append to it, which is atomic, so edits from hooks running at the same moment all count; the edit count is its number of lines, the number of files its different lines. A new prompt or session start clears it, the session's end removes it.

```
src/api.ts
src/app.ts
src/api.ts
```

It has no version line, which would break the atomic one-line appends; it lives for one turn only. If its format ever changes, it gets a new file name instead.

## Face file: `faces/<state>`

One per state, in the repository; the file name is the state's name (`bytek states` lists them). Plain text, `key: value` lines; lines starting with `#` are comments.

| Key | Meaning | Example |
| --- | --- | --- |
| `format` | the file's format version; optional, missing means 1 | `1` |
| `frames` | the 3-character face, one per animation step, `\|`-separated | `≧ᴗ≦\|≦ᴗ≧` |
| `thought` | what floats next to the antenna, `\|`-separated steps; optional | `✎` |
| `status` | the main text, right of the face | `editing` |
| `detail` | the dimmed line below it | `{spin} {arg}` |

In `detail`: `{arg}` is the state's `arg`, `{spin}` a spinner, `{progress}` the progress bar. Animation steps change once a second (the tick is the current second). Frames must be exactly 3 single-width characters; the alignment test renders every face in every frame (CONTRIBUTING, "Art rules").

## Add-on file: `addons/<name>`

One per mood antenna add-on, in the repository; the file name is the add-on's name (`bytek addon` lists them, `docs/mood-antenna.md` shows them all). Plain text, `key: value` lines; lines starting with `#` are comments.

| Key | Meaning | Example |
| --- | --- | --- |
| `format` | the file's format version; optional, missing means 1 | `1` |
| `frames` | what sits on the antenna stick, one single-width character per animation step, `\|`-separated | `♡\|♥` |
| `meaning` | the vibe it shows, for the list and for Claude | `warm, things are going well` |

The current add-on is named in `$BYTEK_HOME/addon` (below); without it, or when it names no add-on, the antenna shows `heart`.

## Routines config: `$BYTEK_HOME/config/routines`

The user's reminders, written by hand (`examples/routines.example` to start from; the path can be changed with `BYTEK_ROUTINES`). One routine per line, `#` lines and blank lines skipped:

```
name = schedule | option | option ...
lunch    = daily 12:30                 | icon bowl | heads_up 10m | clear idle
training = tue,thu 18:30 | months 4-10 | icon bike | heads_up 30m
invoice  = monthly last-workday 10:00  | icon invoice | heads_up 1d
```

- **name:** lowercase letters, digits and `_`, starting with a letter; each name once.
- **schedule:** `daily`, `weekdays` (Monday to Friday), days (`mon,tue,wed,thu,fri,sat,sun`, comma-separated), `monthly <1-31>` or `monthly last-workday` (the last Monday to Friday of the month; holidays aren't known), followed by times and windows, comma-separated: `10:30, 15:00` or `19:00-20:00`. A window can't cross midnight. A monthly day a month doesn't have (31 in November) is skipped that month.
- **options:** `months 4-10` (or `months 12`) limits it to those months; a range like `10-4` runs over New Year. `disable` turns the routine off. `icon`, `heads_up`, `clear` and `action` are for the reminders (#97 to #99, #13).

A line Bytek can't read is skipped, so the others still work, and `bytek doctor` names it. The file has no version line: it's written by people, and a later format keeps reading this one.

## Files in `$BYTEK_HOME`

| Path | Written by | What |
| --- | --- | --- |
| `current` | setup, hooks | link to the installed copy; the status line command runs `current/bin/bytek` |
| `backup/settings.json.<stamp>` | setup | `settings.json` before setup changed it (`.before-uninstall` for uninstall) |
| `original-statusline.json` | setup | the status line Bytek replaced: `{"format": 1, "statusLine": ...}`, the status line `null` if there was none; uninstall puts it back and removes the file |
| `addon` | `bytek addon` | the current mood antenna's name, one line (`star`), shared by all sessions; only letters and `-` count. No version line: a different format would get a new file name |
| `config/antenna-reminders-off` | the user | while it exists, hooks print no antenna reminder (`docs/mood-antenna.md`) |
| `debug` | the user | while it exists, hooks append to `hooks.log` |
| `hooks.log` | hooks | one trimmed JSON line per hook event: no prompts or file contents, user-readable only, cut to half past `BYTEK_DEBUG_LOG_MAX` bytes (1 MB) |
| `config/` | the user | personal settings: `routines` (above), and later others (places); each feature documents its file here |
| `cache/` | providers | cache files from background providers; none yet (`bounded-contexts.md`) |
