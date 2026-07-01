#!/usr/bin/env bash
# Module 70-fail2ban — Install fail2ban + SSH jail
# shellcheck shell=bash
module_run() {
  [[ "${FAIL2BAN_ENABLE:-false}" == true ]] || { log_info "70-fail2ban: disabled."; return 0; }

  if ! have fail2ban-client && ! pkg_installed fail2ban; then
    log_info "70-fail2ban: installing fail2ban"
    export DEBIAN_FRONTEND=noninteractive
    fls_run apt-get -y install fail2ban || { log_warn "70-fail2ban: installation failed."; return 1; }
  fi

  local jail="/etc/fail2ban/jail.d/admincave-sshd.local"
  {
    echo "$FLS_MARKER"
    echo "[sshd]"
    echo "enabled = true"
    echo "port    = ${SSH_PORT:-22}"
    echo "maxretry = ${FAIL2BAN_SSH_MAXRETRY:-10}"
    echo "bantime  = ${FAIL2BAN_SSH_BANTIME:-3600}"
    echo "findtime = ${FAIL2BAN_SSH_FINDTIME:-600}"
  } | write_file "$jail" 0644 root

  fls_run systemctl enable --now fail2ban
  [[ "${DRY_RUN:-false}" == true ]] || fls_run systemctl reload fail2ban 2>/dev/null || true
  log_info "70-fail2ban: SSH jail configured (maxretry=${FAIL2BAN_SSH_MAXRETRY} bantime=${FAIL2BAN_SSH_BANTIME})."
}
