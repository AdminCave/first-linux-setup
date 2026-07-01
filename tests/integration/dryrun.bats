#!/usr/bin/env bats
# Integration: full setup.sh --dry-run on a real box (root). No changes made.

load '../helpers/setup'

setup() {
  [ "$(id -u)" -eq 0 ] || skip "needs root (setup.sh requires root)"
}

@test "setup.sh --dry-run completes cleanly and changes nothing" {
  run bash "$REPO_ROOT/setup.sh" --dry-run --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN active"* ]]
  [[ "$output" == *"Done"* ]]
  [[ "$output" == *"NO changes were made"* ]]
}
