#!/usr/bin/env bash
# Marks what a release shipped (.github/workflows/release.yml, after the tag): every pull
# request merged since the previous release, and every issue those pull requests closed,
# gets the version's milestone and a "Released in vX.Y.Z" comment with a link to the
# release. Re-running doesn't comment twice. Uses gh and jq.
#
#   tools/release-marks.sh <version> <previous tag or ""> <sha>   GH_TOKEN, GITHUB_REPOSITORY set
#   tools/release-marks.sh --prs                                   commit subjects on stdin; for tests

# Pull request numbers from merge commit subjects ("Merge pull request #12 from …") and
# squash merges ("feat: … (#12)"), oldest first, no repeats.
pr_numbers() {
  sed -n -e 's/^Merge pull request #\([0-9][0-9]*\).*/\1/p' -e 's/.*(#\([0-9][0-9]*\))$/\1/p' | sort -n -u
}

if [ "$1" = --prs ]; then
  pr_numbers
  exit 0
fi

version=$1 previous=$2 sha=$3
repo=$GITHUB_REPOSITORY
[ -n "$version" ] && [ -n "$sha" ] && [ -n "$repo" ] || {
  echo "usage: see the header of $0" >&2
  exit 2
}
set -e

if [ -n "$previous" ]; then range="$previous..$sha"; else range=$sha; fi
prs=$(git log --format=%s "$range" | pr_numbers)
issues=""
for pr in $prs; do
  issues="$issues $(gh pr view "$pr" --repo "$repo" --json closingIssuesReferences -q '.closingIssuesReferences[].number')"
done
# shellcheck disable=SC2086 # space-separated issue numbers, split on purpose
issues=$(printf '%s\n' $issues | sort -n -u)

title="v$version"
url="https://github.com/$repo/releases/tag/$title"
line="Released in [$title]($url)."

# The milestone: made open so things can be added to it, then closed (it is shipped).
milestone=$(gh api "repos/$repo/milestones?state=all&per_page=100" -q ".[] | select(.title == \"$title\") | .number")
if [ -z "$milestone" ]; then
  milestone=$(gh api "repos/$repo/milestones" -f title="$title" -f description="$url" -q .number)
else
  gh api -X PATCH "repos/$repo/milestones/$milestone" -f state=open >/dev/null
fi

for n in $prs $issues; do
  gh api -X PATCH "repos/$repo/issues/$n" -F milestone="$milestone" >/dev/null # issues and pull requests alike
  if ! gh api "repos/$repo/issues/$n/comments?per_page=100" -q '.[].body' | grep -qF "$line"; then
    gh api "repos/$repo/issues/$n/comments" -f body="$line" >/dev/null
  fi
  echo "#$n: $title"
done
gh api -X PATCH "repos/$repo/milestones/$milestone" -f state=closed >/dev/null
# shellcheck disable=SC2086 # number lists, split on purpose to count them
echo "$title: $(printf '%s\n' $prs | grep -c .) pull requests, $(printf '%s\n' $issues | grep -c .) issues"
