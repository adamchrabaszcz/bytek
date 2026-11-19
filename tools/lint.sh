#!/usr/bin/env bash
# Lints and format-checks every shell file in the repository: ShellCheck (settings in
# .shellcheckrc) and shfmt (settings in .editorconfig). CI runs the same.
#
#   tools/lint.sh            check; exits 1 on any finding or formatting difference
#   tools/lint.sh --fix      let shfmt rewrite the formatting (ShellCheck findings are fixed by hand)
#   tools/lint.sh --files    list the files it checks
# SHELLCHECK and SHFMT name the tools to run (default: from PATH), e.g. for tests.

shellcheck=${SHELLCHECK:-shellcheck}
shfmt=${SHFMT:-shfmt}
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 2

# Shell files: bin/, *.sh, *.bash and *.bats that git tracks (vendored bats is a submodule, so
# its files aren't listed). Outside a git checkout, the same patterns by name.
list=$(git ls-files 'bin/*' '*.sh' '*.bash' '*.bats' 2>/dev/null ||
  find bin tools tests install.sh uninstall.sh -path tests/bats -prune -o -type f \
    \( -path 'bin/*' -o -name '*.sh' -o -name '*.bash' -o -name '*.bats' \) -print)
files=()
while IFS= read -r f; do
  if [ -f "$f" ]; then files+=("$f"); fi
done <<EOF
$list
EOF

case "${1:-}" in
  --files)
    printf '%s\n' "${files[@]}"
    exit 0
    ;;
  --fix)
    exec "$shfmt" -w "${files[@]}"
    ;;
  "") ;;
  *)
    sed -n '2,10s/^# \{0,1\}//p' "$0"
    exit 2
    ;;
esac

for tool in "$shellcheck" "$shfmt"; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "tools/lint.sh: $tool is not installed (macOS: brew install shellcheck shfmt)" >&2
    exit 2
  }
done

status=0
echo "ShellCheck ($("$shellcheck" --version | sed -n 's/^version: //p')), ${#files[@]} files"
"$shellcheck" "${files[@]}" || status=1
echo "shfmt ($("$shfmt" --version))"
"$shfmt" -d "${files[@]}" || status=1
[ "$status" -eq 0 ] && echo "lint: clean"
exit $status
