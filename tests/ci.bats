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
  assert_output --partial "--require bin/bytek lib/*.sh tools/*.sh install.sh uninstall.sh"
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

@test "the AI review runs when a pull request opens or is ready, not on every push" {
  run triggers claude-review.yml
  assert_output --partial "types: [opened, ready_for_review]"
  refute_output --partial "synchronize"
  refute_output --partial "push"
}

@test "the AI review skips drafts and pull requests without secrets, and can't push" {
  run job claude-review.yml review
  assert_output --partial "!github.event.pull_request.draft"
  assert_output --partial "github.event.pull_request.user.login != 'dependabot[bot]'"
  assert_output --partial "github.event.pull_request.head.repo.full_name == github.repository"
  assert_output --partial "contents: read"
  refute_output --partial "contents: write"
  assert_output --partial 'claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}'
}

@test "@claude answers comments and reviews, reading only, with the subscription token" {
  run triggers claude.yml
  assert_output --partial "issue_comment:"
  assert_output --partial "pull_request_review_comment:"
  assert_output --partial "pull_request_review:"
  run job claude.yml claude
  refute_output --partial "contents: write"
  refute_output --partial "anthropic_api_key"
  assert_output --partial 'claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}'
}

@test "the AI review follows the repository's rules, rates findings and ends with a verdict" {
  run cat "$WORKFLOWS/claude-review.yml"
  assert_output --partial "AGENTS.md"
  assert_output --partial "CONTRIBUTING.md"
  assert_output --partial "definition of done"
  assert_output --partial '"**blocking**"'
  assert_output --partial '"**Ready to merge**"'
  assert_output --partial "Never approve"
  assert_output --partial "--max-turns"
}
