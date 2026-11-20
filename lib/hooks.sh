# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154 # S_<key> belongs to lib/state.sh: read here, written by state_write
# hooks: turns Claude Code's hook events into states. Never prints anything: stdout from some
# hooks (UserPromptSubmit, SessionStart) would be added to Claude's context.
# Needs: clock, state; from bin/bytek: BYTEK_ROOT, BYTEK_HOME.

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

  # Read, change and write the state under the session's lock, so a hook running at the same
  # moment can't overwrite this update. Without the lock after the wait, go ahead anyway, and
  # never release a lock that belongs to another hook.
  local locked=""
  state_lock "$f" && locked=1
  hooks_apply
  [ -n "$locked" ] && state_unlock "$f"
  return 0
}

# Applies the event to the state file. Reads what hooks_handle parsed (event, tool, file,
# pattern, cmd, message, ntype, err, f): bash locals are visible to the functions they call.
hooks_apply() {
  local now n
  clock_now
  now=$REPLY
  state_load "$f"

  case "$event" in
    SessionStart)
      state_to idle
      S_turn_start="" S_edits="" S_files=""
      hooks_follow_plugin_update
      find "$BYTEK_HOME/state" -type f -mtime +7 -delete 2>/dev/null
      ;;
    SessionEnd)
      rm -f "$f"
      return 0
      ;;
    UserPromptSubmit)
      state_to thinking
      S_turn_start=$now S_edits=0 S_files=""
      ;;
    PreToolUse)
      case "$tool" in
        Read) state_to reading "$file" ;;
        Grep | Glob) state_to searching "$pattern" ;;
        Edit | Write | MultiEdit | NotebookEdit)
          S_edits=$((${S_edits:-0} + 1))
          case "${S_files:-|}" in *"|$file|"*) ;; *) S_files="${S_files:-|}$file|" ;; esac
          n=${S_files//[!|]/}
          n=$((${#n} - 1))
          if [ "$n" -gt 1 ]; then state_to editing "$file" "editing $n files"; else state_to editing "$file"; fi
          ;;
        Bash)
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
      if [ "${S_edits:-0}" -gt 0 ]; then state_to "done" "$S_edits changes · $REPLY"; else state_to "done" "$REPLY"; fi
      ;;
    *)
      return 0
      ;;
  esac
  S_since=$now
  state_write "$f"
}
