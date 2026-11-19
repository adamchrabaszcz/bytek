#!/usr/bin/env bash
# Checks tools/format-check.sh against good and bad issues and pull requests.
# Usage: tests/format-check.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/tools/format-check.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fails=0
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; fails=$((fails + 1)); }

command -v jq >/dev/null || { echo "skip: jq not installed"; exit 0; }

issue() { jq -n --arg body "$1" '{issue: {body: $body}}' > "$tmp/event.json"; "$CHECK" issue "$tmp/event.json"; }
pr() { jq -n --arg title "$1" --arg body "$2" '{pull_request: {title: $title, body: $body}}' > "$tmp/event.json"; "$CHECK" pr "$tmp/event.json"; }

good_issue=$'### What and why\nRain outfit.\n\n### Done when\n- [ ] drops render\n\n### Blast radius\n_No response_'
[ -z "$(issue "$good_issue")" ] || fail issue-good "complained about a complete issue: $(issue "$good_issue")"

out=$(issue $'### What and why\nRain outfit.')
case "$out" in *'"### Done when"'*) ;; *) fail issue-no-done "expected Done when missing, got: $out" ;; esac
case "$out" in *'What and why'*) fail issue-no-done "wrongly reported What and why: $out" ;; esac

out=$(issue $'### What and why\n_No response_\n\n### Done when\n- [ ] x')
case "$out" in *'"### What and why"'*) ;; *) fail issue-empty "an empty form field should count as missing: $out" ;; esac

out=$(issue $'## What and why\r\nWindows line endings.\r\n## Done when\r\n- [ ] x\r\n')
[ -z "$out" ] || fail issue-crlf "two-hash headings with CRLF should pass: $out"

[ "$(issue '')" = $'Missing: a "### What and why" section with something in it\nMissing: a "### Done when" section with something in it' ] \
  || fail issue-blank "a blank issue should miss both sections"

pr "feat(outfits): umbrella when it rains" "Closes #9" >/dev/null || fail pr-good "rejected a good pull request"
pr "fix: keep the antenna in place" $'What\n\nfixes #12.' >/dev/null || fail pr-fixes "rejected 'fixes #12.'"
pr "feat!: new state file format" "Resolves #3" >/dev/null || fail pr-breaking "rejected a breaking change title"
pr "ci(release, format): tags" "closes #1" >/dev/null || fail pr-scopes "rejected a multi-scope title"

pr "Add rain outfit" "Closes #9" >/dev/null && fail pr-title "accepted a title without a type"
pr "feature: rain" "Closes #9" >/dev/null && fail pr-type "accepted an unknown type"
pr "feat:rain" "Closes #9" >/dev/null && fail pr-space "accepted a title without a space after the colon"
pr "feat: rain" "Part of #9" >/dev/null && fail pr-closes "accepted 'Part of #9'"
pr "feat: rain" "Closes 9" >/dev/null && fail pr-hash "accepted a Closes line without #"
pr "feat: rain" "disclosed #9" >/dev/null && fail pr-word "accepted 'disclosed #9'"

out=$(pr "nope" "")
[ "$(printf '%s\n' "$out" | grep -c '^Missing: ')" -eq 2 ] || fail pr-both "expected two problems, got: $out"

if [ "$fails" -eq 0 ]; then echo "ok: format check accepts and rejects the right issues and pull requests"; else echo "$fails failure(s)"; exit 1; fi
