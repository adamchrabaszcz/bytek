#!/usr/bin/env bats
# tools/format-check.sh against good and bad issues and pull requests.

load helpers

CHECK="$ROOT/tools/format-check.sh"

setup() {
  bytek_setup
  needs_jq
}

issue() {
  jq -n --arg body "$1" '{issue: {body: $body}}' >"$TMP/event.json"
  "$CHECK" issue "$TMP/event.json"
}
pr() {
  jq -n --arg title "$1" --arg body "$2" '{pull_request: {title: $title, body: $body}}' >"$TMP/event.json"
  "$CHECK" pr "$TMP/event.json"
}

@test "a complete issue passes, an empty optional section included" {
  run issue $'### What and why\nRain outfit.\n\n### Done when\n- [ ] drops render\n\n### Blast radius\n_No response_'
  assert_output ""
}

@test "an issue without Done when is reported" {
  run issue $'### What and why\nRain outfit.'
  assert_output --partial '"### Done when"'
  refute_output --partial 'What and why'
}

@test "an empty form field counts as missing" {
  run issue $'### What and why\n_No response_\n\n### Done when\n- [ ] x'
  assert_output --partial '"### What and why"'
}

@test "two-hash headings and CRLF line endings are fine" {
  run issue $'## What and why\r\nWindows line endings.\r\n## Done when\r\n- [ ] x\r\n'
  assert_output ""
}

@test "a blank issue misses both sections" {
  run issue ''
  assert_output $'Missing: a "### What and why" section with something in it\nMissing: a "### Done when" section with something in it'
}

@test "good pull requests pass: scopes, breaking, fixes and resolves" {
  pr "feat(outfits): umbrella when it rains" "Closes #9"
  pr "fix: keep the antenna in place" $'What\n\nfixes #12.'
  pr "feat!: new state file format" "Resolves #3"
  pr "ci(release, format): tags" "closes #1"
}

@test "titles without a known type or a space after the colon fail" {
  run pr "Add rain outfit" "Closes #9"
  assert_failure
  run pr "feature: rain" "Closes #9"
  assert_failure
  run pr "feat:rain" "Closes #9"
  assert_failure
}

@test "descriptions without a real Closes line fail" {
  run pr "feat: rain" "Part of #9"
  assert_failure
  run pr "feat: rain" "Closes 9"
  assert_failure
  run pr "feat: rain" "disclosed #9"
  assert_failure
}

@test "both problems are reported together" {
  run pr "nope" ""
  assert_failure
  assert_equal "$(printf '%s\n' "$output" | grep -c '^Missing: ')" 2
}
