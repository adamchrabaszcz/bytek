# Contributing

Thanks for helping Bytek grow. Most contributions are small: a new face, antenna add-on, outfit, companion or routine, each as one data file. Engine changes are welcome too.

Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md). Editors pick up the shared settings (UTF-8, LF, final newline, 2-space indent) from `.editorconfig`.

Where things are written down:

- `AGENTS.md`: the short version for coding agents (guardrails, what to decide alone and what to ask). Claude Code reads it directly (v2.1.277 or later), as long as there is no `CLAUDE.md`, so the repository has none.
- `docs/adr/`: architecture decision records, numbered, never deleted.
- `docs/architecture/`: how the engine is put together and the file formats.
- `docs/patterns/`: code shapes to follow, each with the anti-pattern it replaces.

## Workflow

1. Find or open an issue for the change (format below).
2. Branch from the latest `main`: `<type>/<short-topic>`, e.g. `feat/rain-outfit`, `fix/antenna-column`.
3. Make the change, keeping it focused on one thing, with its tests.
4. Run the checks (below) and look at the result in a real terminal (`bin/bytek preview` shows every state, add-on and routine stage; `--state`, `--addon` or `--routine dog:due` show one).
5. Open a pull request into `main`. CI must be green before merging. The code owners (`.github/CODEOWNERS`) are asked for review automatically.
6. Pull requests are squash merged: `main` gets one commit per pull request, with the pull request's title as its subject and its description as the body. That's why the title must be a Conventional Commit (it decides the release) and the description ends with `Closes #<issue>`. Commits inside a branch can be anything; nobody sees them after the merge.

### One issue per pull request

- Each feature, fix or docs change gets its own branch and pull request, even when several are asked for at once. A request with three things is three pull requests.
- Keep them independent: each starts from `main`, not from another open branch, and can be merged in any order.
- When a step really needs an earlier one (the hooks need the renderer), open its pull request after the earlier one is merged, or update it from `main` once it is.
- If `main` moves and a pull request conflicts, merge `main` into the branch rather than piling more onto it. No force-pushes: the squash merge leaves `main` with one commit anyway.
- Small means reviewable in one sitting: one behaviour, its tests and its docs.

### Definition of done

A pull request is ready to merge when:

- [ ] it closes exactly one issue, and every "Done when" item there is met
- [ ] a test fails without the change and passes with it
- [ ] `tests/run.sh` and `tools/lint.sh` pass locally (on a Mac under `/bin/bash` too) and CI is green
- [ ] the change was seen in a real terminal, when it shows on the status line
- [ ] docs it makes wrong are updated: README, this file, `AGENTS.md`, `docs/`, the usage text in `bin/bytek`
- [ ] a decision that is costly to reverse has an ADR in `docs/adr/`
- [ ] no personal data and no secrets
- [ ] the title is a Conventional Commit with the right type, and the description ends with `Closes #<issue>`

### Every change has tests

Every pull request adds or updates a test in `tests/` that fails without the change. Tests use [bats-core](https://github.com/bats-core/bats-core) with bats-support and bats-assert, vendored as git submodules in `tests/bats/` (after cloning: `git submodule update --init`).

- One file per area, `tests/<area>.bats`, starting with `load helpers`. One `@test` per behaviour, named as a sentence about it (`@test "narrow terminals cut long text"`).
- `tests/helpers.bash` gives every test a fresh temp folder with its own `BYTEK_HOME` and settings file (`$TMP`), and helpers: `render [session]`, `hook <json>`, `assert_state <session> <field> <value>`, `needs_jq`.
- Use `run` and the bats-assert checks (`assert_success`, `assert_output --partial`, `assert_equal`); `run --separate-stderr` when stderr matters. A test that needs a missing tool calls `skip` with the reason.
- **Integration tests** (`tests/<area>.bats`) go through `bin/bytek` like Claude Code does. **Unit tests** (`tests/unit/<module>.bats`, starting with `load ../helpers`) load one module with `load_module <name>` and call its functions directly. bats runs tests with `errexit` on and Bytek runs without it, so call a function whose commands may fail on purpose through `run`.
- A test can leave a note for the CI summary by writing `# <note>` to fd 3 (the speed test reports its milliseconds that way).

## Commits: Conventional Commits

Format: `<type>(<optional scope>): <summary>`, summary in the imperative, lowercase, no full stop.

| Type | For |
| --- | --- |
| `feat` | a new feature people can see or use (a new state, outfit, add-on, routine...) |
| `fix` | a bug fix |
| `docs` | documentation only |
| `style` | formatting, no behaviour change |
| `refactor` | code change that neither fixes a bug nor adds a feature |
| `perf` | performance (the render path has a 50 ms budget) |
| `test` | adding or fixing tests |
| `build` / `ci` | tooling, GitHub Actions, install scripts |
| `chore` | anything else |

Scopes: `core`, `hooks`, `plugin`, `art`, `addons`, `outfits`, `companions`, `routines`, `providers`, `preview`.

Examples:

```
feat(outfits): umbrella and drops when it rains
fix(core): keep the antenna in column 5 after a thought bubble
docs: how to write a companion file
```

Breaking changes (e.g. a change to the data file or state file format) get a `!` after the type and a `BREAKING CHANGE:` footer explaining what existing files need. A format change also bumps that format's version and keeps reading the older one (`docs/architecture/data-files.md`, "Format versions").

## Planned work: GitHub issues

- The roadmap is the [issue list](https://github.com/adamchrabaszcz/bytek/issues), not a section in the docs.
- Every task starts as an issue. If there is none yet, open one first, in the format below.
- The pull request for it ends its description with `Closes #<issue>`, so merging closes the issue. Every pull request closes exactly one issue.

### Issues and pull requests

**Issues** use one format. The issue forms (Feature, Bug, Docs or chore; there are no blank issues) write it; when you write the body yourself (`gh issue create --body`, the API), use the same headings:

```markdown
### What and why
What should change and why, in plain words. For a bug: what happens, what should, where, and how to see it.

### Done when
- [ ] A short checklist that says when it is finished

### Blast radius
Optional. What else it touches or could break (the render path, hooks, users' existing config or state files).

### Parent
Optional. #n, when it is one step of bigger work (also add it as a sub-issue there).
```

- **Title:** plain words, no type prefix ("Rain outfit: umbrella and drops").
- **Labels:** the kind (`enhancement`, `bug` or `chore`, set by the form) plus the area (`core`, `art`, `outfit`, `routine`, `companion`, `docs`) and `macos` for macOS-only parts.
- No personal data in issues, code or examples: no names, locations, schedules or paths from your machine.

**Pull requests** follow `.github/pull_request_template.md`: what and why, the checks you ran, and `Closes #<issue>`. The title is a Conventional Commit (`fix(core): keep the antenna in column 5`).

`.github/workflows/format.yml` checks both. An issue without "What and why" or "Done when" gets the `needs-format` label and a comment, both gone once it is fixed. A pull request without a Conventional Commit title or a `Closes #<issue>` line fails the `format / pull-request` check. The rules are in `tools/format-check.sh`, tested in `tests/format-check.sh`.

**Work that takes several pull requests** is a parent issue with a sub-issue per step (GitHub's "Add sub-issue" on the parent, or `gh api -X POST repos/<owner>/<repo>/issues/<parent>/sub_issues -F sub_issue_id=<id>`). Each step's pull request closes its sub-issue, and `.github/workflows/issues.yml` (`tools/close-parent.sh`) closes the parent when its last sub-issue is closed. Steps that come up later become new sub-issues of the same parent.

## Releases

After CI passes on `main`, `.github/workflows/release.yml` tags the commit and publishes a GitHub release with the merged pull requests as notes, if the merge shipped something. The version follows the commit types since the last release (`tools/release.sh`): a breaking change (`feat!:` or a `BREAKING CHANGE:` footer) → major, `feat` → minor, `fix` / `perf` → patch. `docs`, `ci`, `chore`, `test`, `refactor`, `style` and `build` make no release. So the commit type matters: it decides the version. The first release is `v0.1.0`.

Every release also carries `bytek.zip`, the plugin as Claude Code installs it, with the release's version in its `plugin.json` (`tools/plugin-zip.sh`). The `plugin.json` in the repository has no version: the version exists only in releases, so nothing is committed to `main` for it. Once the repository is public, the marketplace entry points at the newest release's zip (`releases/latest/download/bytek.zip`), so people get updates when a release ships, not on every merge.

After a release, every pull request in it and every issue those closed get the milestone `vX.Y.Z` and a "Released in vX.Y.Z" comment (`tools/release-marks.sh`), so an issue shows which version shipped it.

## Checks

```sh
git submodule update --init                 # once, fetches bats
tests/run.sh                                # every .bats file, one line per file
tests/bats/core/bin/bats tests/hooks.bats   # one file, every test listed
bash -n bin/bytek                           # the script parses
/bin/bash tests/run.sh                      # under macOS's bash 3.2 if you're on a Mac
tools/lint.sh                               # ShellCheck + shfmt on every shell file
tools/lint.sh --fix                         # let shfmt fix the formatting
```

`tools/lint.sh` needs [ShellCheck](https://www.shellcheck.net) and [shfmt](https://github.com/mvdan/sh) (macOS: `brew install shellcheck shfmt`). CI runs the same script with pinned versions (ShellCheck 0.11.0, shfmt 3.14.1, in the `lint` job of `.github/workflows/test.yml`); when you bump them, update both there and here.

CI (`.github/workflows/test.yml`) runs the same on every push to `main` and every pull request, on macOS with its own bash 3.2 and on Linux. The job summary lists each test suite with its result; the badge in the README shows the state of `main`.

The render path has a budget: 50 ms per render on average, because the status line redraws every second. `tests/speed.bats` renders every state through the real `bin/bytek`, with each program on `PATH` replaced by a stand-in that notes its call, and fails when a render starts anything but `dirname`, `cat` and `date`, once each (a new one needs a reason in the test). It measures the time too: its note (and so the job summary) shows it per OS; it fails above the budget only locally, since CI runners vary from run to run. `BYTEK_RENDER_BUDGET_MS` changes the budget locally, and the coverage run skips both checks (`BYTEK_COVERAGE=1`) because tracing slows everything down.

Line coverage runs after a merge, in its own workflow (`.github/workflows/coverage.yml`, on pushes to `main`; also by hand): it runs the tests again under [bashcov](https://github.com/infertux/bashcov) for every bash script in the repository (settings in `.simplecov`; the tests themselves are left out), with a table per file in the job summary, uploaded to Codecov (the coverage badge in the README and the history on codecov.io). It follows the trend on `main` and blocks nothing: tracing every line takes minutes, so pull requests wait only for lint and tests, and releases start from the `test` workflow alone. A drop in coverage shows up after the merge. The test files run in parallel (`tests/run.sh -j N`, one file per core). Under `BYTEK_COVERAGE=1` the tests that can't run or add nothing under tracing skip themselves: the speed budget, and `tests/run.sh`'s own tests (the report leaves `tests/` out). The run fails when `bin/bytek`, a module or a tool shows no covered lines, so a measurement that silently stops is noticed. bashcov follows scripts behind bats' `run`, which kcov couldn't (#59). Its gems are pinned in `Gemfile.lock` (Dependabot proposes updates) and cached between CI runs. To see it locally (Linux, Ruby 3.4): `bundle install`, then `BYTEK_COVERAGE=1 bundle exec bashcov --root . -- tests/run.sh -j 4` and open `coverage/index.html`.

## Code conventions

- Bash 3.2 compatible (the macOS default): no associative arrays, no `mapfile`, no `${var,,}`. Why bash, and why 3.2: `docs/adr/0003-bash-over-a-compiled-language.md`, `docs/adr/0004-bash-3-2-compatible.md`.
- **Modules:** the engine lives in `lib/*.sh`, one job per module; `bin/bytek` only sets up and dispatches, loading the modules each command needs. A module defines functions and constants only, with names that start with the module (`state_load`, `RENDER_SPINNER`); the shape is in `docs/patterns/module.md`, the reasons in `docs/adr/0002-engine-modules.md`. `tests/modules.bats` checks it.
- The render path (`bytek render`) reads only local files: no network, no `jq`, as few subprocesses as possible, well under 50 ms. Anything slow (weather, music, git) runs in the background and leaves a cache file.
- Hooks print nothing to stdout, and always exit 0: some hooks' output reaches Claude's context, and a failing hook must never block a tool call. The one exception is the mood antenna reminder on session start and prompts, short and off with one file (`docs/adr/0009-antenna-reminders.md`).
- Text from outside (hooks, the command line, caches written by providers) is untrusted: it goes through the control-character filter (`lib/hook-fields.jq`, `state_write`) before it can reach the terminal. New fields and new caches get the same treatment and a case in `tests/security.bats`.
- Nothing logs prompts or file contents. The debug log goes through `lib/debug-log.jq`.
- GitHub Actions are pinned to a full commit SHA with the version in a comment (`uses: actions/checkout@<sha> # v4.4.0`); Dependabot proposes updates. Dependabot's pull requests are the one exception to "every pull request closes an issue".
- Art and behaviour live in data files (one file per item); the engine reads them. A new face, add-on, outfit or companion should not need an engine change.
- Optional features (macOS Shortcuts, Music) degrade cleanly when the tool isn't there.
- jq programs longer than one line live in `lib/*.jq` and run with `jq -f`, not as multi-line strings in bash: they're easier to read, and line coverage can only count the first line of a multi-line command (`docs/adr/0006-jq-programs-in-files.md`).
- **Shell options:** every script declares `errexit`, `nounset` and `pipefail` before its first command (`set +o errexit +o nounset +o pipefail`, or `-o errexit` where it should stop on errors), instead of inheriting them. A parent that exports its options (bashcov does, to trace every script) would otherwise switch on strict modes a script wasn't written for. `tests/shell-options.bats` checks it.
- ShellCheck findings are fixed, not silenced. When the flagged code is intended (e.g. splitting on `IFS='|'` on purpose), disable that one check on that one line with the reason: `# shellcheck disable=SC2206 # splitting on '|' is the point`. Repository-wide exceptions live in `.shellcheckrc`, each with its reason.
- Comments explain *why*, not *what*.

## Art rules

- Every character is single-width. No emoji: they are double-width in most terminals and break the box.
- Faces are exactly 3 characters. The antenna stick `┴` sits in column 5 (counting the leading space as column 1). Anything to the right of the box starts at least one space after it.
- Prefer characters that are single-width everywhere. East-Asian "ambiguous" characters (`♡ ■ ◎ ♪` and the box drawing set) are fine but need an ASCII fallback once charsets land.
- Every new art file is covered by the alignment test.
