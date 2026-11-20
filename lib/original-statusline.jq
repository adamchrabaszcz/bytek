# The status line Bytek is about to replace, saved as {"format": 1, "statusLine": ...}; the
# status line is null when there is none or it is Bytek's own (format: docs/architecture/data-files.md).
# Input: settings.json. Args: $bytek_re (matches a command that runs Bytek).

{
  format: 1,
  statusLine: (
    .statusLine // null
    | if . != null and ((.command // "") | test($bytek_re)) then null else . end
  )
}
