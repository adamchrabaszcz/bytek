#!/usr/bin/env bash
# Checks the security hardening: no terminal control sequences from hook text or `bytek set`,
# a private and bounded debug log, pinned GitHub Actions, Dependabot and SECURITY.md.
# Usage: tests/security.sh

export LC_ALL=en_US.UTF-8
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BYTEK="$ROOT/bin/bytek"
export BYTEK_HOME
BYTEK_HOME=$(mktemp -d)
trap 'rm -rf "$BYTEK_HOME"' EXIT

fails=0
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; fails=$((fails + 1)); }

command -v jq >/dev/null || { echo "skip: jq not installed"; exit 0; }

hook() { printf '%s' "$1" | "$BYTEK" hook; }
render() { printf '{"session_id":"s1"}' | "$BYTEK" render; }

# Fails when the output holds a control character other than newlines and Bytek's own
# dim / reset codes (ESC[2m, ESC[0m).
no_controls() { # name output
  local rest
  rest=$(printf '%s' "$2" | sed -e $'s/\033\\[2m//g' -e $'s/\033\\[0m//g' | tr -d '\n')
  if printf '%s' "$rest" | LC_ALL=C grep -q $'[\001-\037\177]'; then
    fail "$1" "control character in output: $(printf '%s' "$rest" | od -c | head -3 | tr '\n' ' ')"
  fi
  case "$rest" in *$'\xc2\x9b'*|*$'\xc2\x9d'*) fail "$1" "C1 control (CSI/OSC) in output" ;; esac
}

# Escape sequences hidden in every text field a hook stores: title change (OSC), colour and
# cursor movement (CSI), a hyperlink, BEL, and C1 CSI. JSON escapes, as Claude Code sends them.
evil='x\u001b]0;pwned\u0007\u001b[31m\u001b[2J\u001b]8;;https://evil.example\u001b\\link\u009b1A\u0007y'
hook '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"hi"}'
hook "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"s1\",\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"/r/$evil.ts\"}}"
no_controls read-path "$(render)"
hook "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"s1\",\"tool_name\":\"Grep\",\"tool_input\":{\"pattern\":\"$evil\"}}"
no_controls grep-pattern "$(render)"
hook "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"s1\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo $evil\"}}"
no_controls bash-command "$(render)"
hook "{\"hook_event_name\":\"Notification\",\"session_id\":\"s1\",\"message\":\"$evil\",\"notification_type\":\"permission_prompt\"}"
no_controls notification "$(render)"
hook "{\"hook_event_name\":\"PostToolUseFailure\",\"session_id\":\"s1\",\"tool_name\":\"Bash\",\"error\":\"$evil\"}"
no_controls error "$(render)"
case "$(render)" in *pwned*link*) ;; *) fail visible-text "the printable text should stay: $(render)" ;; esac
LC_ALL=C grep -q $'[\001-\011\013-\037\177]' "$BYTEK_HOME/state/s1" && fail state-file "control characters stored in the state file"

# bytek set takes text from the command line: same rule.
"$BYTEK" set waiting $'allow \033]0;pwned\007 this?' --status $'\033[2Jneeds you' --session s1
no_controls set "$(render)"

# Debug log: off by default; when on, no prompts or file contents, private, bounded.
hook '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"secret-prompt"}'
[ ! -e "$BYTEK_HOME/hooks.log" ] || fail debug-off "log written without the debug switch"
touch "$BYTEK_HOME/debug"
hook '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"secret-prompt"}'
hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Write","tool_input":{"file_path":"/r/a.env","content":"secret-content"}}'
hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"/r/a.ts","old_string":"secret-old","new_string":"secret-new"}}'
hook '{"hook_event_name":"PostToolUse","session_id":"s1","tool_name":"Read","tool_input":{"file_path":"/r/a.ts"},"tool_response":{"file":{"content":"secret-read"}}}'
log="$BYTEK_HOME/hooks.log"
grep -q 'secret-' "$log" && fail debug-private "log holds prompt or file content: $(grep -o 'secret-[a-z]*' "$log" | sort -u | tr '\n' ' ')"
grep -q '"hook_event_name":"PreToolUse"' "$log" || fail debug-useful "log lost the event metadata"
grep -q '"tool_response":\["file"\]' "$log" || fail debug-useful "tool output should be reduced to its key names"
mode=$(ls -l "$log" | cut -c1-10)
[ "$mode" = "-rw-------" ] || fail debug-mode "log should be readable by the user only, is $mode"
i=0
while [ $i -lt 60 ]; do
  printf '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Read","tool_input":{"file_path":"/r/%040d.ts"}}' $i \
    | BYTEK_DEBUG_LOG_MAX=2000 "$BYTEK" hook
  i=$((i + 1))
done
size=$(( $(wc -c < "$log") ))
[ "$size" -le 2000 ] || fail debug-size "log grew to $size bytes past its 2000 byte limit"
jq -c . "$log" >/dev/null 2>&1 || fail debug-lines "trimming left a broken line"
rm -f "$BYTEK_HOME/debug"

# GitHub Actions pinned to full commit SHAs with the version in a comment.
while IFS= read -r line; do
  case "$line" in *uses:*) ;; *) continue ;; esac
  [[ "$line" =~ uses:\ [A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40}\ \#\ v[0-9]+ ]] || fail pin "not pinned: $line"
done < <(cat "$ROOT"/.github/workflows/*.yml)

grep -q 'package-ecosystem: github-actions' "$ROOT/.github/dependabot.yml" 2>/dev/null || fail dependabot "no Dependabot updates for GitHub Actions"
grep -q 'Report a vulnerability' "$ROOT/SECURITY.md" 2>/dev/null || fail security-md "SECURITY.md missing or without reporting steps"

if [ "$fails" -eq 0 ]; then echo "ok: no escape sequences reach the terminal, debug log private, actions pinned"; else echo "$fails failure(s)"; exit 1; fi
