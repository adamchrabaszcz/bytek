# The hook fields Bytek uses, on one line, joined by the unit separator (\u001f) for bash `read`.
# This text ends up in the user's terminal, so line breaks and tabs become spaces and every
# other control character (C0, DEL, C1, the separator itself) is removed: no escape sequences.
# Input: hook JSON from Claude Code.

[
  .hook_event_name, .session_id, .tool_name,
  (.tool_input.file_path // .tool_input.notebook_path),
  .tool_input.pattern, .tool_input.command, .message, .notification_type,
  (.error // (if (.tool_response | type) == "object" then .tool_response.error else null end)),
  .cwd
]
| map(. // "" | tostring | gsub("[\n\r\t]"; " ") | gsub("[\u0000-\u001f\u007f-\u009f]"; ""))
| join("\u001f")
