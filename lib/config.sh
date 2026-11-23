# shellcheck shell=bash
# shellcheck disable=SC2034 # CONFIG_<key> is this module's output, read by charset, render, hooks, preview and doctor
# config: Bytek's own settings, one "key = value" line each in $BYTEK_HOME/config/bytek: the
# charset (lib/charset.sh) and a switch for each part of Bytek, all on by default. A switch is
# off only when its line says "off"; a missing line is on, so turning one back on removes it.
# `bytek config` sets them, and `/bytek config` shows them as a checklist in Claude
# (commands/bytek.md). Plain file reads on the render path, once per render.
# Needs: nothing; from bin/bytek: BYTEK_HOME, die (config_write, config_run).

CONFIG_FILE="$BYTEK_HOME/config/bytek"
# The parts that can be turned off, in the order `bytek config` lists them.
CONFIG_SWITCHES="box antenna thought companions reminders"

# Reads CONFIG_FILE once: CONFIG_charset as written (lib/charset.sh checks it), and
# CONFIG_<switch> for each switch, "on" unless its line says "off".
config_load() {
  local line key val s
  CONFIG_charset=""
  for s in $CONFIG_SWITCHES; do printf -v "CONFIG_$s" '%s' on; done
  [ -f "$CONFIG_FILE" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'*) continue ;; esac
    [[ "$line" == *=* ]] || continue
    key=${line%%=*}
    key=${key//[[:space:]]/}
    val=${line#*=}
    val=${val//[[:space:]]/}
    case "$key" in charset) CONFIG_charset=$val ;; esac
    case " $CONFIG_SWITCHES " in *" $key "*) [ "$val" = off ] && printf -v "CONFIG_$key" '%s' off ;; esac
  done <"$CONFIG_FILE"
}

# Sets key $1 to value $2 in CONFIG_FILE, or removes its line when $2 is empty. Every other
# line stays as it is. Written to a temp file, then renamed.
config_write() {
  local line key kept=""
  if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      key=${line%%=*}
      [ "${key//[[:space:]]/}" = "$1" ] && [[ "$line" == *=* ]] && continue
      kept="$kept$line"$'\n'
    done <"$CONFIG_FILE"
  fi
  [ -n "$2" ] && kept="$kept$1 = $2"$'\n'
  mkdir -p "${CONFIG_FILE%/*}" || die "cannot create ${CONFIG_FILE%/*}"
  if ! { printf '%s' "$kept" >"$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"; }; then
    die "cannot write $CONFIG_FILE"
  fi
}

# Returns 0 when $1 names a switch.
config_is_switch() {
  [[ "$1" =~ ^[a-z]+$ ]] && [[ " $CONFIG_SWITCHES " == *" $1 "* ]]
}

# Prints every switch and its value, one "key: on|off" line each.
config_list() {
  local s
  config_load
  for s in $CONFIG_SWITCHES; do
    eval "printf '%s: %s\n' \"\$s\" \"\$CONFIG_$s\""
  done
}

# bytek config [<switch> [on|off] | reset]: without arguments, lists the switches; with a
# switch, prints its value or sets it; reset turns every switch back on (the charset and other
# lines stay).
config_run() {
  local s
  case "$#:$1" in
    0:*)
      config_list
      ;;
    1:reset)
      for s in $CONFIG_SWITCHES; do config_write "$s" ""; done
      config_list
      ;;
    1:* | 2:*)
      config_is_switch "$1" || die "unknown setting: $1 (one of: $CONFIG_SWITCHES, or reset)"
      if [ $# -eq 1 ]; then
        config_load
        eval "printf '%s\n' \"\$CONFIG_$1\""
        return 0
      fi
      case "$2" in
        on) config_write "$1" "" ;;
        off) config_write "$1" off ;;
        *) die "not a value for $1: $2 (on or off)" ;;
      esac
      printf '%s: %s\n' "$1" "$2"
      ;;
    *)
      die "usage: bytek config [<setting> [on|off] | reset]"
      ;;
  esac
}
