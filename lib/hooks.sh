# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154 # S_<key> belongs to lib/state.sh: read here, written by state_write
# hooks: turns Claude Code's hook events into states. Never prints anything: stdout from some
# hooks (UserPromptSubmit, SessionStart) would be added to Claude's context.
# Needs: clock, state; from bin/bytek: BYTEK_ROOT, BYTEK_HOME.

# Bytek's own command Claude runs to set the mood antenna, alone: "[path/]bytek addon <name>".
# Combined with anything else (&&, ;, |), the command shows as usual.
HOOKS_OWN_RE='^[[:space:]]*[^[:space:];&|]*bytek"?[[:space:]]+addon([[:space:]]+[a-z-]+)?[[:space:]]*$'

# Bash commands that count as running tests (extended regex, override with BYTEK_TEST_PATTERN).
HOOKS_TEST_RE=${BYTEK_TEST_PATTERN:-'(^|[;&|(]|[[:space:]])(npm (run )?test|npm t|yarn (run )?test|pnpm (run )?test|bun test|npx (jest|vitest|mocha)|jest|vitest|mocha|pytest|python3? -m (pytest|unittest)|(vendor/bin/)?(phpunit|pest)|go test|cargo test|mvn.* (test|verify)|(\./)?gradlew? test|rspec|mix test|dotnet test|node --test|deno test|make (test|check)|[^[:space:]]*tests?/[^[:space:]]*\.sh)'}

# Appends a trimmed copy of hook JSON $1 to hooks.log, only while ~/.claude/bytek/debug exists
# (and jq is there): no prompts or file contents (lib/debug-log.jq), readable by the user only,
# cut back to half when it grows past BYTEK_DEBUG_LOG_MAX bytes (default 1 MB).
hooks_debug_log() {
  [ -f "$BYTEK_HOME/debug" ] && command -v jq >/dev/null 2>&1 || return 0
  (
    umask 077
    log="$BYTEK_HOME/hooks.log" max=${BYTEK_DEBUG_LOG_MAX:-1048576}
    printf '%s' "$1" | jq -c -f "$BYTEK_ROOT/lib/debug-log.jq" >>"$log" || exit 0
    if [ $(($(wc -c <"$log"))) -gt "$max" ]; then
      tail -c $((max / 2)) "$log" | sed 1d >"$log.tmp" && mv "$log.tmp" "$log"
    fi
  ) 2>/dev/null
}

# The status line runs ~/.claude/bytek/current/bin/bytek. A plugin update installs into a
# new folder, so when the hook runs from the plugin and `current` points at another plugin
# folder (or nowhere), move it here. A link to a checkout or a manual install is left alone.
hooks_follow_plugin_update() {
  local link="$BYTEK_HOME/current" target
  [ -n "$CLAUDE_PLUGIN_ROOT" ] || return 0
  target=$(cd -P "$link" 2>/dev/null && pwd -P)
  if [ -z "$target" ] || { [ "$target" != "$BYTEK_ROOT" ] && case "$target" in */.claude/plugins/*) true ;; *) false ;; esac } then
    mkdir -p "$BYTEK_HOME" && ln -sfn "$BYTEK_ROOT" "$link"
  fi
}

# Maps the hook event in JSON on stdin to a state and writes it.
hooks_handle() {
  local json event="" session="" tool="" file="" pattern="" cmd="" message="" ntype="" err="" cwd=""
  local f re
  json=$(cat)
  if command -v jq >/dev/null 2>&1; then
    IFS=$'\037' read -r event session tool file pattern cmd message ntype err cwd <<EOF
$(printf '%s' "$json" | jq -r -f "$BYTEK_ROOT/lib/hook-fields.jq")
EOF
  else
    re='"hook_event_name"[[:space:]]*:[[:space:]]*"([A-Za-z]+)"'
    [[ "$json" =~ $re ]] && event=${BASH_REMATCH[1]}
    re='"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_-]+)"'
    [[ "$json" =~ $re ]] && session=${BASH_REMATCH[1]}
    re='"tool_name"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_]+)"'
    [[ "$json" =~ $re ]] && tool=${BASH_REMATCH[1]}
  fi
  hooks_debug_log "$json"

  [[ "$session" =~ ^[A-Za-z0-9_-]+$ ]] || session=default
  f="$BYTEK_HOME/state/$session"
  [ -n "$cwd" ] && file=${file#"$cwd"/}

  hooks_apply
  return 0
}

# Applies the event to the state file. Reads what hooks_handle parsed (event, tool, file,
# pattern, cmd, message, ntype, err, f): bash locals are visible to the functions they call.
# Hooks may run at the same moment: the last one's state wins, and edits go to the edit list,
# where none get lost (lib/state.sh).
hooks_apply() {
  local now n
  clock_now
  now=$REPLY
  state_load "$f"
  # Written by a newer Bytek, in a format this one doesn't know: leave it as it is.
  [ -n "$STATE_NEWER" ] && return 0

  case "$event" in
    SessionStart)
      state_to idle
      S_turn_start=""
      state_clear_edits "$f"
      hooks_follow_plugin_update
      find "$BYTEK_HOME/state" -type f -mtime +7 -delete 2>/dev/null
      ;;
    SessionEnd)
      rm -f "$f"
      state_clear_edits "$f"
      return 0
      ;;
    UserPromptSubmit)
      state_to thinking
      S_turn_start=$now
      state_clear_edits "$f"
      ;;
    PreToolUse)
      case "$tool" in
        Read) state_to reading "$file" ;;
        Grep | Glob) state_to searching "$pattern" ;;
        Edit | Write | MultiEdit | NotebookEdit)
          state_add_edit "$f" "$file"
          state_count_edits "$f"
          if [ "$STATE_FILES" -gt 1 ]; then
            state_to editing "$file" "editing $STATE_FILES files"
          else state_to editing "$file"; fi
          ;;
        Bash)
          # Claude setting the mood antenna isn't news for the status line: keep the face.
          [[ "$cmd" =~ $HOOKS_OWN_RE ]] && return 0
          if [[ "$cmd" =~ $HOOKS_TEST_RE ]]; then
            state_to testing
          else state_to thinking "" "running a command" "\$ $cmd"; fi
          ;;
        mcp__*)
          n=${tool#mcp__}
          state_to thinking "" "using ${n%%__*}"
          ;;
        *) state_to thinking "" "using $tool" ;;
      esac
      ;;
    PostToolUse)
      if [ "$S_state" = testing ]; then
        state_to thinking "" "tests passed" "✓ tests passed"
      elif [ "$S_state" = waiting ]; then state_to thinking; fi
      ;;
    PostToolUseFailure)
      if [ "$S_state" = testing ]; then
        state_to error "$err" "tests failed"
      else state_to error "$err" "$tool failed"; fi
      ;;
    PermissionRequest)
      state_to waiting "allow $tool${file:+ $file}${cmd:+ $cmd}?"
      ;;
    PermissionDenied)
      state_to thinking
      ;;
    Notification)
      # "Waiting for your input" after a finished turn is not a question; keep the state.
      case "$ntype$message" in idle_prompt* | *"waiting for your input"*) return 0 ;; esac
      state_to waiting "$message"
      ;;
    Stop)
      clock_duration $((now - ${S_turn_start:-$now}))
      state_count_edits "$f"
      if [ "$STATE_EDITS" -gt 0 ]; then state_to "done" "$STATE_EDITS changes · $REPLY"; else state_to "done" "$REPLY"; fi
      ;;
    *)
      return 0
      ;;
  esac
  S_since=$now
  state_write "$f"
}
