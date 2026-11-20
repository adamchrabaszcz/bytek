#!/usr/bin/env bats
# The engine's modules (lib/*.sh) keep their shape (docs/patterns/module.md): loading one runs
# nothing and changes no shell options, its names carry the module's name, bin/bytek loads it,
# and the render path loads only what it needs.

load helpers

# Prints the modules' names: clock, hooks, locale, ...
modules() {
  local f
  for f in "$ROOT"/lib/*.sh; do
    f=${f##*/}
    printf '%s\n' "${f%.sh}"
  done
}

@test "loading a module prints nothing and changes no shell options" {
  local m problems=""
  for m in $(modules); do
    run bash -c 'before=$(set -o); . "$1"; [ "$before" = "$(set -o)" ] || echo "changed shell options"' _ "$ROOT/lib/$m.sh"
    [ -z "$output" ] || problems="$problems$m: $output"$'\n'
  done
  [ -z "$problems" ] || fail "$problems"
}

@test "a module's functions and variables start with its name" {
  local m upper problems=""
  for m in $(modules); do
    upper=$(printf '%s' "$m" | tr '[:lower:]' '[:upper:]')
    # What loading the module adds, in a shell that starts with nothing.
    run env -i bash -c 'f=$(compgen -A function); v=$(compgen -v); . "$1"
      comm -13 <(printf "%s\n" "$f" | sort) <(compgen -A function | sort) | sed "s/^/function /"
      comm -13 <(printf "%s\n" "$v" | sort) <(compgen -v | sort) | grep -vx -e f -e v | sed "s/^/variable /"' _ "$ROOT/lib/$m.sh"
    while read -r kind name; do
      case "$kind $name" in
        "function ${m}_"* | "variable ${upper}_"*) ;;
        *) problems="$problems$m: $kind $name"$'\n' ;;
      esac
    done <<<"$output"
  done
  [ -z "$problems" ] || fail "names without the module's prefix:"$'\n'"$problems"
}

@test "bin/bytek loads every module" {
  local m problems=""
  for m in $(modules); do
    grep -q "\"\$BYTEK_LIB/$m.sh\"" "$BYTEK" || problems="$problems $m"
  done
  [ -z "$problems" ] || fail "not loaded by bin/bytek:$problems"
}

@test "the render path loads neither hooks nor settings" {
  run awk '/^  render\)/ { on = 1 } on { print } on && /;;/ { exit }' "$BYTEK"
  assert_output --partial "lib/render.sh"
  refute_output --partial "hooks.sh"
  refute_output --partial "settings.sh"
}
