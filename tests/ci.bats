#!/usr/bin/env bats
# The shape of CI: pull requests wait for lint and tests only (test.yml); line coverage runs
# after a merge, in its own workflow (coverage.yml), with its gems locked and cached, and
# blocks nothing, releases included.

load helpers

WORKFLOWS="$ROOT/.github/workflows"

# Prints the lines of job $2 in workflow $1 (from "  $2:" to the next job).
job() {
  awk -v job="  $2:" '
    $0 == job { on = 1; next }
    on && /^  [^ ]/ { on = 0 } # the next job, or the comment above it
    on' "$WORKFLOWS/$1"
}

# Prints the workflow's `on:` block.
triggers() {
  awk '/^on:/ { on = 1; next } on && /^[^ ]/ { on = 0 } on' "$WORKFLOWS/$1"
}

@test "pull requests wait for lint and tests only" {
  run cat "$WORKFLOWS/test.yml"
  assert_output --partial "run: tools/lint.sh"
  assert_output --partial "run: tests/run.sh"
  refute_output --partial "bashcov"
  refute_output --partial "codecov"
}

@test "coverage runs after a merge to main, in its own workflow" {
  run triggers coverage.yml
  assert_output --partial "branches: [main]"
  refute_output --partial "pull_request"
  run job coverage.yml coverage
  assert_output --partial "bundle exec bashcov"
  assert_output --partial "codecov/codecov-action"
}

@test "releases start from the test workflow, not from coverage" {
  grep -q '^    workflows: \[test\]$' "$WORKFLOWS/release.yml"
}

@test "the coverage job installs locked gems from the cache and requires every script" {
  run job coverage.yml coverage
  assert_output --partial "bundler-cache: true"
  assert_output --partial "--require bin/bytek tools/*.sh install.sh uninstall.sh"
  refute_output --partial "gem install"
}

@test "every gem in the Gemfile is pinned and locked, and Dependabot updates them" {
  local name version problems=""
  while read -r name version; do
    grep -q "^    $name ($version)$" "$ROOT/Gemfile.lock" || problems="$problems$name $version: not in Gemfile.lock"$'\n'
  done < <(sed -n 's/^gem "\([^"]*\)", "\([0-9.]*\)"$/\1 \2/p' "$ROOT/Gemfile")
  [ "$(grep -c '^gem ' "$ROOT/Gemfile")" = "$(grep -c '^gem "[^"]*", "[0-9.]*"$' "$ROOT/Gemfile")" ] ||
    problems="${problems}a gem without an exact version"$'\n'
  [ -z "$problems" ] || fail "$problems"
  grep -q 'package-ecosystem: bundler' "$ROOT/.github/dependabot.yml"
}
