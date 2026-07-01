#!/usr/bin/env bats
# Unit tests: 55-ssh-harden lockout failsafe (dry-run)

load '../helpers/setup'

setup() {
  load_libs
  setup_shims
  DRY_RUN=true
  SSH_HARDEN=true
  SSH_PORT=22
  SSH_KEYS_TARGET_USER=root
  HOME_T="$BATS_TEST_TMPDIR/roothome"
  mkdir -p "$HOME_T/.ssh"
  # getent returns our fake home for the target user
  shim getent <<EOF
#!/usr/bin/env bash
echo "root:x:0:0::$HOME_T:/bin/bash"
EOF
}

@test "aborts (rc!=0) when target user has NO authorized_keys" {
  run run_module 55-ssh-harden
  [ "$status" -ne 0 ]
  [[ "$output" == *ABORT* || "$output" == *lockout* || "$output" == *keys* ]]
}

@test "aborts when authorized_keys exists but is empty" {
  : >"$HOME_T/.ssh/authorized_keys"
  run run_module 55-ssh-harden
  [ "$status" -ne 0 ]
}

@test "proceeds (rc=0) in dry-run when a valid key is present" {
  echo "ssh-ed25519 AAAAExampleKeyData test@host" >"$HOME_T/.ssh/authorized_keys"
  run run_module 55-ssh-harden
  [ "$status" -eq 0 ]
}

@test "disabled when SSH_HARDEN=false" {
  SSH_HARDEN=false
  run run_module 55-ssh-harden
  [ "$status" -eq 0 ]
  [[ "$output" == *disabled* ]]
}
