#!/usr/bin/env bash
# Checks the repository basics: Code of Conduct, code owners, and that every tracked text
# file follows .editorconfig (LF line endings, final newline, no trailing whitespace outside
# Markdown, no tabs for indentation).
# Usage: tests/hygiene.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fails=0
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; fails=$((fails + 1)); }

coc="$ROOT/CODE_OF_CONDUCT.md"
[ -f "$coc" ] || fail coc "CODE_OF_CONDUCT.md missing"
grep -q 'version 2.1' "$coc" 2>/dev/null || fail coc "not the Contributor Covenant 2.1"
grep -q 'INSERT' "$coc" 2>/dev/null && fail coc "placeholder left in the Code of Conduct"
grep -qx '\* @[A-Za-z0-9-]*' "$ROOT/.github/CODEOWNERS" 2>/dev/null || fail codeowners "no default owner for every file"
grep -qx 'root = true' "$ROOT/.editorconfig" 2>/dev/null || fail editorconfig ".editorconfig missing or not the root"

# Only files git tracks (a checkout, as in CI); skip quietly elsewhere.
files=$(git -C "$ROOT" ls-files 2>/dev/null) || { echo "skip: not a git checkout"; exit 0; }
while IFS= read -r f; do
  path="$ROOT/$f"
  [ -f "$path" ] || continue
  LC_ALL=C grep -q $'\r' "$path" && fail "$f" "CRLF line endings"
  [ -s "$path" ] && [ -n "$(tail -c 1 "$path")" ] && fail "$f" "no newline at the end"
  case "$f" in
    *.md) ;;
    *) LC_ALL=C grep -n '[[:blank:]]$' "$path" >/dev/null && fail "$f" "trailing whitespace on line $(LC_ALL=C grep -n '[[:blank:]]$' "$path" | head -1 | cut -d: -f1)" ;;
  esac
  LC_ALL=C grep -q $'^\t' "$path" && fail "$f" "tab indentation"
done <<< "$files"

if [ "$fails" -eq 0 ]; then echo "ok: code of conduct, code owners and editorconfig rules in place"; else echo "$fails failure(s)"; exit 1; fi
