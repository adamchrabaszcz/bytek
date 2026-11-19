# The status line Bytek is about to replace, or null when there is none or it is Bytek's own.
# Input: settings.json. Args: $bytek_re (matches a command that runs Bytek).

.statusLine // null
| if . != null and ((.command // "") | test($bytek_re)) then null else . end
