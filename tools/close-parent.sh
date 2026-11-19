#!/usr/bin/env bash
# Closes the parent of a closed issue once all its sub-issues are done
# (.github/workflows/issues.yml, CONTRIBUTING.md "Work that takes several pull requests").
# Uses the gh CLI.
#
#   tools/close-parent.sh <closed issue number>         GH_TOKEN and REPO (owner/name) set
#   tools/close-parent.sh --decide "<parent> <state> <completed> <total>"
#                                                       prints what it would do; for tests

# Prints "close" when the parent should close now, otherwise why not.
decide() {
  local number=$1 state=$2 completed=$3 total=$4
  if [ -z "$number" ]; then
    echo "no parent"
  elif [ "$state" != OPEN ]; then
    echo "parent #$number is already closed"
  elif [ "$completed" != "$total" ]; then
    echo "parent #$number: $completed of $total sub-issues done"
  else
    echo "close"
  fi
}

if [ "$1" = --decide ]; then
  set -f
  # shellcheck disable=SC2086 # the four fields are space-separated on purpose
  decide $2
  exit 0
fi

issue=$1
[ -n "$issue" ] && [ -n "$REPO" ] || {
  echo "usage: REPO=owner/name tools/close-parent.sh <issue>" >&2
  exit 2
}

parent=$(gh api graphql -F owner="${REPO%/*}" -F repo="${REPO#*/}" -F n="$issue" -f query='
  query($owner: String!, $repo: String!, $n: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $n) { parent { number state subIssuesSummary { total completed } } }
    }
  }' -q '.data.repository.issue.parent | select(. != null) | "\(.number) \(.state) \(.subIssuesSummary.completed) \(.subIssuesSummary.total)"') || exit 1

set -f
# shellcheck disable=SC2086
verdict=$(decide $parent)
set +f
if [ "$verdict" = close ]; then
  number=${parent%% *}
  gh issue close "$number" --repo "$REPO" --comment "All its sub-issues are done (the last one was #$issue), so this is done too."
  echo "Closed parent #$number."
else
  echo "#$issue: $verdict."
fi
