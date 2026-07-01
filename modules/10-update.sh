#!/usr/bin/env bash
# Modul 10-update — System aktualisieren
# shellcheck shell=bash
module_run() {
  [[ "${RUN_UPDATE:-false}" == true || "${RUN_UPGRADE:-false}" == true ]] \
    || { log_info "10-update: deaktiviert — übersprungen."; return 0; }

  export DEBIAN_FRONTEND=noninteractive

  if [[ "${RUN_UPDATE:-false}" == true ]]; then
    log_info "10-update: apt-get update"
    run apt-get update
  fi
  if [[ "${RUN_UPGRADE:-false}" == true ]]; then
    log_info "10-update: apt-get dist-upgrade"
    run apt-get -y -o Dpkg::Options::=--force-confold dist-upgrade
    run apt-get -y autoremove --purge
  fi
}
