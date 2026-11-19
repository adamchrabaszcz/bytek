#!/usr/bin/env bats
# The release tools: version bumps from commit types (also against real git repositories with
# tags and squash merges) and pull request numbers from commit subjects.

load helpers

RELEASE="$ROOT/tools/release.sh"
MARKS="$ROOT/tools/release-marks.sh"

# next <last> <subject[|body]>...: one commit per argument, "|" separating subject and body.
next() {
  local last=$1 c subject body
  shift
  for c in "$@"; do
    subject=${c%%|*} body=""
    [ "$subject" != "$c" ] && body=${c#*|}
    printf '%s\037%s\036' "$subject" "$body"
  done | "$RELEASE" --next "$last"
}

# A throwaway repository in $TMP/$1 with empty commits.
repo() { git init -q "$TMP/$1"; }
commit() { git -C "$TMP/$1" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false commit -q --allow-empty -m "$2" ${3:+-m "$3"}; }
next_in() { (cd "$TMP/$1" && "$RELEASE"); }

@test "the first release is 0.1.0" {
  assert_equal "$(next "" "docs: readme")" "0.1.0"
}

@test "fix and perf bump the patch version" {
  assert_equal "$(next 0.1.0 "fix(core): antenna column" "docs: x")" "0.1.1"
  assert_equal "$(next 0.1.0 "perf: fewer forks")" "0.1.1"
}

@test "feat bumps the minor version" {
  assert_equal "$(next 0.1.3 "fix: a" "feat(outfits): rain")" "0.2.0"
}

@test "a breaking change bumps the major version, by ! or footer" {
  assert_equal "$(next 0.2.0 "feat!: new state format")" "1.0.0"
  assert_equal "$(next 0.2.0 "fix: x|Details.
BREAKING CHANGE: state files are rewritten")" "1.0.0"
}

@test "docs, ci, chore, test and non-conventional commits release nothing" {
  assert_equal "$(next 0.2.0 "docs: a" "ci: b" "chore: c" "test: d")" ""
  assert_equal "$(next 0.2.0 "Merge branch main" "WIP")" ""
}

@test "in a repository, tags decide where counting starts" {
  repo r
  commit r "feat: first"
  assert_equal "$(next_in r)" "0.1.0"
  git -C "$TMP/r" tag v0.1.0
  assert_equal "$(next_in r)" ""
  commit r "fix: something"
  assert_equal "$(next_in r)" "0.1.1"
  git -C "$TMP/r" tag v0.1.1
  commit r "docs: notes"
  commit r "feat(addons): lollipop"
  assert_equal "$(next_in r)" "0.2.0"
}

@test "squash merges: patch, major only by a footer line, pull requests from (#n)" {
  repo s
  commit s "feat(plugin): install as a plugin (#38)" $'### What and why\nPlugin.\n\nCloses #3'
  git -C "$TMP/s" tag v0.2.0
  commit s "docs: explain setup (#40)" $'### What and why\nDocs.\n\nCloses #12'
  commit s "fix(core): keep the antenna in place (#41)" $'### What and why\nNo BREAKING CHANGE: here.\n\nCloses #13'
  assert_equal "$(next_in s)" "0.2.1"
  commit s "feat!: new state format (#42)" $'### What and why\nState files change.\n\nBREAKING CHANGE: old state files are reset\n\nCloses #14'
  assert_equal "$(next_in s)" "1.0.0"
  assert_equal "$(git -C "$TMP/s" log --format=%s v0.2.0..HEAD | "$MARKS" --prs | tr '\n' ' ')" "40 41 42 "
}

@test "pull request numbers come from merge and squash subjects, once each" {
  run bash -c "printf '%s\n' 'Merge pull request #34 from owner/ci/coverage' 'feat: squash merged (#7)' \
    'Merge pull request #7 from owner/feat/x' 'fix: mentions #9 in the middle' 'chore: plain commit' | '$MARKS' --prs"
  assert_output $'7\n34'
}
