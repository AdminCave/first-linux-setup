#!/usr/bin/env bash
# Modul 70-fail2ban — fail2ban installieren + SSH-Jail
# shellcheck shell=bash
module_run() {
  [[ "${FAIL2BAN_ENABLE:-false}" == true ]] || { log_info "70-fail2ban: deaktiviert."; return 0; }

  if ! have fail2ban-client && ! pkg_installed fail2ban; then
    log_info "70-fail2ban: installiere fail2ban"
    export DEBIAN_FRONTEND=noninteractive
    run apt-get -y install fail2ban || { log_warn "70-fail2ban: Installation fehlgeschlagen."; return 1; }
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

  run systemctl enable --now fail2ban
  [[ "${DRY_RUN:-false}" == true ]] || run systemctl reload fail2ban 2>/dev/null || true
  log_info "70-fail2ban: SSH-Jail konfiguriert (maxretry=${FAIL2BAN_SSH_MAXRETRY} bantime=${FAIL2BAN_SSH_BANTIME})."
}
