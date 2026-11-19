# What the debug log keeps of a hook event: its shape and metadata, never what was said or
# written. Prompts, file contents and edit text are dropped; tool output becomes its key names.
# Input: hook JSON from Claude Code.

del(.prompt, .tool_input.content, .tool_input.old_string, .tool_input.new_string,
    .tool_input.edits, .tool_input.new_source)
| if has("tool_response") then
    .tool_response |= (if type == "object" then keys else type end)
  else . end
