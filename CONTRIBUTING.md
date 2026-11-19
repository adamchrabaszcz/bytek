# Contributing

Thanks for helping Bytek grow. Most contributions are small: a new face, antenna add-on, outfit, companion or routine, each as one data file. Engine changes are welcome too.

## Workflow

1. Find or open an issue for the change (format below).
2. Branch from the latest `main`: `<type>/<short-topic>`, e.g. `feat/rain-outfit`, `fix/antenna-column`.
3. Make the change, keeping it focused on one thing, with its tests.
4. Run the checks (below) and look at the result in a real terminal (`bytek set <state>`, later `/bytek preview`).
5. Open a pull request into `main`. CI must be green before merging.

### One issue per pull request

- Each feature, fix or docs change gets its own branch and pull request, even when several are asked for at once. A request with three things is three pull requests.
- Keep them independent: each starts from `main`, not from another open branch, and can be merged in any order.
- When a step really needs an earlier one (the hooks need the renderer), open its pull request after the earlier one is merged, or rebase it onto `main` once it is.
- If `main` moves and a pull request conflicts, update it from `main` rather than piling more onto it.
- Small means reviewable in one sitting: one behaviour, its tests and its docs.

### Every change has tests

Every pull request adds or updates a test in `tests/` that fails without the change. Tests are plain bash scripts (`tests/<area>.sh`) that print `ok: ...` and exit 0, or print `FAIL ...` lines and exit 1. `tests/run.sh` runs them all.

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

Breaking changes (e.g. a change to the data file or state file format) get a `!` after the type and a `BREAKING CHANGE:` footer explaining what existing files need.

## Planned work: GitHub issues

- The roadmap is the [issue list](https://github.com/adamchrabaszcz/bytek/issues), not a section in the docs.
- Every task starts as an issue. If there is none yet, open one first, in the format below.
- The pull request for it ends its description with `Closes #<issue>`, so merging closes the issue. Every pull request closes exactly one issue.

### Issues and pull requests

**Issues** use one format:

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
- **Labels:** the area (`core`, `art`, `outfit`, `routine`, `companion`, `docs`) plus `macos` for macOS-only parts.
- No personal data in issues, code or examples: no names, locations, schedules or paths from your machine.

**Pull requests** follow `.github/pull_request_template.md`: what and why, the checks you ran, and `Closes #<issue>`. The title is a Conventional Commit.

**Work that takes several pull requests** is a parent issue with a sub-issue per step (GitHub's "Add sub-issue"). Each step's pull request closes its sub-issue.

## Checks

```sh
tests/run.sh                  # every test script in tests/
bash -n bin/bytek             # the script parses
/bin/bash tests/run.sh        # same, under macOS's bash 3.2 if you're on a Mac
```

CI (`.github/workflows/test.yml`) runs the same on every push to `main` and every pull request, on macOS with its own bash 3.2 and on Linux. The job summary lists each test suite with its result; the badge in the README shows the state of `main`.

## Code conventions

- Bash 3.2 compatible (the macOS default): no associative arrays, no `mapfile`, no `${var,,}`.
- The render path (`bytek render`) reads only local files: no network, no `jq`, as few subprocesses as possible, well under 50 ms. Anything slow (weather, music, git) runs in the background and leaves a cache file.
- Hooks print nothing to stdout and always exit 0: some hooks' output reaches Claude's context, and a failing hook must never block a tool call.
- Art and behaviour live in data files (one file per item); the engine reads them. A new face, add-on, outfit or companion should not need an engine change.
- Optional features (macOS Shortcuts, Music) degrade cleanly when the tool isn't there.
- Comments explain *why*, not *what*.

## Art rules

- Every character is single-width. No emoji: they are double-width in most terminals and break the box.
- Faces are exactly 3 characters. The antenna stick `┴` sits in column 5 (counting the leading space as column 1). Anything to the right of the box starts at least one space after it.
- Prefer characters that are single-width everywhere. East-Asian "ambiguous" characters (`♡ ■ ◎ ♪` and the box drawing set) are fine but need an ASCII fallback once charsets land.
- Every new art file is covered by the alignment test.
