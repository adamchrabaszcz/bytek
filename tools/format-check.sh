#!/usr/bin/env bash
# Checks the format of issues and pull requests (CONTRIBUTING.md, "Issues and pull requests"),
# for .github/workflows/format.yml. Needs jq.
#
# Issues: "### What and why" and "### Done when" with something under them; "### Blast radius"
# and "### Parent" are optional. The issue forms (.github/ISSUE_TEMPLATE/) write these headings.
# Pull requests: a Conventional Commit title, and a "Closes #n" line, so merging closes the issue.
#
#   tools/format-check.sh issue [event.json]   prints "Missing: ..." lines; always exits 0
#   tools/format-check.sh pr [event.json]      prints what is missing; exits 1 when something is
# The event defaults to $GITHUB_EVENT_PATH, as in GitHub Actions.

set +o errexit +o nounset +o pipefail # declared, not inherited (CONTRIBUTING, "Shell options")

TYPES="feat|fix|perf|docs|ci|chore|test|refactor|style|build"
TITLE_RE="^($TYPES)(\([[:alnum:] ,./_-]+\))?!?: [^ ]"
CLOSES_RE="(^|[^[:alnum:]_])(close[sd]?|fix(e[sd])?|resolve[sd]?) +#[0-9]+([^[:alnum:]_]|$)"

# Prints the text under "## Heading" or "### Heading" $2 in body $1, trimmed.
# "_No response_" (what an issue form writes for an empty field) counts as nothing.
section() {
  printf '%s\n' "$1" | tr -d '\r' | awk -v want="$2" '
    /^#{2,3} +/ { h = $0; sub(/^#+ +/, "", h); sub(/ +$/, "", h); inside = (h == want); next }
    inside { print }
  ' | sed -e '/^[[:space:]]*$/d' -e '/^_No response_$/d'
}

check_issue() {
  local body=$1 name
  for name in "What and why" "Done when"; do
    [ -n "$(section "$body" "$name")" ] || echo "Missing: a \"### $name\" section with something in it"
  done
}

check_pr() {
  local title=$1 body=$2 problems=0
  if ! [[ "$title" =~ $TITLE_RE ]]; then
    echo "Missing: a Conventional Commit title (${TYPES//|/, }), e.g. \"fix(core): keep the antenna in column 5\""
    problems=1
  fi
  shopt -s nocasematch
  if ! [[ "$body" =~ $CLOSES_RE ]]; then
    echo "Missing: a \"Closes #<issue>\" line in the description, so merging closes the issue"
    problems=1
  fi
  shopt -u nocasematch
  return $problems
}

event=${2:-$GITHUB_EVENT_PATH}
[ -f "$event" ] || { echo "format-check: no event file (${event:-unset})" >&2; exit 2; }

case "$1" in
  issue)
    check_issue "$(jq -r '.issue.body // ""' "$event")"
    exit 0 ;;
  pr)
    if check_pr "$(jq -r '.pull_request.title // ""' "$event")" "$(jq -r '.pull_request.body // ""' "$event")"; then
      echo "Format OK."
    else
      exit 1
    fi ;;
  *)
    sed -n '2,12s/^# \{0,1\}//p' "$0"; exit 2 ;;
esac
