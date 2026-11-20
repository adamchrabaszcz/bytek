# Return values through REPLY

## Use when
A function on the render path (or called by it) returns a string: a frame, a progress bar, a cut text.

## Pattern
The function sets the global `REPLY`, and the caller copies it right away:

```bash
# Sets REPLY to $1 cut to $2 characters, ending in "…" when cut.
truncate_to() {
  ...
  REPLY="${1:0:$(($2 - 1))}…"
}

truncate_to "$status" "$max"
status=$REPLY
```

Used by `pick`, `progress_bar`, `truncate_to` and `duration` in `bin/bytek`. The comment above each function says what it sets `REPLY` to.

## Anti-pattern
Printing the result and capturing it:

```bash
status=$(truncate_to "$status" "$max")
```

Every `$( )` forks a subshell. The status line renders every second within a 50 ms budget, and on macOS's bash 3.2 a handful of forks per render use up a noticeable part of it. Copy `REPLY` straight away: the next call overwrites it.
