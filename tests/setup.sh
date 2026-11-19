#!/usr/bin/env bash
# Checks setup, uninstall, the manual install scripts and the plugin files, against
# temporary settings files (never the real ~/.claude/settings.json).
# Usage: tests/setup.sh

ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BYTEK="$ROOT/bin/bytek"
tmp=$(cd -P "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$tmp"' EXIT
export BYTEK_HOME="$tmp/home" BYTEK_SETTINGS="$tmp/settings.json"

fails=0
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; fails=$((fails + 1)); }
same_json() { [ "$(jq -S . "$1")" = "$(jq -S . "$2")" ]; }
q() { jq -r "$1" "$BYTEK_SETTINGS"; }
resolve() { (cd -P "$1" 2>/dev/null && pwd -P); }

command -v jq >/dev/null || { echo "skip: jq not installed"; exit 0; }

# A user with their own status line, other settings and a hook of their own.
cat > "$tmp/initial.json" <<'EOF'
{
  "theme": "dark",
  "statusLine": { "type": "command", "command": "~/bin/my-status", "padding": 2 },
  "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "~/bin/guard" } ] } ] }
}
EOF
cp "$tmp/initial.json" "$BYTEK_SETTINGS"

"$BYTEK" setup >/dev/null || fail setup "exited non-zero"
expect_cmd="\"$BYTEK_HOME/current/bin/bytek\" render"
[ "$(q .statusLine.command)" = "$expect_cmd" ] || fail setup "status line command: $(q .statusLine.command)"
[ "$(q .statusLine.refreshInterval)" = 1 ]     || fail setup "refreshInterval not 1"
[ "$(q .statusLine.padding)" = 2 ]             || fail setup "padding not kept"
[ "$(q .theme)" = dark ]                       || fail setup "other settings changed"
[ "$(q '.hooks.PreToolUse | length')" = 1 ]    || fail setup "plugin mode must not add hooks"
[ "$(jq -r .command "$BYTEK_HOME/original-statusline.json")" = "~/bin/my-status" ] || fail setup "original status line not saved"
ls "$BYTEK_HOME"/backup/settings.json.* >/dev/null 2>&1 || fail setup "no backup"
[ "$(resolve "$BYTEK_HOME/current")" = "$ROOT" ] || fail setup "current does not point at this checkout"

# Running setup again must not overwrite the saved original with Bytek's own status line.
"$BYTEK" setup >/dev/null
[ "$(jq -r .command "$BYTEK_HOME/original-statusline.json")" = "~/bin/my-status" ] || fail setup-twice "original overwritten"

# --hooks adds Bytek to every event once, next to the user's own hook.
"$BYTEK" setup --hooks >/dev/null
"$BYTEK" setup --hooks >/dev/null
events=$(jq -r '.hooks | keys | length' "$ROOT/hooks/hooks.json")
[ "$(q '.hooks | keys | length')" = "$events" ] || fail hooks "expected $events events, got $(q '.hooks | keys | length')"
[ "$(q '[.hooks[][].hooks[] | select(.command | endswith("bytek\" hook"))] | length')" = "$events" ] || fail hooks "Bytek hook missing or duplicated"
[ "$(q '[.hooks.PreToolUse[].hooks[] | select(.command == "~/bin/guard")] | length')" = 1 ] || fail hooks "user's hook lost"

# A hook from the status line works through the link.
out=$(printf '{"session_id":"s"}' | "$BYTEK_HOME/current/bin/bytek" render)
case "$out" in *"╭──┴──╮"*) ;; *) fail link "render through current failed: $out" ;; esac

"$BYTEK" uninstall >/dev/null || fail uninstall "exited non-zero"
same_json "$tmp/initial.json" "$BYTEK_SETTINGS" || fail uninstall "settings differ from before setup: $(jq -c . "$BYTEK_SETTINGS")"
[ ! -e "$BYTEK_HOME/current" ] || fail uninstall "current link left behind"

# No status line before: uninstall removes the key again.
printf '{"theme":"light"}' > "$tmp/plain.json"
cp "$tmp/plain.json" "$BYTEK_SETTINGS"
"$BYTEK" setup --hooks >/dev/null && "$BYTEK" uninstall >/dev/null
same_json "$tmp/plain.json" "$BYTEK_SETTINGS" || fail plain "settings differ: $(jq -c . "$BYTEK_SETTINGS")"

# A status line set by someone else after setup survives uninstall.
"$BYTEK" setup >/dev/null
tmpjson=$(jq '.statusLine = {"type":"command","command":"other"}' "$BYTEK_SETTINGS") && printf '%s\n' "$tmpjson" > "$BYTEK_SETTINGS"
"$BYTEK" uninstall >/dev/null
[ "$(q .statusLine.command)" = other ] || fail foreign "someone else's status line was replaced"

# A failed edit (jq failing on Bytek's program) leaves settings.json as it was, with no temp files.
real_jq=$(command -v jq)
mkdir -p "$tmp/fakebin"
printf '#!/bin/sh\nfor a in "$@"; do case "$a" in */lib/setup.jq|*/lib/uninstall.jq) exit 5 ;; esac; done\nexec "%s" "$@"\n' \
  "$real_jq" > "$tmp/fakebin/jq"
chmod +x "$tmp/fakebin/jq"
cp "$tmp/initial.json" "$BYTEK_SETTINGS"
out=$(PATH="$tmp/fakebin:$PATH" "$BYTEK" setup 2>&1) && fail edit-fails "setup reported success"
case "$out" in *"could not update"*) ;; *) fail edit-fails "no error message: $out" ;; esac
cmp -s "$tmp/initial.json" "$BYTEK_SETTINGS" || fail edit-fails "setup changed settings.json"
"$BYTEK" setup >/dev/null
before=$(cat "$BYTEK_SETTINGS")
PATH="$tmp/fakebin:$PATH" "$BYTEK" uninstall >/dev/null 2>&1 && fail edit-fails "uninstall reported success"
[ "$(cat "$BYTEK_SETTINGS")" = "$before" ] || fail edit-fails "uninstall changed settings.json"
ls "$BYTEK_SETTINGS".?????? >/dev/null 2>&1 && fail edit-fails "temp files left next to settings.json"
"$BYTEK" uninstall >/dev/null

# A Bytek hook sharing a matcher group with the user's own: only Bytek's hook goes.
bin_cmd="\"$BYTEK_HOME/current/bin/bytek\" hook"
jq --arg b "$bin_cmd" '.hooks.PreToolUse[0].hooks += [{"type": "command", "command": $b}]
  | .hooks.Stop = [{"matcher": "x"}]' "$tmp/initial.json" > "$tmp/shared.json"
cp "$tmp/shared.json" "$BYTEK_SETTINGS"
"$BYTEK" setup --hooks >/dev/null || fail shared "setup failed"
[ "$(q '[.hooks.PreToolUse[].hooks[] | select(.command == "~/bin/guard")] | length')" = 1 ] || fail shared "setup lost the user's hook"
[ "$(q '[.hooks.Stop[] | select(.matcher == "x")] | length')" = 1 ] || fail shared "setup dropped a group without hooks"
"$BYTEK" uninstall >/dev/null || fail shared "uninstall failed"
[ "$(q '.hooks.PreToolUse[0].hooks | map(.command)')" = "$(jq -r '.hooks.PreToolUse[0].hooks | map(.command)' "$tmp/initial.json")" ] \
  || fail shared "uninstall should leave only the user's hook in the shared group: $(jq -c .hooks.PreToolUse "$BYTEK_SETTINGS")"
[ "$(jq -c .hooks.Stop "$BYTEK_SETTINGS")" = '[{"matcher":"x"}]' ] \
  || fail shared "uninstall dropped a group without hooks: $(jq -c .hooks.Stop "$BYTEK_SETTINGS")"

# An empty saved status line (a setup interrupted while saving it) doesn't break uninstall.
cp "$tmp/initial.json" "$BYTEK_SETTINGS"
"$BYTEK" setup >/dev/null
: > "$BYTEK_HOME/original-statusline.json"
"$BYTEK" uninstall >/dev/null || fail empty-original "uninstall failed with an empty saved status line"
[ "$(q 'has("statusLine")')" = false ] || fail empty-original "Bytek's status line not removed"

# Uninstall without a settings file has nothing to do.
mv "$BYTEK_SETTINGS" "$tmp/kept.json"
"$BYTEK" uninstall | grep -q 'Nothing to do' || fail no-settings "expected 'Nothing to do'"
mv "$tmp/kept.json" "$BYTEK_SETTINGS"

# Broken settings are left alone.
printf '{ not json' > "$BYTEK_SETTINGS"
"$BYTEK" setup >/dev/null 2>&1 && fail broken "setup accepted invalid JSON"
[ "$(cat "$BYTEK_SETTINGS")" = '{ not json' ] || fail broken "invalid settings were changed"

# Plugin updates: the SessionStart hook moves `current` from an old plugin folder to this one,
# but leaves a link to a checkout alone.
mkdir -p "$tmp/x/.claude/plugins/cache/bytek/old" "$tmp/checkout"
ln -sfn "$tmp/x/.claude/plugins/cache/bytek/old" "$BYTEK_HOME/current"
printf '{"hook_event_name":"SessionStart","session_id":"s"}' | CLAUDE_PLUGIN_ROOT="$ROOT" "$BYTEK" hook
[ "$(resolve "$BYTEK_HOME/current")" = "$ROOT" ] || fail plugin-update "current not moved to the new plugin folder"
ln -sfn "$tmp/checkout" "$BYTEK_HOME/current"
printf '{"hook_event_name":"SessionStart","session_id":"s"}' | CLAUDE_PLUGIN_ROOT="$ROOT" "$BYTEK" hook
[ "$(resolve "$BYTEK_HOME/current")" = "$tmp/checkout" ] || fail plugin-update "a checkout link was moved"
rm -f "$BYTEK_HOME/current"

# Manual install and uninstall scripts.
cp "$tmp/initial.json" "$BYTEK_SETTINGS"
"$ROOT/install.sh" >/dev/null || fail install "install.sh failed"
[ -x "$BYTEK_HOME/app/bin/bytek" ] || fail install "no copy in $BYTEK_HOME/app"
[ "$(resolve "$BYTEK_HOME/current")" = "$(resolve "$BYTEK_HOME/app")" ] || fail install "current does not point at the copy"
[ ! -d "$BYTEK_HOME/app/.git" ] || fail install ".git copied"
"$ROOT/uninstall.sh" >/dev/null || fail uninstall.sh "uninstall.sh failed"
same_json "$tmp/initial.json" "$BYTEK_SETTINGS" || fail uninstall.sh "settings differ from before install"
[ ! -d "$BYTEK_HOME/app" ] || fail uninstall.sh "copy left behind"
"$ROOT/uninstall.sh" --purge >/dev/null
[ ! -d "$BYTEK_HOME" ] || fail purge "$BYTEK_HOME left behind"

# Plugin files.
[ "$(jq -r .name "$ROOT/.claude-plugin/plugin.json")" = bytek ] || fail plugin "plugin.json name"
[ "$(jq -r '.plugins[0].name' "$ROOT/.claude-plugin/marketplace.json")" = bytek ] || fail plugin "marketplace.json plugin"
grep -qF '"${CLAUDE_PLUGIN_ROOT}/bin/bytek" $ARGUMENTS' "$ROOT/commands/bytek.md" || fail plugin "/bytek command does not run the plugin's script"
"$BYTEK" help | grep -q 'bytek setup' || fail help "help does not list setup"
out=$("$BYTEK" nope); code=$?
[ "$code" -eq 1 ] || fail unknown "unknown command should exit 1, got $code"
case "$out" in *"bytek setup"*) ;; *) fail unknown "unknown command should print usage" ;; esac

if [ "$fails" -eq 0 ]; then echo "ok: setup and uninstall leave settings as they were"; else echo "$fails failure(s)"; exit 1; fi
