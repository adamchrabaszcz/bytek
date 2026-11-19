#!/usr/bin/env bats
# The issue forms: blank issues off, every form has the CONTRIBUTING sections (What and why
# and Done when required, Blast radius and Parent optional) and a known label.

load helpers

DIR="$ROOT/.github/ISSUE_TEMPLATE"

# Prints "label|required;" for each field of a form, required being true or false.
fields() {
  awk '
    /^  - type:/ { if (label != "") print label "|" req; label = ""; req = "false" }
    /^      label:/ { sub(/^      label: */, ""); label = $0 }
    /^      required: true/ { req = "true" }
    END { if (label != "") print label "|" req }
  ' "$1" | tr '\n' ';'
}

@test "blank issues are turned off" {
  grep -qx 'blank_issues_enabled: false' "$DIR/config.yml"
}

@test "there are three forms, each with the four sections and a known label" {
  local form forms=0 label
  for form in "$DIR"/*.yml; do
    [ "${form##*/}" = config.yml ] && continue
    forms=$((forms + 1))
    assert_equal "$(fields "$form")" "What and why|true;Done when|true;Blast radius|false;Parent|false;"
    label=$(sed -n 's/^labels: \[\(.*\)\]$/\1/p' "$form")
    case " enhancement bug chore " in *" $label "*) ;; *) fail "${form##*/}: unknown label '$label'" ;; esac
  done
  assert_equal "$forms" 3
}
