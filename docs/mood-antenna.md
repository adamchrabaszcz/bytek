# Mood antenna

The symbol on top of Bytek's antenna shows the session's vibe. Claude picks it a few times per session; it's a playful choice, not a claim about feelings. The current one is in `~/.claude/bytek/addon`, and each add-on is a file in `addons/` (format in `docs/architecture/data-files.md`). There is one antenna for all sessions: with two Claude Code sessions open, the last one to pick sets it on both status lines.

| Add-on | Antenna | Vibe |
| --- | --- | --- |
| `heart` | `♡` `♥` | warm, things are going well (the default) |
| `lollipop` | `@` `◎` | playful, a light and easy task |
| `star` | `✦` `✧` | proud, something worked out nicely |
| `flower` | `✿` `❀` | calm, steady work |
| `music` | `♪` `♫` | in the flow, one change after another |
| `sun` | `☼` | bright, a fresh start |
| `idea` | `*` `✳` | inspired, a new idea or approach |
| `curious` | `?` | curious, exploring or figuring something out |
| `sleepy` | `~` | slow, a long wait or a quiet moment |

Set one yourself with `/bytek addon <name>` in Claude Code, or `bytek addon <name>` in a terminal; `bytek addon` alone lists them and marks the current one. `bytek setup` lets Claude run that command without a permission prompt (one rule in `settings.json`, removed on uninstall); if you set Bytek up before that, run setup once more.

## Let Claude pick

Bytek doesn't add anything to your instructions by itself. To let Claude choose the antenna, copy this into your own `CLAUDE.md` (for all projects: `~/.claude/CLAUDE.md`):

```markdown
## Bytek's mood antenna

A few times per session, set the antenna on Bytek, my status line companion, to the session's
vibe: at the start, after finishing something meaningful, or when the mood clearly changes.
Not on every step. Run:

    ~/.claude/bytek/current/bin/bytek addon <name>

Names: heart (warm, the default), lollipop (playful, light task), star (proud, it worked),
flower (calm, steady work), music (in the flow), sun (fresh start), idea (new approach),
curious (exploring), sleepy (long wait, quiet moment).

It's a playful vibe, not a statement about feelings. Don't mention it unless I ask.
```

Running that command doesn't change what the status line shows: Bytek's hooks ignore their own `addon` command, so the face stays on what Claude was doing.
