# Reads the status line setup saved (original-statusline.json), for uninstall to put back.
# Format 1 is {"format": 1, "statusLine": ...}. A file from before formats existed holds the
# status line itself (or null). A newer format isn't read: "known" is false, and uninstall
# leaves the file alone and puts nothing back.
# Input: original-statusline.json. Output: {"known": true|false, "statusLine": ...}.

if type == "object" and has("format") then
  if .format == 1 then {known: true, statusLine: .statusLine}
  else {known: false, statusLine: null} end
else {known: true, statusLine: .} end
