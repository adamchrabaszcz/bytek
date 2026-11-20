# shellcheck shell=bash
# doctor: `bytek doctor` checks an installation and says what to fix, for people whose Bytek
# doesn't show up and for bug reports. It reads settings.json only to see whether Bytek is in
# it, and never prints anything from it (it can hold secrets).
# Needs: settings (SETTINGS_CMD_RE); from bin/bytek: BYTEK_ROOT, BYTEK_HOME, BYTEK_SETTINGS,
# BYTEK_UTF8, and $0 (the bytek it times).

DOCTOR_BUDGET_MS=50 # the render budget (tests/speed.bats)
DOCTOR_PROBLEMS=0

# Prints one result: doctor_say ok|warning|problem <what> [<how to fix it>]. A problem makes
# `bytek doctor` exit 1.
doctor_say() {
  printf '%-8s %s\n' "$1" "$2"
  [ -n "$3" ] && printf '         → %s\n' "$3"
  [ "$1" = problem ] && DOCTOR_PROBLEMS=$((DOCTOR_PROBLEMS + 1))
  return 0
}

# Runs every check; returns 1 when at least one found a problem.
doctor_run() {
  DOCTOR_PROBLEMS=0
  doctor_versions
  doctor_jq
  doctor_locale
  doctor_settings
  doctor_state_folder
  doctor_render_time
  [ "$DOCTOR_PROBLEMS" -eq 0 ]
}

doctor_versions() {
  local claude
  doctor_say ok "bash ${BASH_VERSION%%(*}"
  if claude=$(claude --version 2>/dev/null) && [ -n "$claude" ]; then
    doctor_say ok "Claude Code ${claude%% *}"
  else
    doctor_say warning "Claude Code not found on PATH (fine if it runs from an app)"
  fi
}

doctor_jq() {
  if command -v jq >/dev/null 2>&1; then
    doctor_say ok "$(jq --version 2>/dev/null)"
  else
    doctor_say problem "jq is missing: hooks only see the event name, setup can't run" "install jq: https://jqlang.org (macOS: brew install jq)"
  fi
}

doctor_locale() {
  if [ "$BYTEK_UTF8" = 1 ]; then
    doctor_say ok "locale $LC_ALL counts characters"
  else
    doctor_say warning "no UTF-8 locale: long text isn't cut to the window" "set BYTEK_LOCALE to a UTF-8 locale that \`locale -a\` lists"
  fi
}

# The status line, the hooks and the current link, as far as settings.json shows them.
doctor_settings() {
  local command uses
  if [ ! -f "$BYTEK_SETTINGS" ]; then
    doctor_say problem "no $BYTEK_SETTINGS" "run: bytek setup"
    return
  fi
  command -v jq >/dev/null 2>&1 || {
    doctor_say warning "can't read $BYTEK_SETTINGS without jq"
    return
  }
  if ! jq -e 'type == "object"' "$BYTEK_SETTINGS" >/dev/null 2>&1; then
    doctor_say problem "$BYTEK_SETTINGS isn't a JSON object" "fix the file (backups are in $BYTEK_HOME/backup/)"
    return
  fi

  command=$(jq -r '.statusLine.command // ""' "$BYTEK_SETTINGS")
  if [[ "$command" =~ $SETTINGS_CMD_RE ]]; then
    doctor_say ok "the status line runs Bytek"
  else
    doctor_say problem "the status line doesn't run Bytek" "run: bytek setup"
  fi

  if jq -e 'any(.enabledPlugins // {} | to_entries[]; (.key | startswith("bytek@")) and .value == true)' "$BYTEK_SETTINGS" >/dev/null 2>&1; then
    doctor_say ok "hooks come from the Bytek plugin"
  elif uses=$(jq --arg re "$SETTINGS_CMD_RE" '[.hooks // {} | .[] | .[]? | .hooks[]? | select((.command // "") | test($re))] | length' "$BYTEK_SETTINGS" 2>/dev/null) && [ "${uses:-0}" -gt 0 ]; then
    doctor_say ok "hooks run Bytek on $uses events"
  else
    doctor_say problem "no hooks run Bytek: it won't follow what Claude does" "install the plugin (/plugin install bytek@bytek), or run: bytek setup --hooks"
  fi

  case "$command" in
    *"$BYTEK_HOME/current/"*)
      if [ -x "$BYTEK_HOME/current/bin/bytek" ]; then
        doctor_say ok "$BYTEK_HOME/current leads to Bytek"
      else
        doctor_say problem "$BYTEK_HOME/current doesn't lead to Bytek" "run: bytek setup"
      fi
      ;;
  esac
}

doctor_state_folder() {
  local probe="$BYTEK_HOME/state/.doctor.$$"
  if mkdir -p "$BYTEK_HOME/state" 2>/dev/null && : >"$probe" 2>/dev/null; then
    rm -f "$probe"
    doctor_say ok "$BYTEK_HOME/state is writable"
  else
    doctor_say problem "$BYTEK_HOME/state isn't writable: hooks can't record anything" "check the folder's owner and permissions"
  fi
}

# Times five renders through this same bytek, like the status line runs it.
doctor_render_time() {
  local seconds ms TIMEFORMAT=%3R
  seconds=$({ time for _ in 1 2 3 4 5; do printf '{}' | "$0" render >/dev/null; done; } 2>&1)
  ms=$(awk -v s="$seconds" 'BEGIN { printf "%d", s * 1000 / 5 }')
  if [ "$ms" -le "$DOCTOR_BUDGET_MS" ]; then
    doctor_say ok "a render takes $ms ms"
  else
    doctor_say warning "a render takes $ms ms, over the $DOCTOR_BUDGET_MS ms budget" "a busy machine can cause it; if it stays slow, report it with this output"
  fi
}
