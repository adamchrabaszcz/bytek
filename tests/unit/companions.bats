#!/usr/bin/env bats
# lib/companions.sh: the names given to companions, reading them and setting them.
# COMPANIONS_* are set by the module under test, and each test runs in its own subshell on purpose:
# shellcheck disable=SC2154,SC2030,SC2031

load ../helpers

setup() {
  bytek_setup
  load_module companions
  mkdir -p "$BYTEK_HOME/config"
}

@test "a companion's name comes from its line; no file or no line means no name" {
  companions_name dog
  assert_equal "[$REPLY]" "[]"
  printf '%s\n' "# names" "meal=Soup" "  dog  =  Rex  " >"$BYTEK_HOME/config/companions"
  companions_name dog
  assert_equal "$REPLY" Rex
  companions_name meal
  assert_equal "$REPLY" Soup
  companions_name report
  assert_equal "[$REPLY]" "[]"
}

@test "a name read from the file loses control characters and is cut to 20 characters" {
  printf 'dog = R\033[31mex\a and a very long name indeed\n' >"$BYTEK_HOME/config/companions"
  companions_name dog
  assert_equal "$REPLY" "R[31mex and a very l"
}

@test "setting a name replaces that companion's line and keeps the others" {
  printf '%s\n' "# mine" "meal = Soup" "dog = Old" >"$BYTEK_HOME/config/companions"
  companions_set dog Rex the Second
  run cat "$BYTEK_HOME/config/companions"
  assert_output $'# mine\nmeal = Soup\ndog = Rex the Second'
}

@test "no name takes the name away" {
  printf '%s\n' "meal = Soup" "dog = Rex" >"$BYTEK_HOME/config/companions"
  companions_set dog
  run cat "$BYTEK_HOME/config/companions"
  assert_output "meal = Soup"
}

@test "an unknown companion or a name with = is refused, the file unchanged" {
  printf 'dog = Rex\n' >"$BYTEK_HOME/config/companions"
  run companions_set cat Tom
  assert_failure
  assert_output --partial "unknown companion: cat"
  run companions_set ../faces/idle Tom
  assert_failure
  run companions_set dog "a=b"
  assert_failure
  run cat "$BYTEK_HOME/config/companions"
  assert_output "dog = Rex"
}

@test "without arguments it lists every companion with its name" {
  companions_set dog Rex
  run companions_set
  assert_line "dog       Rex"
  assert_line "meal      (no name)"
}
