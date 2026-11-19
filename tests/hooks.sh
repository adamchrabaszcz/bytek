#!/usr/bin/env bash
# Feeds hook events to `bytek hook` and checks the state it writes.
# Usage: tests/hooks.sh

export LC_ALL=en_US.UTF-8
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BYTEK="$ROOT/bin/bytek"
export BYTEK_HOME
BYTEK_HOME=$(mktemp -d)
trap 'rm -rf "$BYTEK_HOME"' EXIT
STATE="$BYTEK_HOME/state/s1"

fails=0
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; fails=$((fails + 1)); }

# hook <now> <json fields without braces>
hook() {
  printf '{"session_id":"s1","cwd":"/repo",%s}' "$2" | BYTEK_NOW=$1 "$BYTEK" hook
}
expect() { # name key value
  local got
  got=$(sed -n "s/^$2=//p" "$STATE")
  [ "$got" = "$3" ] || fail "$1" "$2: expected '$3', got '$got'"
}
render() { printf '{"session_id":"s1"}' | BYTEK_NOW=${1:-1000} "$BYTEK" render; }

command -v jq >/dev/null || { echo "skip: jq not installed"; exit 0; }

hook 1000 '"hook_event_name":"SessionStart"'
expect session-start state idle

hook 1000 '"hook_event_name":"UserPromptSubmit","prompt":"hi"'
expect prompt state thinking
expect prompt turn_start 1000

hook 1001 '"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/repo/src/api.ts"}'
expect read state reading
expect read arg src/api.ts

hook 1002 '"hook_event_name":"PreToolUse","tool_name":"Grep","tool_input":{"pattern":"TODO"}'
expect grep state searching
expect grep arg TODO

hook 1003 '"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/a.ts"}'
hook 1004 '"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/b.ts"}'
hook 1005 '"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/repo/a.ts"}'
expect edit state editing
expect edit edits 3
expect edit status "editing 2 files"

hook 1006 '"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm test -- --watch=false"}'
expect test-start state testing
hook 1007 '"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"npm test"},"tool_response":{}'
expect test-pass status "tests passed"

hook 1008 '"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"go test ./..."}'
hook 1009 '"hook_event_name":"PostToolUseFailure","tool_name":"Bash","error":"exit 1: 2 failing"'
expect test-fail state error
expect test-fail status "tests failed"
expect test-fail arg "exit 1: 2 failing"

hook 1010 '"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status"}'
expect bash state thinking
expect bash detail '$ git status'

hook 1011 '"hook_event_name":"PermissionRequest","tool_name":"Edit","tool_input":{"file_path":"/repo/.env"}'
expect permission state waiting
expect permission arg "allow Edit .env?"
hook 1012 '"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/.env"},"tool_response":{}'
expect permission-granted state thinking

hook 1013 '"hook_event_name":"Notification","message":"Claude needs your permission to use Bash","notification_type":"permission_prompt"'
expect notification state waiting
hook 1014 '"hook_event_name":"Notification","message":"Claude is waiting for your input","notification_type":"idle_prompt"'
expect idle-notification state waiting

hook 1041 '"hook_event_name":"Stop"'
expect stop state done
expect stop arg "3 changes · 41s"
case "$(render 1041)" in *"3 changes · 41s"*) ;; *) fail stop-render "summary not shown" ;; esac

hook 1050 '"hook_event_name":"PreToolUse","tool_name":"mcp__sentry__search_issues","tool_input":{}'
expect mcp status "using sentry"

# Hooks print nothing (stdout of some hooks would reach Claude's context) and always exit 0.
out=$(printf 'not json' | "$BYTEK" hook); code=$?
[ -z "$out" ] && [ "$code" -eq 0 ] || fail garbage "printed '$out' or exited $code"
out=$(hook 1060 '"hook_event_name":"UserPromptSubmit"')
[ -z "$out" ] || fail quiet "UserPromptSubmit printed '$out'"

hook 1100 '"hook_event_name":"SessionEnd"'
[ ! -f "$STATE" ] || fail session-end "state file not removed"

if [ "$fails" -eq 0 ]; then echo "ok: hooks map events to states"; else echo "$fails failure(s)"; exit 1; fi
