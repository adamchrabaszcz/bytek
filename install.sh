#!/usr/bin/env bash
# Installs Bytek without the plugin system: copies this checkout to ~/.claude/bytek/app,
# then makes it the status line and adds its hooks (settings.json is backed up first).
# Usage: ./install.sh
set -e

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
home="${BYTEK_HOME:-$HOME/.claude/bytek}"
command -v jq >/dev/null 2>&1 || {
  echo "install.sh: Bytek's setup needs jq (https://jqlang.org)" >&2
  exit 1
}

rm -rf "$home/app.new"
mkdir -p "$home/app.new"
tar -C "$src" --exclude .git --exclude ./coverage -cf - . | tar -C "$home/app.new" -xf -
rm -rf "$home/app"
mv "$home/app.new" "$home/app"

BYTEK_HOME="$home" "$home/app/bin/bytek" setup --hooks
