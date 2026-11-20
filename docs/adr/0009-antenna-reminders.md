# 0009. Hooks remind Claude of the mood antenna

- Status: Accepted
- Date: 2026-11-20

## Context
Claude picks the mood antenna (#4) so it reflects the work. With only instructions in a `CLAUDE.md` asking for it "a few times per session", it rarely changed: nothing reminded Claude, and in a long session it slipped. People also had to copy a snippet into their own `CLAUDE.md` for it to happen at all.

Until now Bytek's hooks printed nothing, because the stdout of some hooks (SessionStart, UserPromptSubmit) is added to Claude's context, and a status line companion has no business in it.

## Decision
Two hooks add a short text to Claude's context, by printing it on stdout (plain text, which Claude Code adds as context and doesn't show in the chat):

- **SessionStart** (which also runs after a compaction): the antenna instructions, with the add-ons and the moments to change it, and the current one.
- **UserPromptSubmit:** one line, `Bytek's antenna: <name>.`, so Claude decides at the start of each task whether it still fits.

Every other hook still prints nothing. A file `~/.claude/bytek/config/antenna-reminders-off` turns both off, and then no hook prints anything. Claude still makes the choice; the hooks only remind.

## Consequences
- The antenna can follow the work, and works for everyone who installs Bytek, without a `CLAUDE.md` snippet (the snippet stays in the docs for those who turn the reminders off).
- A few lines of context per session and about ten words per prompt.
- Changing the antenna is a tool call each time; setup allows exactly that command, so it asks for no permission (`0010`).
- Anything new a hook prints needs to stay this small, on these two events, and go through `HOOKS_CONTEXT`; `tests/hooks.bats` checks that the other events print nothing.
