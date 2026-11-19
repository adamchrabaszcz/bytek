#!/usr/bin/env bash
# Undoes install.sh: puts back the original status line, removes Bytek's hooks and the
# installed copy. --purge also deletes config, state and reports in ~/.claude/bytek.
# Usage: ./uninstall.sh [--purge]
set -e

home="${BYTEK_HOME:-$HOME/.claude/bytek}"
bin="$home/app/bin/bytek"
[ -x "$bin" ] || bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin/bytek"

BYTEK_HOME="$home" "$bin" uninstall
rm -rf "$home/app"
if [ "$1" = --purge ]; then
  rm -rf "$home"
  echo "Removed $home."
fi
