# Touch Bar

On a MacBook Pro with a Touch Bar, Bytek can sit there too, on one line:

```
(≧ᴗ≦) editing · ◜ lib/render.sh
(◕ᴗ◕) needs you · Bash: tools/lint.sh
```

macOS doesn't let a command-line tool put anything on the Touch Bar by itself; a Touch Bar app does it. Bytek gives the line, the app shows it and runs it again every second or two:

```sh
~/.claude/bytek/current/bin/bytek line --width 40
```

`bytek line` prints the face, a companion when a routine shows one, the status and the detail, without colour codes. It shows the Claude Code session that changed last; `--session ID` picks one. `--width N` cuts the text to N characters, the detail first; the Touch Bar has room for about 40 to 60, depending on what else is on it. If something goes wrong it prints `(•ᴗ•) bytek`, never nothing. With `bytek charset ascii` the line is plain ASCII too.

It works anywhere a command's output is shown, so the same command fits a menu bar app, or a Mac without a Touch Bar.

## MTMR

[MTMR](https://github.com/Toxblh/MTMR) (My TouchBar My Rules) is free and open source: `brew install --cask mtmr`. Its Touch Bar is a list of items in `~/Library/Application Support/MTMR/items.json`. Open it from the MTMR menu bar icon (**Edit Preset File…**, or **Customize Touch Bar…** then *Advanced*) and add this item to the list:

```json
{
  "type": "shellScriptTitledButton",
  "source": {
    "inline": "$HOME/.claude/bytek/current/bin/bytek line --width 40"
  },
  "refreshInterval": 1,
  "width": 360,
  "align": "left",
  "bordered": false
}
```

- `refreshInterval` is in seconds: 1 follows Bytek like the status line does, 2 is gentler.
- `width` is the item's room on the Touch Bar, in points. If the line is cut off by the edge, lower `--width` or raise `width`.
- `align` puts the item on the left, in the middle (`center`) or on the right of the Touch Bar.

Save in the editor (⌘S) and the Touch Bar updates; after editing the file by hand, restart MTMR if nothing changes.

## BetterTouchTool

BetterTouchTool (paid) has a Touch Bar widget that runs a shell script and shows what it prints. Give it the command above and let it run every second.
