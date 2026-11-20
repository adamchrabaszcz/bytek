# Bytek: agent instructions

Bytek is a small ASCII companion for the Claude Code status line, written in bash. It shows what the agent is doing (reading, thinking, editing, testing, waiting), with faces, outfits and routines kept in data files. Claude Code runs `bin/bytek render` every second for the status line and `bin/bytek hook` on its hook events; `bytek setup` and `bytek uninstall` edit `~/.claude/settings.json`. MIT licensed, macOS first, Linux too.

This file is the rulebook for coding agents. The details behind it are in `CONTRIBUTING.md`, the decisions in `docs/adr/`, the structure in `docs/architecture/`, the recurring code shapes in `docs/patterns/`. Keep this file under 10 KB (`tests/docs.bats` checks it); link to those instead of copying them here.

## Guardrails

1. Never commit or push directly to `main`. Branch and open a pull request.
2. An agent never merges a pull request. Merging is a human action.
3. Never rewrite shared history (`push --force`, rebasing `main`). To update a branch from `main`, merge `main` into it.
4. Ask before any outward-facing action beyond pushing a branch and opening its pull request: comments on issues and pull requests, creating or editing issues, releases, tags, repository settings.
5. Destructive commands (deleting branches, tags or files outside your change) need explicit confirmation for that specific action, with the evidence shown first.
6. Never read, print or quote local secret files (`~/.claude/settings.json`, `.env` files, credential stores), or copy their contents into this repo.
7. This repo needs no secrets in its files. Never add one, not even as an example value. CI's tokens, `CODECOV_TOKEN` and `CLAUDE_CODE_OAUTH_TOKEN` (the AI review), are GitHub Actions secrets in the repository settings.
8. No personal data in code, tests, examples, issues or commits: no names, places, schedules or paths from anyone's machine. Personal values live in the user's `~/.claude/bytek/config/`, never in the repo.

## Decide on your own

These have a rule already, so don't ask:

- **Branch name:** `<type>/<short-topic>` from the latest `main`, e.g. `feat/rain-outfit`.
- **Commit and pull request title:** a Conventional Commit; the type decides the release (table in `CONTRIBUTING.md`). Behaviour users see is `feat` or `fix`; tooling is `ci` or `build`; docs only is `docs`.
- **Tests:** every change adds or updates a bats test that fails without it, in `tests/<area>.bats` (unit tests of a `lib/` module in `tests/unit/<module>.bats`).
- **Formatting and lint:** `tools/lint.sh --fix`, then fix ShellCheck findings in the code; a `# shellcheck disable=` needs the reason on the same line.
- **Docs that the change makes wrong:** update them in the same pull request (README, `CONTRIBUTING.md`, `docs/`, the usage text at the top of `bin/bytek`).
- **Small cleanups inside the files you change.** Bigger refactors are their own issue.
- **Working notes and plans:** in `.plan/` (ignored by git).
- **Where code goes:** the module map in `docs/architecture/`; shapes in `docs/patterns/`.

## Ask first

- What the user sees when the issue doesn't say: art, faces, wording on the status line.
- A new dependency or tool, for users or for CI.
- Anything that changes a file format users already have (state, config, data files): that is a breaking change.
- Changes to CI, releases or repository settings beyond what the issue asks.
- A decision that deserves an ADR (below): propose it, don't settle it alone.
- Work that grows past its issue: say so and suggest a follow-up issue instead of widening the pull request.

## Workflow

1. Every change starts from a GitHub issue (format in `CONTRIBUTING.md`). One issue, one branch, one pull request.
2. Branch from the latest `main`. If Bytek runs from this checkout as the status line, work in a `git worktree` so the checkout stays on `main`.
3. Make the change with its tests and docs. Run the checks below before every push; CI runs the same, but it isn't the first place to find out.
4. The pull request follows `.github/pull_request_template.md` and ends with `Closes #<issue>`. Pull requests are squash merged, so the title becomes the commit on `main`.
5. Done means the definition of done in `CONTRIBUTING.md`.

## Checks

```sh
git submodule update --init   # once: bats in tests/bats/
tests/run.sh                  # all tests; on a Mac also: /bin/bash tests/run.sh (bash 3.2)
tools/lint.sh                 # ShellCheck + shfmt
```

CI (`.github/workflows/test.yml`) runs lint and the tests on Linux and on macOS with bash 3.2; pull requests wait for those. Line coverage (bashcov, `coverage.yml`) runs after a merge to `main` and blocks nothing.

## Code rules that bite

- **Bash 3.2** (macOS's own): no associative arrays, no `mapfile`, no `${var,,}`, no `case` inside `$( )`.
- **Render path** (`bytek render`): local files only, no network, no `jq`, as few subprocesses as possible; 50 ms budget; `tests/speed.bats` counts the programs a render starts (only `dirname`, `cat`, `date`). Return values through `REPLY` (`docs/patterns/`).
- **Modules:** the engine is `lib/*.sh`, one job each; `bin/bytek` only dispatches. Functions and constants only, named after the module (`state_load`, `RENDER_SPINNER`); new code goes into the module whose job it is (`docs/patterns/module.md`).
- **Hooks** print nothing to stdout, except the antenna reminder on session start and prompts (`docs/adr/0009-antenna-reminders.md`), and always exit 0.
- **Outside text is untrusted:** hook fields, command-line text and caches go through the control-character filter (`lib/hook-fields.jq`, `state_write`); new inputs get a case in `tests/security.bats`.
- **Shell options:** every script declares `set ±o errexit ±o nounset ±o pipefail` before its first command (`tests/shell-options.bats`).
- **jq programs** longer than one line live in `lib/*.jq`.
- **Art:** single-width characters only, no emoji; faces are exactly 3 characters; the antenna stick sits in column 5. One data file per face, outfit or companion; new art shouldn't need an engine change.
- **GitHub Actions** are pinned to a full commit SHA with the version in a comment.

## Decisions and patterns

- **ADRs** (`docs/adr/`): a decision that is costly to reverse or that people will ask "why?" about (language, file formats, what Bytek may edit, dependencies) gets a numbered record. Records are never deleted; a changed decision gets a new record that supersedes the old one. Template in `docs/adr/README.md`.
- **Patterns** (`docs/patterns/`): a code shape used in several places, with the anti-pattern it replaces. Follow them; when you add a pattern, add its file.

## Code review

Claude reviews each pull request when it's opened or marked ready (`.github/workflows/claude-review.yml`); `@claude review` in a comment asks for another pass (only the owner, members and collaborators can start it; fork pull requests get no automatic review). When reviewing, look first at what CI can't see:

- **Bash 3.2:** anything newer that slips through (`docs/adr/0004-bash-3-2-compatible.md`), `"$var▰"` without braces.
- **The render path:** a new subprocess, jq or network call in `bytek render` (50 ms budget).
- **Hooks:** anything printed to stdout beyond the antenna reminder, a way to exit non-zero or hang.
- **Outside text:** hook fields, command-line text or cache contents that reach the terminal without the control-character filter.
- **Files people already have:** a state, face or config format change without a version bump (`docs/architecture/data-files.md`).
- **Tests:** a change without a test that fails without it; a test that depends on timing.
- **No personal data or secrets** in code, tests, docs or examples.

Skip what ShellCheck, shfmt and the tests already catch. The summary is a checklist of these points and the definition of done, `[x]` when fine and `[ ]` with what needs attention (leaving out what doesn't apply), then the verdict. If nothing important turns up, keep it short.
