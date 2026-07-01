#!/usr/bin/env bats
# Unit tests: modules respect their enable flags / profile gating (dry-run)

load '../helpers/setup'

setup() {
  load_libs
  # shellcheck source=/dev/null
  source "$FLS_DIR/profiles/defaults.conf"   # all config keys defined
  DRY_RUN=true
  FLS_PROFILE=debian-server                   # non-Proxmox by default
  DETECTED_VIRT=none; DETECTED_CONTAINER=no
}

@test "10-update: disabled when RUN_UPDATE and RUN_UPGRADE are false" {
  RUN_UPDATE=false RUN_UPGRADE=false
  run run_module 10-update
  [ "$status" -eq 0 ]
  [[ "$output" == *disabled* ]]
}

@test "40-bashrc: disabled when DEPLOY_BASHRC=false" {
  DEPLOY_BASHRC=false
  run run_module 40-bashrc
  [ "$status" -eq 0 ]
  [[ "$output" == *disabled* ]]
}

@test "45-fastfetch: disabled when INSTALL_FASTFETCH=false" {
  INSTALL_FASTFETCH=false
  run run_module 45-fastfetch
  [ "$status" -eq 0 ]
  [[ "$output" == *disabled* ]]
}

@test "70-fail2ban: disabled when FAIL2BAN_ENABLE=false" {
  FAIL2BAN_ENABLE=false
  run run_module 70-fail2ban
  [ "$status" -eq 0 ]
  [[ "$output" == *disabled* ]]
}

@test "25-time-ntp: MANAGE=never skips" {
  NTP_MANAGE=never
  run run_module 25-time-ntp
  [ "$status" -eq 0 ]
  [[ "$output" == *never* ]]
}

@test "80-proxmox-repos: skipped on non-Proxmox profile" {
  FLS_PROFILE=debian-server
  run run_module 80-proxmox-repos
  [ "$status" -eq 0 ]
  [[ "$output" == *"no Proxmox profile"* ]]
}

@test "85-proxmox-tuning: skipped on non-Proxmox profile" {
  FLS_PROFILE=ubuntu-server
  run run_module 85-proxmox-tuning
  [ "$status" -eq 0 ]
  [[ "$output" == *"no Proxmox profile"* ]]
}

@test "35-guest-agent: skipped on bare metal" {
  DETECTED_VIRT=none DETECTED_CONTAINER=no
  run run_module 35-guest-agent
  [ "$status" -eq 0 ]
  [[ "$output" == *"not a VM"* ]]
}

@test "35-guest-agent: disabled when GUEST_AGENT_INSTALL=false" {
  GUEST_AGENT_INSTALL=false
  run run_module 35-guest-agent
  [ "$status" -eq 0 ]
  [[ "$output" == *disabled* ]]
}
