#!/usr/bin/env bats
# Integration (Crabbox): real, mutating run on a fresh Debian box.
# Guarded twice: requires root AND FLS_ALLOW_REAL=1 so it never runs by accident.
# Kept SSH-safe: hardening is disabled so we don't cut our own connection.

load '../helpers/setup'

setup() {
  [ "$(id -u)" -eq 0 ] || skip "needs root"
  [ "${FLS_ALLOW_REAL:-0}" = 1 ] || skip "set FLS_ALLOW_REAL=1 to run mutating tests"
}

@test "real run: deploys bashrc, installs a package, and is idempotent" {
  local cfg="$BATS_TEST_TMPDIR/it.conf"
  cat >"$cfg" <<'EOF'
SSH_HARDEN=false
INSTALL_FASTFETCH=false
FAIL2BAN_ENABLE=false
RUN_UPGRADE=false
RUN_UPDATE=true
DEPLOY_BASHRC=true
PROMPT_ROOT_PASSWORD=false
PACKAGES_INSTALL=(tree)
PACKAGES_INSTALL_BAREMETAL=()
PACKAGES_REMOVE=()
FILES_REMOVE=()
EOF

  export FLS_CONFIG="$cfg"   # must be exported so setup.sh (a child process) sees it

  run bash "$REPO_ROOT/setup.sh" --yes
  [ "$status" -eq 0 ]

  # bashrc deployed with our managed marker
  grep -q "Managed by AdminCave first-linux-setup" /root/.bashrc

  # package really installed
  command -v tree

  # second run: bashrc is idempotent (already up to date)
  run bash "$REPO_ROOT/setup.sh" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"already up to date"* ]]
}
