#!/usr/bin/env bats
# The shape of CI (.github/workflows/test.yml): coverage runs in its own job, next to the
# tests, with its gems locked and cached.

load helpers

# Prints the lines of job $1 in test.yml (from "  $1:" to the next job).
job() {
  awk -v job="  $1:" '
    $0 == job { on = 1; next }
    on && /^  [^ ]/ { on = 0 } # the next job, or the comment above it
    on' "$ROOT/.github/workflows/test.yml"
}

@test "the test jobs only test; coverage has its own job" {
  run job test
  assert_output --partial "tests/run.sh"
  refute_output --partial "bashcov"
  refute_output --partial "codecov"
  run job coverage
  assert_output --partial "bundle exec bashcov"
  assert_output --partial "codecov/codecov-action"
}

@test "the coverage job installs locked gems from the cache and requires every script" {
  run job coverage
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
