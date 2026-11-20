#!/usr/bin/env bash
# Builds bytek.zip, the plugin as Claude Code installs it from a release: the files of a commit,
# at the top of the zip, with the release's version in .claude-plugin/plugin.json (the copy in
# the repository has none). .github/workflows/release.yml attaches it to every release.
#
#   tools/plugin-zip.sh <version> <commit> <out.zip>      e.g. 0.4.0 HEAD /tmp/bytek.zip

set -o errexit +o nounset +o pipefail # declared, not inherited (CONTRIBUTING, "Shell options")

usage() {
  echo "usage: tools/plugin-zip.sh <version> <commit> <out.zip>" >&2
  exit 2
}

version=$1 commit=$2 out=$3
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || usage
[ -n "$commit" ] && [ -n "$out" ] || usage
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/bytek-zip.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# The commit's files exactly, with their executable bits (bin/bytek runs directly).
git -C "$root" archive --format=tar "$commit" | tar -x -C "$tmp"
manifest="$tmp/.claude-plugin/plugin.json"
jq --arg version "$version" '.version = $version' "$manifest" >"$manifest.new"
mv "$manifest.new" "$manifest"

rm -f "$out"
(cd "$tmp" && zip -q -r -X "$out" .)
