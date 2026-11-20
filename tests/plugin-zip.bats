#!/usr/bin/env bats
# tools/plugin-zip.sh: the plugin zip a release carries, with the release's version in it.

load helpers

ZIP="$ROOT/tools/plugin-zip.sh"

setup() {
  bytek_setup
  needs_jq
  if ! command -v zip >/dev/null || ! command -v unzip >/dev/null; then skip "zip or unzip not installed"; fi
  git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1 || skip "not a git checkout"
}

@test "the zip carries the release's version in plugin.json, at its top level" {
  run "$ZIP" 1.2.3 HEAD "$TMP/bytek.zip"
  assert_success
  assert_equal "$(unzip -p "$TMP/bytek.zip" .claude-plugin/plugin.json | jq -r .version)" 1.2.3
  assert_equal "$(unzip -p "$TMP/bytek.zip" .claude-plugin/plugin.json | jq -r .name)" bytek
}

@test "the zip holds the plugin's files, and bin/bytek stays runnable" {
  "$ZIP" 1.2.3 HEAD "$TMP/bytek.zip"
  mkdir "$TMP/unpacked"
  (cd "$TMP/unpacked" && unzip -q "$TMP/bytek.zip")
  local f
  for f in bin/bytek lib/render.sh faces/idle hooks/hooks.json commands/bytek.md LICENSE; do
    [ -f "$TMP/unpacked/$f" ] || fail "missing: $f"
  done
  [ -x "$TMP/unpacked/bin/bytek" ] || fail "bin/bytek is not executable"
}

@test "the repository's own plugin.json keeps no version" {
  "$ZIP" 1.2.3 HEAD "$TMP/bytek.zip"
  assert_equal "$(jq -r '.version // "none"' "$ROOT/.claude-plugin/plugin.json")" none
}

@test "a version that isn't X.Y.Z, or a missing argument, prints usage" {
  run "$ZIP" v1.2 HEAD "$TMP/bytek.zip"
  assert_failure 2
  assert_output --partial "usage: tools/plugin-zip.sh"
  run "$ZIP" 1.2.3 HEAD
  assert_failure 2
}
