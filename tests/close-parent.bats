#!/usr/bin/env bats
# When tools/close-parent.sh decides to close a parent issue.

load helpers

TOOL="$ROOT/tools/close-parent.sh"

@test "the parent closes when its last sub-issue is done" {
  run "$TOOL" --decide "12 OPEN 3 3"
  assert_output "close"
}

@test "the parent stays open while sub-issues remain" {
  run "$TOOL" --decide "12 OPEN 2 3"
  assert_output "parent #12: 2 of 3 sub-issues done"
}

@test "an already closed parent is left alone" {
  run "$TOOL" --decide "12 CLOSED 3 3"
  assert_output "parent #12 is already closed"
}

@test "an issue without a parent does nothing" {
  run "$TOOL" --decide ""
  assert_output "no parent"
}

@test "without REPO it prints usage and exits 2" {
  REPO='' run "$TOOL" 5
  assert_failure 2
}
