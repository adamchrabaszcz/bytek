# Puts back the status line Bytek replaced ($saved, or none), but only while the current one
# is still Bytek's: one set later by someone else stays. Removes only Bytek's hooks, then any
# events and the hooks key left empty.
# Input: settings.json. Args: $saved (status line or null), $bytek_re (matches a command that runs Bytek),
# $antenna_rule (the permission setup added).

def runs_bytek: (.command // "") | test($bytek_re);

# An event's matcher groups without Bytek's hooks; a group that held only Bytek goes too,
# other hooks in a shared group stay, and groups without a hooks list are left as they are.
def without_bytek:
  map(if (.hooks | type) == "array"
      then .hooks |= map(select(runs_bytek | not)) | select(.hooks | length > 0)
      else . end);

if ((.statusLine.command // "") | test($bytek_re)) then
  (if $saved == null then del(.statusLine) else .statusLine = $saved end)
else . end
| if has("hooks") then
    .hooks |= (map_values(without_bytek) | with_entries(select(.value | length > 0)))
    | if .hooks == {} then del(.hooks) else . end
  else . end
# Only Bytek's own permission rule goes; an allow list (or permissions) left empty by that goes
# too, so settings are what they were before setup.
| if ((.permissions // {}) | type) == "object" and (.permissions.allow | type) == "array" then
    .permissions.allow |= map(select(. != $antenna_rule))
    | if .permissions.allow == [] then del(.permissions.allow) else . end
    | if .permissions == {} then del(.permissions) else . end
  else . end
