#!/usr/bin/env bats
# Unit tests: lib/util.sh helpers

load '../helpers/setup'

setup() { load_libs; }

@test "size_to_bytes: gibibytes" {
  run size_to_bytes 8G
  [ "$status" -eq 0 ]
  [ "$output" -eq 8589934592 ]
}

@test "size_to_bytes: mebibytes and kibibytes" {
  [ "$(size_to_bytes 512M)" -eq 536870912 ]
  [ "$(size_to_bytes 1024K)" -eq 1048576 ]
}

@test "size_to_bytes: plain number passes through" {
  [ "$(size_to_bytes 4294967296)" -eq 4294967296 ]
}

@test "size_to_bytes: empty input fails" {
  run size_to_bytes ""
  [ "$status" -ne 0 ]
}

@test "is_managed: true only when marker present" {
  local f="$BATS_TEST_TMPDIR/f"
  printf '%s\nfoo\n' "$FLS_MARKER" >"$f"
  run is_managed "$f"
  [ "$status" -eq 0 ]
  echo "no marker" >"$f"
  run is_managed "$f"
  [ "$status" -ne 0 ]
}

@test "backup_file: dry-run creates no file but returns ok" {
  local f="$BATS_TEST_TMPDIR/orig"; echo x >"$f"
  DRY_RUN=true
  run backup_file "$f"
  [ "$status" -eq 0 ]
  run bash -c "ls $BATS_TEST_TMPDIR/orig.bak.* 2>/dev/null"
  [ "$status" -ne 0 ]
}

@test "login_users: outputs user:home format" {
  run login_users
  [ "$status" -eq 0 ]
  # every non-empty line must look like name:/path
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [[ "$line" =~ ^[^:]+:/.+ ]]
  done <<<"$output"
}
