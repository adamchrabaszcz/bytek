# Data files

Every file Bytek reads or writes, field by field. `$BYTEK_HOME` is `~/.claude/bytek` unless set.

## Format versions

Files that outlive a Bytek version carry a format version, so a newer Bytek can recognise an older file and an older Bytek doesn't misread a newer one (`docs/adr/0008-versioned-file-formats.md`):

| File | Current format | Without a version | Newer than this Bytek knows |
| --- | --- | --- | --- |
| state file | `format=1`, its first line | format 1 | loads as idle; hooks leave the file alone |
| face file | `format: 1`, optional | format 1 | the idle face is shown instead |
| add-on file | `format: 1`, optional | format 1 | the plain heart is shown instead |
| companion file | `format: 1`, optional | format 1 | the reminder shows without its companion, with `◷` |
| cleared file | `format=1`, its first line | not read: clears nothing | clears nothing; `bytek done` leaves the file alone |
| away file | `format=1`, its first line | no check yet: one starts | no check yet: one starts and writes format 1 |
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
lunch    = daily 12:30                 | icon meal | heads_up 10m | clear idle
training = tue,thu 18:30 | months 4-10 | icon bike | heads_up 30m
invoice  = monthly last-workday 10:00  | icon invoice | heads_up 1d
```

- **name:** lowercase letters, digits and `_`, starting with a letter; each name once.
- **schedule:** `daily`, `weekdays` (Monday to Friday), days (`mon,tue,wed,thu,fri,sat,sun`, comma-separated), `monthly <1-31>` or `monthly last-workday` (the last Monday to Friday of the month; holidays aren't known), followed by times and windows, comma-separated: `10:30, 15:00` or `19:00-20:00`. A window can't cross midnight. A monthly day a month doesn't have (31 in November) is skipped that month.
- **options:** `months 4-10` (or `months 12`) limits it to those months; a range like `10-4` runs over New Year. `disable` turns the routine off. `heads_up 10m` (or `1h`, `1d`) shows a reminder that long before; `overdue 30m` how long it stays after its time or window (default 20 minutes); anything else there (`10min`, `1hour`) makes the line one Bytek can't read. `icon dog` puts a companion next to Bytek (`companions/<name>`, below; a name with no companion file keeps the `◷`). `clear idle` clears the occurrence when the Mac has had no keyboard or mouse input for 10 minutes while it's due or overdue (`clear idle 15m` for another time): away during it means it happened. It works on macOS (`ioreg`); elsewhere `bytek doctor` says so. `action` is for a later step (#13).

**On the status line**, the most urgent reminder goes first in the status row, what Claude is doing after it: `◷ lunch in 8m · editing 3 files` (heads-up), `◷ lunch now` or `◷ walk now, until 20:00` (due), `◷ lunch 15m ago` in bold (overdue), with `+1` when more are active (the detail row stays on what Claude is doing). A time is due for its whole minute, a window through its last one. Overdue beats due beats a heads-up; among equals, the one that starts first. In a narrow terminal the work status is shortened, not the reminder. `bytek done walk` (or `bytek skip walk`) clears a reminder: the occurrence showing now, else the next one that starts today; the next one shows as usual. Otherwise a reminder stays for its overdue time; one whose time passed before midnight isn't shown after it.

A line Bytek can't read is skipped, so the others still work, and `bytek doctor` names it. The file has no version line: it's written by people, and a later format keeps reading this one.

## Companion file: `companions/<name>`

One per companion, in the repository; a routine picks one with `icon <name>`. Plain text, `key: value` lines; lines starting with `#` are comments; every key is optional.

| Key | Meaning | Example |
| --- | --- | --- |
| `format` | the file's format version; missing means 1 | `1` |
| `icon` | next to Bytek during the heads-up | `(ᵔᴥᵔ)` |
| `due` | next to Bytek while due, `\|`-separated animation steps | `(ᵔᴥᵔ)~\|(ᵔᴥᵔ)` |
| `due_text` | replaces the reminder's text while due; `{routine}` is the routine's name | `{routine} time!` |
| `due_face` | Bytek's face while due, `\|`-separated steps of 3 characters | `^ᴗ^\|ᵔᴗᵔ` |
| `due_thought` | Bytek's thought while due | `!` |
| `leash` | `yes`: while due, the companion hangs on a leash from the box (`╮` and `╰`) | `yes` |
| `overdue` | next to Bytek when overdue, `\|`-separated steps | `(•ᴥ•)?\|(•ᴥ•)` |
| `overdue_text` | replaces the reminder's text when overdue | `waiting by the door` |
| `heads_up_named` | replaces the heads-up text when the companion has a name (`bytek name`); `{name}`, `{routine}`, `{in}` (the time to go) | `{name}'s {routine} in {in}` |
| `due_named` | replaces the due text when the companion has a name | `{name}, {routine} time!` |
| `overdue_named` | replaces the overdue text when the companion has a name | `{name} is waiting by the door` |

The companion stands at the start of the detail row, Claude's detail after it; the reminder's text stays first in the status row. Steps of different widths are padded to the widest, so what follows doesn't move. A narrow terminal cuts Claude's detail, never the companion.

## Companion names: `$BYTEK_HOME/config/companions`

Written by `bytek name dog Rex` (or by hand); example in `examples/companions.example`. One `companion = Name` per line; lines starting with `#` are comments. The companion must be one in `companions/`; the name is cut to 20 characters, control characters dropped, and can't contain `=`. A companion with a name uses its `*_named` texts; without one, or when the file doesn't have them, the plain texts. Every routine with that `icon` gets the same name. `bytek doctor` names lines it can't use.

## Cleared file: `$BYTEK_HOME/cleared`

The occurrences cleared with `bytek done <routine>` or `bytek skip <routine>`. Plain text: first `format=1`, then one line per occurrence, `<routine> <start> <how> <when>`: the routine's name, the occurrence's start and the moment it was cleared (seconds since 1970), and `done`, `skip` or `idle` (cleared by `bytek away`). Read on every render while routines are set up, so the reminder moves on to the routine's next occurrence. Each `bytek done` or `skip` writes it whole (temp file and rename) and drops entries that started more than 2 days ago. When two clear at the same moment, the last one wins (as with the state file, `docs/adr/0007-no-lock-append-edits.md`).

## Away file: `$BYTEK_HOME/away`

The last check of how long the Mac has had no keyboard or mouse input, for routines with `clear idle` (`lib/away.sh`). Plain text: `format=1`, `sampled=<seconds since 1970>`, `idle=<seconds without input>`. While such a routine exists and `ioreg` is there, the status line starts `bytek away` in the background when the last check is 10 seconds old, after writing its stamp first so other renders don't start one too. `bytek away` reads `HIDIdleTime` from `ioreg` (it keeps counting while the screen is locked, and prompts sent from another device don't reset it), writes the file, and adds due or overdue `clear idle` occurrences to the cleared file as `idle`. Written with plain `printf`, no temp file, because the render path writes the stamp and starts no programs; a reader that catches it half-written sees no check and starts one more.

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
| `cleared` | `bytek done`, `bytek skip`, `bytek away` | the cleared reminders (above) |
| `away` | the status line, `bytek away` | the last idle check (above) |
| `config/` | the user, `bytek name` | personal settings: `routines` and `companions` (above), and later others (places); each feature documents its file here |
| `cache/` | providers | cache files from background providers; none yet (`bounded-contexts.md`) |
