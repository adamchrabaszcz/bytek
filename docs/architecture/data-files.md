# Data files

Every file Bytek reads or writes, field by field. Changing a format users already have (state, config, data files) is a breaking change: it gets a `!` in its commit type and a `BREAKING CHANGE:` footer (CONTRIBUTING, "Commits").

`$BYTEK_HOME` is `~/.claude/bytek` unless set.

## State file: `$BYTEK_HOME/state/<session>`

One per Claude Code session (`<session>` is the session id: letters, digits, `_`, `-`); `default` is used when a session has none yet. Written by hooks and `bytek set`, read by the status line. Plain text, one `key=value` per line, in this order:

| Key | Meaning | Example |
| --- | --- | --- |
| `state` | the face to show; a file name in `faces/` | `editing` |
| `arg` | fills `{arg}` in the face's detail | `src/api.ts` |
| `status` | replaces the face's status text when set | `editing 3 files` |
| `detail` | replaces the face's detail text when set | `$ npm run build` |
| `progress` | `N/M` for `{progress}`; empty shows a sweeping cell | `3/5` |
| `since` | when the state last changed, seconds since 1970 | `1763635200` |
| `turn_start` | when the prompt was sent, for the turn's duration | `1763635100` |
| `edits` | file edits in this turn | `4` |
| `files` | files edited in this turn, `\|`-separated with `\|` at both ends | `\|src/a.ts\|src/b.ts\|` |

Values are one line: line breaks and tabs become spaces and control characters are removed when the file is written. Unknown keys are ignored when it is read, and a missing file reads as `idle`. Files untouched for 7 days are removed at the next session start; a session's file is removed when it ends.

An `idle` or `done` state older than `BYTEK_SLEEP_AFTER` seconds (default 600) is shown as `sleeping`.

## Face file: `faces/<state>`

One per state, in the repository; the file name is the state's name (`bytek states` lists them). Plain text, `key: value` lines; lines starting with `#` are comments.

| Key | Meaning | Example |
| --- | --- | --- |
| `frames` | the 3-character face, one per animation step, `\|`-separated | `≧ᴗ≦\|≦ᴗ≧` |
| `thought` | what floats next to the antenna, `\|`-separated steps; optional | `✎` |
| `status` | the main text, right of the face | `editing` |
| `detail` | the dimmed line below it | `{spin} {arg}` |

In `detail`: `{arg}` is the state's `arg`, `{spin}` a spinner, `{progress}` the progress bar. Animation steps change once a second (the tick is the current second). Frames must be exactly 3 single-width characters; the alignment test renders every face in every frame (CONTRIBUTING, "Art rules").

## Files in `$BYTEK_HOME`

| Path | Written by | What |
| --- | --- | --- |
| `current` | setup, hooks | link to the installed copy; the status line command runs `current/bin/bytek` |
| `backup/settings.json.<stamp>` | setup | `settings.json` before setup changed it (`.before-uninstall` for uninstall) |
| `original-statusline.json` | setup | the status line Bytek replaced, as JSON (`null` if none); uninstall puts it back and removes the file |
| `debug` | the user | while it exists, hooks append to `hooks.log` |
| `hooks.log` | hooks | one trimmed JSON line per hook event: no prompts or file contents, user-readable only, cut to half past `BYTEK_DEBUG_LOG_MAX` bytes (1 MB) |
| `config/` | the user | personal settings for features that need them (routines, places); nothing reads it yet; each feature documents its file here |
| `cache/` | providers | cache files from background providers; none yet (`bounded-contexts.md`) |
