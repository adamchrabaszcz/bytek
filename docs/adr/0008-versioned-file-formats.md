# 0008. Files that outlive a version carry a format version

- Status: Accepted
- Date: 2026-11-20

## Context
State files, face files and the saved status line outlive the Bytek version that wrote them: a plugin update, a downgrade, or two versions running side by side (an old session next to a new one) mean one version reads another's files. Without a version in the file, a newer layout is read as if it were the old one: wrong fields on the status line, or a broken status line put back into `settings.json` on uninstall.

## Decision
Each such file carries a format version: the state file as a `format=1` first line, a face file as an optional `format: 1` key, the saved status line as `{"format": 1, "statusLine": ...}`. A missing version means format 1, so files written before versions existed keep working. A version newer than the reader knows is never guessed at: the state loads as idle and hooks leave the file alone, the idle face is shown, and uninstall puts nothing back and keeps the file. The edit list has no version (a version line would break its atomic appends, and it lives for one turn); a new format there gets a new file name.

## Consequences
- A format change bumps its version, and Bytek keeps reading the older version (a migration) as long as such files can exist.
- An older Bytek can't read a newer version's files, but it fails safe instead of misreading them.
- `docs/architecture/data-files.md` lists every format and its current version; tests cover current, missing and newer versions.
