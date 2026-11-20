# Architecture decision records

One file per decision that is costly to reverse or that people will ask "why?" about: the language, file formats, what Bytek may edit, dependencies.

- **Name:** `NNNN-decision-title.md`, numbered in order (`0002-bash-over-a-compiled-language.md`). Numbers are never reused.
- **Never deleted.** When a decision changes, write a new record and set the old one's status to `Superseded by NNNN`. The old record stays, so the history of why stays readable.
- **Short:** a page at most. Write it in the pull request that makes the decision, or before it as a proposal (`Proposed`).

## Template

```markdown
# NNNN. Decision title

- Status: Proposed | Accepted | Superseded by NNNN
- Date: YYYY-MM-DD

## Context
What forces the decision: the problem, the constraints, the options considered.

## Decision
What we do, in one or two sentences, then any detail.

## Consequences
What becomes easier, what becomes harder, what we now have to keep doing.
```

## Records

- [0001. Record architecture decisions](0001-record-architecture-decisions.md)
- [0002. The engine is split into modules](0002-engine-modules.md)
- [0003. Bash, not a compiled language](0003-bash-over-a-compiled-language.md)
- [0004. Compatible with bash 3.2](0004-bash-3-2-compatible.md)
- [0005. Bytek edits settings.json itself](0005-bytek-edits-settings-json.md)
- [0006. JSON through jq, with programs in lib/*.jq](0006-jq-programs-in-files.md)
- [0007. No lock on state files: edits are appended to a list](0007-no-lock-append-edits.md)
- [0008. Files that outlive a version carry a format version](0008-versioned-file-formats.md)
