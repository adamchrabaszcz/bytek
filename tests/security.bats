#!/usr/bin/env bats
# Security hardening: no terminal control sequences from hook text or `bytek set`, a private
# and bounded debug log, pinned GitHub Actions, Dependabot and SECURITY.md.

load helpers

setup() {
  bytek_setup
  needs_jq
  hook '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"hi"}'
}

# Escape sequences: title change (OSC), colour and screen clear (CSI), a hyperlink (OSC 8),
# BEL and a C1 CSI, as JSON escapes the way Claude Code sends them.
EVIL='x\u001b]0;pwned\u0007\u001b[31m\u001b[2J\u001b]8;;https://evil.example\u001b\\link\u009b1A\u0007y'

# Fails when $1 holds a control character other than newlines and Bytek's own dim / reset codes.
refute_controls() {
  local rest
  rest=$(printf '%s' "$1" | sed -e $'s/\033\\[2m//g' -e $'s/\033\\[0m//g' | tr -d '\n')
  if printf '%s' "$rest" | LC_ALL=C grep -q $'[\001-\037\177]'; then
    fail "control character in output: $(printf '%s' "$rest" | od -c | head -3 | tr '\n' ' ')"
  fi
  case "$rest" in *$'\xc2\x9b'* | *$'\xc2\x9d'*) fail "C1 control (CSI/OSC) in output" ;; esac
}

@test "escape sequences in a file path don't reach the terminal" {
  hook "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"s1\",\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"/r/$EVIL.ts\"}}"
  refute_controls "$(render s1)"
}

@test "escape sequences in a search pattern don't reach the terminal" {
  hook "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"s1\",\"tool_name\":\"Grep\",\"tool_input\":{\"pattern\":\"$EVIL\"}}"
  refute_controls "$(render s1)"
}

@test "escape sequences in a command don't reach the terminal" {
  hook "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"s1\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo $EVIL\"}}"
  refute_controls "$(render s1)"
}

@test "escape sequences in a notification don't reach the terminal" {
  hook "{\"hook_event_name\":\"Notification\",\"session_id\":\"s1\",\"message\":\"$EVIL\",\"notification_type\":\"permission_prompt\"}"
  refute_controls "$(render s1)"
}

@test "escape sequences in an error don't reach the terminal, the text stays" {
  hook "{\"hook_event_name\":\"PostToolUseFailure\",\"session_id\":\"s1\",\"tool_name\":\"Bash\",\"error\":\"$EVIL\"}"
  run render s1
  refute_controls "$output"
  assert_output --regexp 'pwned.*link'
  ! LC_ALL=C grep -q $'[\001-\011\013-\037\177]' "$BYTEK_HOME/state/s1" || fail "control characters stored in the state file"
}

@test "bytek set drops control characters too" {
  "$BYTEK" set waiting $'allow \033]0;pwned\007 this?' --status $'\033[2Jneeds you' --session s1
  refute_controls "$(render s1)"
}

@test "the debug log is off by default" {
  hook '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"secret-prompt"}'
  [ ! -e "$BYTEK_HOME/hooks.log" ] || fail "log written without the debug switch"
}

@test "the debug log keeps metadata but no prompts or file contents, user-only" {
  touch "$BYTEK_HOME/debug"
  hook '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"secret-prompt"}'
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Write","tool_input":{"file_path":"/r/a.env","content":"secret-content"}}'
  hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"/r/a.ts","old_string":"secret-old","new_string":"secret-new"}}'
  hook '{"hook_event_name":"PostToolUse","session_id":"s1","tool_name":"Read","tool_input":{"file_path":"/r/a.ts"},"tool_response":{"file":{"content":"secret-read"}}}'
  local log="$BYTEK_HOME/hooks.log"
  ! grep -q 'secret-' "$log" || fail "log holds prompt or file content: $(grep -o 'secret-[a-z]*' "$log" | sort -u | tr '\n' ' ')"
  grep -q '"hook_event_name":"PreToolUse"' "$log" || fail "log lost the event metadata"
  grep -q '"tool_response":\["file"\]' "$log" || fail "tool output should be reduced to its key names"
  # shellcheck disable=SC2012 # ls -l is the portable way to read permissions; stat differs on macOS and Linux
  assert_equal "$(ls -l "$log" | cut -c1-10)" "-rw-------"
}

@test "the debug log stays within its size limit as whole lines" {
  touch "$BYTEK_HOME/debug"
  local i=0 log="$BYTEK_HOME/hooks.log"
  while [ $i -lt 60 ]; do
    printf '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Read","tool_input":{"file_path":"/r/%040d.ts"}}' $i |
      BYTEK_DEBUG_LOG_MAX=2000 "$BYTEK" hook
    i=$((i + 1))
  done
  [ "$(($(wc -c <"$log")))" -le 2000 ] || fail "log grew past its 2000 byte limit"
  jq -c . "$log" >/dev/null 2>&1 || fail "trimming left a broken line"
}

@test "GitHub Actions are pinned to commit SHAs with the version noted" {
  local line
  while IFS= read -r line; do
    case "$line" in *uses:*) ;; *) continue ;; esac
    [[ "$line" =~ uses:\ [A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40}\ \#\ v[0-9]+ ]] || fail "not pinned: $line"
  done < <(cat "$ROOT"/.github/workflows/*.yml)
}

@test "Dependabot updates actions and SECURITY.md explains reporting" {
  grep -q 'package-ecosystem: github-actions' "$ROOT/.github/dependabot.yml"
  grep -q 'Report a vulnerability' "$ROOT/SECURITY.md"
}
