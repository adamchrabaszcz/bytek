---
description: Control Bytek, the status line companion (setup, uninstall, doctor, preview, config, addon, charset, name, done, skip, set, states, help)
argument-hint: "[setup | uninstall | doctor | preview [--state S | --addon A | --routine dog:due] | config [part [on | off] | reset] | addon [name] | charset [unicode | ascii] | name [companion [Name]] | done <routine> | skip <routine> | set <state> [text] | states | help]"
---

When the arguments are exactly `config`, show the settings screen (below). Otherwise run this command with the Bash tool, exactly as written, with the user's arguments in place of `$ARGUMENTS` (use `help` when there are none):

```
"${CLAUDE_PLUGIN_ROOT}/bin/bytek" $ARGUMENTS
```

Show the output to the user in a code block, without commentary. If it fails, show the error and one line on what to do. Don't run anything else and don't change any file yourself.

## The settings screen (`/bytek config`)

1. Run `"${CLAUDE_PLUGIN_ROOT}/bin/bytek" config`. It prints each part of Bytek as `part: on` or `part: off`.
2. Ask with the AskUserQuestion tool, two questions, both with `multiSelect: true`, the options' labels being the parts' names exactly:
   - **Look** ("Which parts should show?"): `box` (the box around the face; off: Bytek on one line), `antenna` (Claude changes the mood antenna as the work goes; off: it stays at ♡), `thought` (the thought bubble next to the antenna).
   - **Extras** ("Which extras should show?"): `companions` (a companion next to Bytek for a routine's reminder; off: the reminder as text with ◷), `reminders` (routine reminders on the status line).

   Start each option's description with `(on now)` or `(off now)`, from step 1. A ticked part is on afterwards, an unticked one off.
3. For each part whose value changes, run `"${CLAUDE_PLUGIN_ROOT}/bin/bytek" config <part> on` or `off`. Change nothing else, and run nothing if nothing changes.
4. Run `"${CLAUDE_PLUGIN_ROOT}/bin/bytek" config` again and show its output in a code block, with one line saying the status line shows the change from its next refresh.

If the user skips the questions or answers something else, change nothing.
