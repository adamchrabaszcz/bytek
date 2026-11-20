# shellcheck shell=bash
# settings: makes Bytek the status line in Claude Code's settings.json (setup) and takes it
# out again (uninstall). Every edit backs the file up first and goes through a jq program in
# lib/, checked before it replaces the file.
# Needs: clock; from bin/bytek: BYTEK_ROOT, BYTEK_HOME, BYTEK_SETTINGS, die.

# A status line or hook command that runs Bytek ("…/bin/bytek render", quoted or not).
SETTINGS_CMD_RE='/bin/bytek"? (render|hook)$'

# Applies the jq program lib/$1 to settings.json, with jq options after it. Writes a temp
# file first and checks it, so a failed edit leaves settings.json as it was.
settings_edit() {
  local program="$BYTEK_ROOT/lib/$1" tmp
  shift
  tmp=$(mktemp "$BYTEK_SETTINGS.XXXXXX") || return 1
  if jq --arg bytek_re "$SETTINGS_CMD_RE" "$@" -f "$program" "$BYTEK_SETTINGS" >"$tmp" &&
    jq -e . "$tmp" >/dev/null 2>&1; then
    # cat, not mv: settings.json may be a symlink (dotfiles) and must stay one.
    cat "$tmp" >"$BYTEK_SETTINGS"
    rm -f "$tmp"
  else
    rm -f "$tmp"
    return 1
  fi
}

# bytek setup [--hooks]: Bytek as the status line; --hooks also adds the hooks.
settings_setup() {
  local with_hooks=false bin backup original="$BYTEK_HOME/original-statusline.json"
  [ "$1" = --hooks ] && with_hooks=true
  command -v jq >/dev/null 2>&1 || die "setup needs jq (https://jqlang.org)"
  mkdir -p "$BYTEK_HOME/backup" "$BYTEK_HOME/state" || die "cannot create $BYTEK_HOME"
  ln -sfn "$BYTEK_ROOT" "$BYTEK_HOME/current" || die "cannot link $BYTEK_HOME/current"
  bin="$BYTEK_HOME/current/bin/bytek"

  mkdir -p "$(dirname "$BYTEK_SETTINGS")"
  [ -f "$BYTEK_SETTINGS" ] || printf '{}\n' >"$BYTEK_SETTINGS"
  jq -e 'type == "object"' "$BYTEK_SETTINGS" >/dev/null 2>&1 || die "$BYTEK_SETTINGS is not a JSON object; not touching it"
  clock_stamp
  backup="$BYTEK_HOME/backup/settings.json.$REPLY"
  cp -p "$BYTEK_SETTINGS" "$backup" || die "cannot back up $BYTEK_SETTINGS"

  # Remember the status line Bytek replaces, once, and never Bytek's own.
  if [ ! -f "$original" ]; then
    jq --arg bytek_re "$SETTINGS_CMD_RE" -f "$BYTEK_ROOT/lib/original-statusline.jq" "$BYTEK_SETTINGS" \
      >"$original" || {
      rm -f "$original"
      die "cannot write $original"
    }
  fi

  settings_edit setup.jq --arg render "\"$bin\" render" --arg hook "\"$bin\" hook" \
    --argjson with_hooks "$with_hooks" --slurpfile plugin "$BYTEK_ROOT/hooks/hooks.json" ||
    die "could not update $BYTEK_SETTINGS (unchanged; backup in $backup)"

  printf 'Bytek is your status line now.\n'
  printf '  settings backup: %s\n' "$backup"
  if jq -f "$BYTEK_ROOT/lib/saved-statusline.jq" "$original" | jq -e '.statusLine != null' >/dev/null 2>&1; then
    printf '  your previous status line is saved in %s and comes back with: bytek uninstall\n' "$original"
  fi
  $with_hooks && printf '  hooks added to %s\n' "$BYTEK_SETTINGS"
  return 0
}

# bytek uninstall: puts back the status line Bytek replaced and removes Bytek's hooks.
settings_uninstall() {
  local original="$BYTEK_HOME/original-statusline.json" saved=null known=true info backup
  command -v jq >/dev/null 2>&1 || die "uninstall needs jq (https://jqlang.org)"
  [ -f "$BYTEK_SETTINGS" ] || {
    echo "Nothing to do: no $BYTEK_SETTINGS"
    return 0
  }
  if [ -s "$original" ]; then
    info=$(jq -c -f "$BYTEK_ROOT/lib/saved-statusline.jq" "$original") || die "cannot read $original"
    known=$(printf '%s' "$info" | jq -r .known)
    saved=$(printf '%s' "$info" | jq -c .statusLine)
  fi
  mkdir -p "$BYTEK_HOME/backup"
  clock_stamp
  backup="$BYTEK_HOME/backup/settings.json.$REPLY.before-uninstall"
  cp -p "$BYTEK_SETTINGS" "$backup" || die "cannot back up $BYTEK_SETTINGS"

  settings_edit uninstall.jq --argjson saved "$saved" ||
    die "could not update $BYTEK_SETTINGS (unchanged; backup in $backup)"
  rm -f "$BYTEK_HOME/current"
  if [ "$known" = true ]; then
    rm -f "$original"
  else
    printf 'Kept %s: a newer Bytek saved it, in a format this version can'"'"'t read.\n' "$original"
  fi
  printf 'Bytek is off. Settings backup: %s\n' "$backup"
  printf 'Your config and state stay in %s (delete it to remove everything).\n' "$BYTEK_HOME"
}
