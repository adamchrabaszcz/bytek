# Makes Bytek the status line (keeping padding) and, with $with_hooks, adds its hooks to
# every event next to the user's own, replacing any earlier Bytek hooks.
# Input: settings.json. Args: $render, $hook (commands), $with_hooks (bool), $antenna_rule,
# $plugin (hooks/hooks.json, slurped), $bytek_re (matches a command that runs Bytek).

def runs_bytek: (.command // "") | test($bytek_re);

# An event's matcher groups without Bytek's hooks; a group that held only Bytek goes too,
# other hooks in a shared group stay, and groups without a hooks list are left as they are.
def without_bytek:
  map(if (.hooks | type) == "array"
      then .hooks |= map(select(runs_bytek | not)) | select(.hooks | length > 0)
      else . end);

.statusLine = {type: "command", command: $render, padding: (.statusLine.padding // 0), refreshInterval: 1}
| if $with_hooks then
    ($plugin[0].hooks | map_values(map(.hooks |= map(.command = $hook)))) as $ours
    | .hooks = reduce ($ours | to_entries[]) as $e (.hooks // {};
        .[$e.key] = ((.[$e.key] // []) | without_bytek) + $e.value)
  else . end
# Claude may set the mood antenna without a permission prompt each time: $antenna_rule, once,
# next to the user's own rules.
| .permissions.allow = ((.permissions.allow // []) | if any(. == $antenna_rule) then . else . + [$antenna_rule] end)
