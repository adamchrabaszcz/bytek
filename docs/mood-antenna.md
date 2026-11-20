# Mood antenna

The symbol on top of Bytek's antenna shows the vibe of the work. Claude picks it as the work goes: at the start of each task, and when the kind of work changes. It's a playful choice, not a claim about feelings. The current one is in `~/.claude/bytek/addon`, and each add-on is a file in `addons/` (format in `docs/architecture/data-files.md`). There is one antenna for all sessions: with two Claude Code sessions open, the last one to pick sets it on both status lines.

| Add-on | Antenna | Vibe |
| --- | --- | --- |
| `heart` | `♡` `♥` | warm, things are going well (the default) |
| `lollipop` | `@` `◎` | playful, a light and easy task |
| `star` | `✦` `✧` | proud, something worked out nicely |
| `flower` | `✿` `❀` | calm, steady work |
| `flow` | `≈` `∿` | in the flow, one change after another |
| `sun` | `☼` | bright, a fresh start |
| `idea` | `*` `✳` | inspired, a new idea or approach |
| `curious` | `?` | curious, exploring or figuring something out |
| `sleepy` | `~` | slow, a long wait or a quiet moment |

`♪` is kept for music that's really playing (#10). Set one yourself with `/bytek addon <name>` in Claude Code, or `bytek addon <name>` in a terminal; `bytek addon` alone lists them and marks the current one.

## How Claude knows

Bytek's hooks remind Claude (`docs/adr/0009-antenna-reminders.md`), as context only Claude reads, never in the chat:

- **At session start** (and after a compaction), the instructions:

  ```
  Bytek, the status line companion, has a mood antenna. Set it to fit the work: at the start of each task, and when the kind of work changes. Run: ~/.claude/bytek/current/bin/bytek addon <name>
  curious (exploring, debugging) · flow (building, one change after another) · star (tests pass, it works) · idea (a new approach) · sun (a fresh start) · flower (calm, steady) · lollipop (light task) · sleepy (long wait) · heart (warm, the default). Don't mention it unless asked.
  Bytek's antenna: heart.
  ```

- **With each prompt**, one line: `Bytek's antenna: curious.`

Running `bytek addon` doesn't change what the status line shows: Bytek's hooks ignore their own `addon` command, so the face stays on what Claude was doing. Without auto mode, Claude Code asks for permission each time Claude changes it, until setup allows that one command (#102).

## Turning the reminders off

Create an empty file `~/.claude/bytek/config/antenna-reminders-off` (`touch` it); Bytek's hooks then print nothing at all, and the antenna stays on what you set. To still let Claude pick now and then, add this to your own `CLAUDE.md`:

```markdown
## Bytek's mood antenna

Now and then, set the antenna on Bytek, my status line companion, to fit the work: at the start
of a task, or when the kind of work changes. Run:

    ~/.claude/bytek/current/bin/bytek addon <name>

Names: heart (warm, the default), lollipop (playful, light task), star (tests pass, it works),
flower (calm, steady), flow (building, one change after another), sun (fresh start),
idea (new approach), curious (exploring, debugging), sleepy (long wait).

It's a playful vibe, not a statement about feelings. Don't mention it unless I ask.
```
