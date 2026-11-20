#!/usr/bin/env bats
# The docs agents and contributors rely on keep their shape: AGENTS.md small enough to load
# whole and the one instruction file, ADRs numbered and listed, patterns with their anti-pattern.

load helpers

@test "AGENTS.md stays under 10 KB" {
  local size
  size=$(wc -c <"$ROOT/AGENTS.md")
  [ "$size" -lt 10240 ] || fail "AGENTS.md is $size bytes; move details to CONTRIBUTING.md or docs/"
}

@test "AGENTS.md is the only instruction file" {
  # Claude Code reads AGENTS.md only when no CLAUDE.md is around; one would replace it.
  local f found=""
  for f in CLAUDE.md .claude/CLAUDE.md CLAUDE.local.md; do
    [ -e "$ROOT/$f" ] && found="$found $f"
  done
  [ -z "$found" ] || fail "found$found: Claude Code would read it instead of AGENTS.md"
}

@test "ADRs are numbered, unique, have a status and are listed in the index" {
  local f name num problems="" seen=" "
  for f in "$ROOT"/docs/adr/*.md; do
    name=${f##*/}
    [ "$name" = README.md ] && continue
    [[ "$name" =~ ^[0-9]{4}-[a-z0-9-]+\.md$ ]] || problems="$problems$name: not NNNN-title.md"$'\n'
    num=${name%%-*}
    case "$seen" in *" $num "*) problems="$problems$name: number $num used twice"$'\n' ;; esac
    seen="$seen$num "
    grep -q '^- Status: ' "$f" || problems="$problems$name: no '- Status:' line"$'\n'
    grep -q "($name)" "$ROOT/docs/adr/README.md" || problems="$problems$name: not listed in docs/adr/README.md"$'\n'
  done
  [ -z "$problems" ] || fail "$problems"
}

@test "every pattern has its anti-pattern and is listed in the index" {
  local f name problems=""
  for f in "$ROOT"/docs/patterns/*.md; do
    name=${f##*/}
    [ "$name" = README.md ] && continue
    grep -qx '## Anti-pattern' "$f" || problems="$problems$name: no '## Anti-pattern' section"$'\n'
    grep -q "($name)" "$ROOT/docs/patterns/README.md" || problems="$problems$name: not listed in docs/patterns/README.md"$'\n'
  done
  [ -z "$problems" ] || fail "$problems"
}

@test "working notes in .plan/ are ignored" {
  git -C "$ROOT" rev-parse 2>/dev/null || skip "not a git checkout"
  git -C "$ROOT" check-ignore -q .plan/notes.md || fail ".plan/ is not in .gitignore"
}
