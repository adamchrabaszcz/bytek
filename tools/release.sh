#!/usr/bin/env bash
# Prints the next version from the Conventional Commits since the last vX.Y.Z tag, or nothing
# when they ship no change (.github/workflows/release.yml). The first release is 0.1.0.
#
#   breaking change ("feat!:" or a "BREAKING CHANGE:" footer) -> major
#   feat -> minor;  fix, perf -> patch;  docs, ci, chore, test, refactor, style, build -> none
#
#   tools/release.sh                    in a git checkout with full history and tags
#   tools/release.sh --next <last>      commits on stdin as "subject\037body\036" records; for tests

FIRST=0.1.0

# Reads commit records on stdin; prints the version after $1 ("" = no release yet).
next_version() {
  local last=$1 level=0 record subject body re='^([a-z]+)(\([^)]*\))?(!)?:'
  while IFS= read -r -d $'\036' record || [ -n "$record" ]; do
    record=${record#$'\n'}
    subject=${record%%$'\037'*}
    body=${record#*$'\037'}
    [[ "$subject" =~ $re ]] || continue
    if [ -n "${BASH_REMATCH[3]}" ] || printf '%s\n' "$body" | grep -Eq '^BREAKING[ -]CHANGE:'; then
      level=3
    elif [ "${BASH_REMATCH[1]}" = feat ] && [ "$level" -lt 2 ]; then
      level=2
    elif { [ "${BASH_REMATCH[1]}" = fix ] || [ "${BASH_REMATCH[1]}" = perf ]; } && [ "$level" -lt 1 ]; then
      level=1
    fi
  done
  if [ -z "$last" ]; then echo "$FIRST"; return; fi
  local major minor patch
  IFS=. read -r major minor patch <<< "$last"
  case $level in
    3) echo "$((major + 1)).0.0" ;;
    2) echo "$major.$((minor + 1)).0" ;;
    1) echo "$major.$minor.$((patch + 1))" ;;
  esac
}

if [ "$1" = --next ]; then
  next_version "$2"
  exit 0
fi

last=$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null)
if [ -n "$last" ]; then range="$last..HEAD"; else range=HEAD; fi
git log --no-merges --format='%s%x1f%b%x1e' "$range" | next_version "${last#v}"
