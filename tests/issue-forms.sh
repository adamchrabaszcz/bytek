#!/usr/bin/env bash
# Checks the issue forms: blank issues off, every form has the CONTRIBUTING sections
# (What and why and Done when required, Blast radius and Parent optional) and a known label.
# Usage: tests/issue-forms.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/.github/ISSUE_TEMPLATE"
LABELS="enhancement bug chore"

fails=0
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; fails=$((fails + 1)); }

grep -qx 'blank_issues_enabled: false' "$DIR/config.yml" || fail config "blank issues are not turned off"

# Prints "label|required" for each field of a form, required being true or false.
fields() {
  awk '
    /^  - type:/ { if (label != "") print label "|" req; label = ""; req = "false" }
    /^      label:/ { sub(/^      label: */, ""); label = $0 }
    /^      required: true/ { req = "true" }
    END { if (label != "") print label "|" req }
  ' "$1"
}

forms=0
for form in "$DIR"/*.yml; do
  name=${form##*/}
  [ "$name" = config.yml ] && continue
  forms=$((forms + 1))
  got=$(fields "$form" | tr '\n' ';')
  want="What and why|true;Done when|true;Blast radius|false;Parent|false;"
  [ "$got" = "$want" ] || fail "$name" "fields: expected '$want', got '$got'"
  label=$(sed -n 's/^labels: \[\(.*\)\]$/\1/p' "$form")
  case " $LABELS " in *" $label "*) ;; *) fail "$name" "unknown label '$label'" ;; esac
done
[ "$forms" -eq 3 ] || fail forms "expected 3 forms, found $forms"

if [ "$fails" -eq 0 ]; then echo "ok: issue forms match the contributing format"; else echo "$fails failure(s)"; exit 1; fi
