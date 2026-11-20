# 0001. Record architecture decisions

- Status: Accepted
- Date: 2026-11-20

## Context
Bytek's early decisions (bash, bash 3.2 compatibility, editing `settings.json`, jq programs in files) were taken in issues and pull requests and summed up in `CONTRIBUTING.md`. The reasons are spread out, and contributors and coding agents keep asking why, or quietly undo a decision they can't see.

## Decision
Decisions that are costly to reverse get an architecture decision record in `docs/adr/`, in the format of `docs/adr/README.md`: numbered, short, never deleted, superseded by a new record when they change.

## Consequences
- A change that goes against a record has to supersede it first, in the open.
- Decisions already taken get their records as the docs catch up (#45).
- `AGENTS.md` and `CONTRIBUTING.md` point here instead of explaining the reasons themselves.
