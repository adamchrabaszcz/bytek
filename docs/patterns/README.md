# Patterns

One file per code shape that Bytek uses in several places, with the anti-pattern it replaces. Follow them in new code; when a shape repeats a third time, give it a file here.

Each file has the same sections:

```markdown
# Pattern name

## Use when
The situation, in a sentence or two.

## Pattern
A short example, taken from the code where possible, and where it is used.

## Anti-pattern
What it replaces, and what goes wrong with it.
```

## Patterns

- [Return values through REPLY](reply-return-value.md): functions on the render path set `REPLY` instead of printing into `$( )`.
- [Braces before non-ASCII text](braces-before-non-ascii.md): `"${bar}▰"`, not `"$bar▰"`, which macOS's bash 3.2 misreads.
