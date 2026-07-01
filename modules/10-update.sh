#!/usr/bin/env bash
# Module 10-update — Update system
# shellcheck shell=bash
module_run() {
  [[ "${RUN_UPDATE:-false}" == true || "${RUN_UPGRADE:-false}" == true ]] \
    || { log_info "10-update: disabled — skipped."; return 0; }

  export DEBIAN_FRONTEND=noninteractive

  if [[ "${RUN_UPDATE:-false}" == true ]]; then
    log_info "10-update: apt-get update"
    fls_run apt-get update
  fi
  if [[ "${RUN_UPGRADE:-false}" == true ]]; then
    log_info "10-update: apt-get dist-upgrade"
    fls_run apt-get -y -o Dpkg::Options::=--force-confold dist-upgrade
    fls_run apt-get -y autoremove --purge
  fi
}
