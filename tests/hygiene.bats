#!/usr/bin/env bats
# Repository basics: Code of Conduct, code owners, and every tracked text file following
# .editorconfig (LF, final newline, no trailing whitespace outside Markdown, no tab indents).

load helpers

@test "the Code of Conduct is the Contributor Covenant 2.1, filled in" {
  grep -q 'version 2.1' "$ROOT/CODE_OF_CONDUCT.md"
  ! grep -q 'INSERT' "$ROOT/CODE_OF_CONDUCT.md" || fail "placeholder left in the Code of Conduct"
}

@test "every file has a code owner and .editorconfig is the root" {
  grep -qx '\* @[A-Za-z0-9-]*' "$ROOT/.github/CODEOWNERS"
  grep -qx 'root = true' "$ROOT/.editorconfig"
}

@test "tracked text files follow .editorconfig" {
  local files f path problems=""
  files=$(git -C "$ROOT" ls-files 2>/dev/null) || skip "not a git checkout"
  while IFS= read -r f; do
    path="$ROOT/$f"
    [ -f "$path" ] || continue # submodules are folders
    LC_ALL=C grep -q $'\r' "$path" && problems="$problems$f: CRLF line endings"$'\n'
    [ -s "$path" ] && [ -n "$(tail -c 1 "$path")" ] && problems="$problems$f: no newline at the end"$'\n'
    case "$f" in
      *.md) ;;
      *) LC_ALL=C grep -q '[[:blank:]]$' "$path" && problems="$problems$f: trailing whitespace"$'\n' ;;
    esac
    [ "$f" != .gitmodules ] && LC_ALL=C grep -q $'^\t' "$path" && problems="$problems$f: tab indentation"$'\n' # git's own format
  done <<<"$files"
  [ -z "$problems" ] || fail "$problems"
}
