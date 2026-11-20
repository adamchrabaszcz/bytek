# Return values through REPLY

## Use when
A function on the render path (or called by it) returns a string: a frame, a progress bar, a cut text.

## Pattern
The function sets the global `REPLY`, and the caller copies it right away:

```bash
# Sets REPLY to $1 cut to $2 characters, ending in "…" when cut.
render_cut() {
  ...
  REPLY="${1:0:$(($2 - 1))}…"
}

render_cut "$status" "$max"
status=$REPLY
```

Used by `render_pick`, `render_bar`, `render_cut` (`lib/render.sh`), `clock_now`, `clock_stamp` and `clock_duration` (`lib/clock.sh`). The comment above each function says what it sets `REPLY` to.

## Anti-pattern
Printing the result and capturing it:

```bash
status=$(render_cut "$status" "$max")
```

Every `$( )` forks a subshell. The status line renders every second within a 50 ms budget, and on macOS's bash 3.2 a handful of forks per render use up a noticeable part of it. Copy `REPLY` straight away: the next call overwrites it.
