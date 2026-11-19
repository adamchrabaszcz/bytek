#!/usr/bin/env bash
# Checks the release tools: version bumps from commit types (also against a real git
# repository with tags) and pull request numbers from merge commit subjects.
# Usage: tests/release.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE="$ROOT/tools/release.sh"
MARKS="$ROOT/tools/release-marks.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fails=0
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; fails=$((fails + 1)); }

# next <last> <subject[|body]>...: one commit per argument, "|" separating subject and body.
# (No case inside $( ): bash 3.2 can't parse it.)
next() {
  local last=$1 c subject body
  shift
  for c in "$@"; do
    subject=${c%%|*} body=""
    [ "$subject" != "$c" ] && body=${c#*|}
    printf '%s\037%s\036' "$subject" "$body"
  done | "$RELEASE" --next "$last"
}
expect() { [ "$2" = "$3" ] || fail "$1" "expected '$3', got '$2'"; }

expect first      "$(next "" "docs: readme")"                                  "0.1.0"
expect patch      "$(next 0.1.0 "fix(core): antenna column" "docs: x")"        "0.1.1"
expect perf       "$(next 0.1.0 "perf: fewer forks")"                          "0.1.1"
expect minor      "$(next 0.1.3 "fix: a" "feat(outfits): rain")"               "0.2.0"
expect bang       "$(next 0.2.0 "feat!: new state format")"                    "1.0.0"
expect footer     "$(next 0.2.0 "fix: x|Details.
BREAKING CHANGE: state files are rewritten")"                                  "1.0.0"
expect nothing    "$(next 0.2.0 "docs: a" "ci: b" "chore: c" "test: d")"       ""
expect non-cc     "$(next 0.2.0 "Merge branch main" "WIP")"                    ""

# Against a real repository: tags decide where to count from.
repo="$tmp/repo"
git init -q "$repo"
commit() { git -C "$repo" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false commit -q --allow-empty -m "$1"; }
run() { (cd "$repo" && "$RELEASE"); }
commit "feat: first"
expect repo-first "$(run)" "0.1.0"
git -C "$repo" tag v0.1.0
expect repo-none  "$(run)" ""
commit "fix: something"
expect repo-fix   "$(run)" "0.1.1"
git -C "$repo" tag v0.1.1
commit "docs: notes"
commit "feat(addons): lollipop"
expect repo-feat  "$(run)" "0.2.0"

prs=$(printf '%s\n' \
  "Merge pull request #34 from owner/ci/coverage" \
  "feat: squash merged (#7)" \
  "Merge pull request #7 from owner/feat/x" \
  "fix: mentions #9 in the middle" \
  "chore: plain commit" | "$MARKS" --prs | tr '\n' ' ')
expect prs "$prs" "7 34 "

# Squash merges only (how main is merged): title "(#n)" as subject, the pull request
# description as body. A description mentioning "BREAKING CHANGE:" in passing doesn't count;
# only a footer line that starts with it does.
squash="$tmp/squash"
git init -q "$squash"
scommit() { git -C "$squash" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false commit -q --allow-empty -m "$1" -m "$2"; }
scommit "feat(plugin): install as a plugin (#38)" $'### What and why\nPlugin.\n\nCloses #3'
git -C "$squash" tag v0.2.0
scommit "docs: explain setup (#40)" $'### What and why\nDocs.\n\nCloses #12'
scommit "fix(core): keep the antenna in place (#41)" $'### What and why\nNo BREAKING CHANGE: here.\n\nCloses #13'
expect squash-fix "$( (cd "$squash" && "$RELEASE") )" "0.2.1"
scommit "feat!: new state format (#42)" $'### What and why\nState files change.\n\nBREAKING CHANGE: old state files are reset\n\nCloses #14'
expect squash-major "$( (cd "$squash" && "$RELEASE") )" "1.0.0"
prs=$(git -C "$squash" log --format=%s v0.2.0..HEAD | "$MARKS" --prs | tr '\n' ' ')
expect squash-prs "$prs" "40 41 42 "

if [ "$fails" -eq 0 ]; then echo "ok: releases bump the right version part"; else echo "$fails failure(s)"; exit 1; fi
