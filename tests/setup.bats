#!/usr/bin/env bats
# Setup, uninstall, the manual install scripts and the plugin files, always against a
# temporary settings.json (never the real ~/.claude/settings.json).
# shellcheck disable=SC2088 # "~/bin/..." is sample settings data, compared as text, not a path

load helpers

setup() {
  bytek_setup
  needs_jq
  # A user with their own status line, other settings and a hook of their own.
  cat >"$TMP/initial.json" <<'EOF'
{
  "theme": "dark",
  "statusLine": { "type": "command", "command": "~/bin/my-status", "padding": 2 },
  "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "~/bin/guard" } ] } ] }
}
EOF
  cp "$TMP/initial.json" "$BYTEK_SETTINGS"
}

q() { jq -r "$1" "$BYTEK_SETTINGS"; }
resolve() { (cd -P "$1" 2>/dev/null && pwd -P); }
assert_settings_equal() {
  [ "$(jq -S . "$1")" = "$(jq -S . "$BYTEK_SETTINGS")" ] || fail "settings differ: $(jq -c . "$BYTEK_SETTINGS")"
}
events() { jq -r '.hooks | keys | length' "$ROOT/hooks/hooks.json"; }

@test "setup makes Bytek the status line and keeps everything else" {
  run "$BYTEK" setup
  assert_success
  assert_equal "$(q .statusLine.command)" "\"$BYTEK_HOME/current/bin/bytek\" render"
  assert_equal "$(q .statusLine.refreshInterval)" 1
  assert_equal "$(q .statusLine.padding)" 2
  assert_equal "$(q .theme)" dark
  assert_equal "$(q '.hooks.PreToolUse | length')" 1 # plugin mode adds no hooks
  assert_equal "$(jq -c '[.format, .statusLine.command]' "$BYTEK_HOME/original-statusline.json")" '[1,"~/bin/my-status"]'
  ls "$BYTEK_HOME"/backup/settings.json.* >/dev/null
  assert_equal "$(resolve "$BYTEK_HOME/current")" "$ROOT"
}

@test "setup twice keeps the saved original, never Bytek's own" {
  "$BYTEK" setup >/dev/null
  "$BYTEK" setup >/dev/null
  assert_equal "$(jq -c '[.format, .statusLine.command]' "$BYTEK_HOME/original-statusline.json")" '[1,"~/bin/my-status"]'
}

@test "setup --hooks adds Bytek to every event once, next to the user's hook" {
  "$BYTEK" setup --hooks >/dev/null
  "$BYTEK" setup --hooks >/dev/null
  assert_equal "$(q '.hooks | keys | length')" "$(events)"
  assert_equal "$(q '[.hooks[][].hooks[] | select(.command | endswith("bytek\" hook"))] | length')" "$(events)"
  assert_equal "$(q '[.hooks.PreToolUse[].hooks[] | select(.command == "~/bin/guard")] | length')" 1
}

@test "the status line renders through the current link" {
  "$BYTEK" setup >/dev/null
  run bash -c "printf '{\"session_id\":\"s\"}' | '$BYTEK_HOME/current/bin/bytek' render"
  assert_output --partial "╭──┴──╮"
}

@test "uninstall returns settings to exactly what they were" {
  "$BYTEK" setup --hooks >/dev/null
  run "$BYTEK" uninstall
  assert_success
  assert_settings_equal "$TMP/initial.json"
  [ ! -e "$BYTEK_HOME/current" ] || fail "current link left behind"
}

@test "uninstall reads a status line saved before formats existed" {
  "$BYTEK" setup >/dev/null
  jq -c .statusLine "$BYTEK_HOME/original-statusline.json" >"$TMP/old.json"
  cp "$TMP/old.json" "$BYTEK_HOME/original-statusline.json" # the unwrapped way older versions saved it
  run "$BYTEK" uninstall
  assert_success
  assert_settings_equal "$TMP/initial.json"
}

@test "uninstall leaves a status line saved in a newer format alone" {
  "$BYTEK" setup >/dev/null
  printf '{"format":2,"lines":["~/bin/my-status"]}\n' >"$BYTEK_HOME/original-statusline.json"
  run "$BYTEK" uninstall
  assert_success
  assert_output --partial "a newer Bytek saved it"
  assert_equal "$(q .statusLine)" null # Bytek's own is gone; nothing misread is put back
  assert_equal "$(jq -c . "$BYTEK_HOME/original-statusline.json")" '{"format":2,"lines":["~/bin/my-status"]}'
}

@test "without an earlier status line, uninstall removes it again" {
  printf '{"theme":"light"}' >"$TMP/plain.json"
  cp "$TMP/plain.json" "$BYTEK_SETTINGS"
  "$BYTEK" setup --hooks >/dev/null
  "$BYTEK" uninstall >/dev/null
  assert_settings_equal "$TMP/plain.json"
}

@test "a status line set by someone else after setup survives uninstall" {
  "$BYTEK" setup >/dev/null
  jq '.statusLine = {"type":"command","command":"other"}' "$BYTEK_SETTINGS" >"$TMP/s.json"
  cp "$TMP/s.json" "$BYTEK_SETTINGS"
  "$BYTEK" uninstall >/dev/null
  assert_equal "$(q .statusLine.command)" other
}

@test "a failed edit leaves settings.json as it was, without temp files" {
  # A jq that fails only on Bytek's own programs.
  mkdir -p "$TMP/fakebin"
  printf '#!/bin/sh\nfor a in "$@"; do case "$a" in */lib/setup.jq|*/lib/uninstall.jq) exit 5 ;; esac; done\nexec "%s" "$@"\n' \
    "$(command -v jq)" >"$TMP/fakebin/jq"
  chmod +x "$TMP/fakebin/jq"

  PATH="$TMP/fakebin:$PATH" run "$BYTEK" setup
  assert_failure
  assert_output --partial "could not update"
  cmp -s "$TMP/initial.json" "$BYTEK_SETTINGS" || fail "setup changed settings.json"

  "$BYTEK" setup >/dev/null
  cp "$BYTEK_SETTINGS" "$TMP/before.json"
  PATH="$TMP/fakebin:$PATH" run "$BYTEK" uninstall
  assert_failure
  cmp -s "$TMP/before.json" "$BYTEK_SETTINGS" || fail "uninstall changed settings.json"
  ! ls "$BYTEK_SETTINGS".?????? >/dev/null 2>&1 || fail "temp files left next to settings.json"
}

@test "only Bytek's hook leaves a matcher group it shares with the user" {
  jq --arg b "\"$BYTEK_HOME/current/bin/bytek\" hook" \
    '.hooks.PreToolUse[0].hooks += [{"type": "command", "command": $b}] | .hooks.Stop = [{"matcher": "x"}]' \
    "$TMP/initial.json" >"$BYTEK_SETTINGS"
  "$BYTEK" setup --hooks >/dev/null
  assert_equal "$(q '[.hooks.PreToolUse[].hooks[] | select(.command == "~/bin/guard")] | length')" 1
  assert_equal "$(q '[.hooks.Stop[] | select(.matcher == "x")] | length')" 1
  "$BYTEK" uninstall >/dev/null
  assert_equal "$(q '.hooks.PreToolUse[0].hooks | map(.command) | join(",")')" "~/bin/guard"
  assert_equal "$(jq -c .hooks.Stop "$BYTEK_SETTINGS")" '[{"matcher":"x"}]'
}

@test "an empty saved status line doesn't break uninstall" {
  "$BYTEK" setup >/dev/null
  : >"$BYTEK_HOME/original-statusline.json"
  run "$BYTEK" uninstall
  assert_success
  assert_equal "$(q 'has("statusLine")')" false
}

@test "uninstall without a settings file has nothing to do" {
  rm "$BYTEK_SETTINGS"
  run "$BYTEK" uninstall
  assert_success
  assert_output --partial "Nothing to do"
}

@test "invalid settings are left alone" {
  printf '{ not json' >"$BYTEK_SETTINGS"
  run "$BYTEK" setup
  assert_failure
  assert_equal "$(cat "$BYTEK_SETTINGS")" '{ not json'
}

@test "after a plugin update the link follows the plugin, not a checkout" {
  mkdir -p "$TMP/x/.claude/plugins/cache/bytek/old" "$TMP/checkout"
  ln -sfn "$TMP/x/.claude/plugins/cache/bytek/old" "$BYTEK_HOME/current"
  CLAUDE_PLUGIN_ROOT="$ROOT" hook '{"hook_event_name":"SessionStart","session_id":"s"}'
  assert_equal "$(resolve "$BYTEK_HOME/current")" "$ROOT"

  ln -sfn "$TMP/checkout" "$BYTEK_HOME/current"
  CLAUDE_PLUGIN_ROOT="$ROOT" hook '{"hook_event_name":"SessionStart","session_id":"s"}'
  assert_equal "$(resolve "$BYTEK_HOME/current")" "$TMP/checkout"
}

@test "install.sh and uninstall.sh install a copy and undo it" {
  run "$ROOT/install.sh"
  assert_success
  [ -x "$BYTEK_HOME/app/bin/bytek" ] || fail "no copy in $BYTEK_HOME/app"
  assert_equal "$(resolve "$BYTEK_HOME/current")" "$(resolve "$BYTEK_HOME/app")"
  [ ! -e "$BYTEK_HOME/app/.git" ] || fail ".git copied"

  run "$ROOT/uninstall.sh"
  assert_success
  assert_settings_equal "$TMP/initial.json"
  [ ! -d "$BYTEK_HOME/app" ] || fail "copy left behind"

  "$ROOT/uninstall.sh" --purge >/dev/null
  [ ! -d "$BYTEK_HOME" ] || fail "$BYTEK_HOME left behind"
}

@test "plugin files name the plugin and run its script" {
  assert_equal "$(jq -r .name "$ROOT/.claude-plugin/plugin.json")" bytek
  assert_equal "$(jq -r '.plugins[0].name' "$ROOT/.claude-plugin/marketplace.json")" bytek
  grep -qF '"${CLAUDE_PLUGIN_ROOT}/bin/bytek" $ARGUMENTS' "$ROOT/commands/bytek.md"
}

@test "help lists the commands; an unknown command prints usage and fails" {
  run "$BYTEK" help
  assert_success
  assert_output --partial "bytek setup"
  run "$BYTEK" nope
  assert_failure 1
  assert_output --partial "bytek setup"
}

@test "setup lets Claude set the antenna without a prompt, once, next to the user's own rules" {
  jq '.permissions = {"allow": ["Bash(npm test)"], "deny": ["Bash(rm *)"]}' "$BYTEK_SETTINGS" >"$TMP/s" && mv "$TMP/s" "$BYTEK_SETTINGS"
  "$BYTEK" setup >/dev/null
  "$BYTEK" setup >/dev/null
  assert_equal "$(jq -c .permissions "$BYTEK_SETTINGS")" \
    '{"allow":["Bash(npm test)","Bash(~/.claude/bytek/current/bin/bytek addon *)"],"deny":["Bash(rm *)"]}'
}

@test "uninstall removes only Bytek's permission rule" {
  jq '.permissions = {"allow": ["Bash(npm test)"]}' "$BYTEK_SETTINGS" >"$TMP/s" && mv "$TMP/s" "$BYTEK_SETTINGS"
  cp "$BYTEK_SETTINGS" "$TMP/with-rules.json"
  "$BYTEK" setup >/dev/null
  "$BYTEK" uninstall >/dev/null
  assert_settings_equal "$TMP/with-rules.json"
}
