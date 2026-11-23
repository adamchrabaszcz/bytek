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

[MTMR](https://github.com/Toxblh/MTMR) (My TouchBar My Rules) is free and open source: `brew install --cask mtmr`. Its Touch Bar is a list of items in `~/Library/Application Support/MTMR/items.json`. Open it from the MTMR menu bar icon (**Edit Preset File…**, or **Customize Touch Bar…** then *Advanced*).

MTMR replaces the app's part of the Touch Bar. To keep every other app's own controls, give each item a `matchAppId`: MTMR then shows only while that app is in front, here the terminal Claude Code runs in, and steps aside for the rest. A preset with Bytek and an Escape key, in iTerm2 only:

```json
[
  {
    "type": "escape",
    "width": 64,
    "align": "left",
    "matchAppId": "iterm2"
  },
  {
    "type": "shellScriptTitledButton",
    "source": {
      "inline": "$HOME/.claude/bytek/current/bin/bytek line --width 40"
    },
    "refreshInterval": 1,
    "align": "left",
    "bordered": false,
    "matchAppId": "iterm2"
  }
]
```

- `matchAppId` is a pattern matched against the app's id: `iterm2` matches iTerm2's `com.googlecode.iterm2`, `Terminal` matches Apple's Terminal. `osascript -e 'id of app "iTerm"'` prints an app's id. Leave it out to show Bytek in every app, instead of their own controls.
- In MTMR's menu, untick **Hide Control Strip** to keep Apple's Control Strip (brightness, volume, Siri) on the right. MTMR's own brightness and volume buttons are then duplicates you can leave out.
- `refreshInterval` is in seconds: 1 follows Bytek like the status line does, 2 is gentler.
- Without a `width` the item fits its text. A fixed `width` (in points) keeps it still while the text changes, with the text centred in it. `align` places the item on the left, in the middle (`center`) or on the right of the bar; it doesn't move the text inside the item.
- `--width` cuts Bytek's line to that many characters, the detail first: 40 leaves room for the Control Strip.

Save in MTMR's editor (⌘S) and the Touch Bar updates. After editing the file by hand, restart MTMR: it doesn't notice the change by itself.

## BetterTouchTool

BetterTouchTool (paid) has a Touch Bar widget that runs a shell script and shows what it prints. Give it the command above and let it run every second.
