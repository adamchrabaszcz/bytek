# Security

Bytek runs on every Claude Code tool call (as hooks), prints text in your terminal and edits `~/.claude/settings.json` during setup. Problems in any of these are taken seriously.

## Reporting a vulnerability

Please don't open a public issue. Report it privately through GitHub: **Security → Report a vulnerability** on this repository. Include what you found, how to reproduce it and which version (`/plugin` shows it, or the latest release tag) and OS you use.

You'll get an answer within a week. Fixes are released as a patch version and credited in the release notes unless you prefer otherwise.

## What Bytek does to stay safe

- Text that comes from hooks (file paths, commands, messages) has control characters removed before it is stored or shown, so it can't send escape sequences to your terminal.
- Settings are backed up before every change, edited through a checked temporary file, and only Bytek's own entries are removed on uninstall.
- The render path reads local files only; it makes no network calls.
- The debug log is off by default. When on, it leaves out prompts and file contents and keeps its size bounded.
- GitHub Actions in this repository are pinned to commit SHAs. CI's two tokens (`CODECOV_TOKEN` for coverage, `CLAUDE_CODE_OAUTH_TOKEN` for the AI review) are repository secrets, never in files. The AI review can comment but not push, and only the owner, members and collaborators can start it with `@claude` (checked in the workflow and by the action); pull requests from forks get no automatic review.

## Supported versions

Only the latest release gets fixes.
