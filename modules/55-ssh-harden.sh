#!/usr/bin/env bash
# Modul 55-ssh-harden — SSH härten (nur Key-Login)
# FAILSAFE: Passwort-Login NIE deaktivieren, wenn keine Keys vorhanden sind.
# shellcheck shell=bash
module_run() {
  [[ "${SSH_HARDEN:-false}" == true ]] || { log_info "55-ssh-harden: deaktiviert."; return 0; }

  # --- FAILSAFE: mind. ein gültiger Key für den Ziel-User? ---
  local user="${SSH_KEYS_TARGET_USER:-root}"
  local home akf
  home="$(getent passwd "$user" | cut -d: -f6)"
  akf="$home/.ssh/authorized_keys"
  if [[ ! -s "$akf" ]] || ! grep -qE '^(ssh|ecdsa|sk-)' "$akf" 2>/dev/null; then
    log_error "55-ssh-harden: ABBRUCH — keine SSH-Keys für '$user' ($akf). Aussperr-Schutz."
    return 1
  fi
  log_info "55-ssh-harden: Keys für '$user' vorhanden — Härtung wird angewendet."

  # --- sshd-Konfiguration als Drop-in (mit Backup) ---
  local dropdir="/etc/ssh/sshd_config.d"
  local conf="$dropdir/60-admincave-hardening.conf"
  run install -d -m 0755 "$dropdir"
  [[ -f "$conf" ]] && backup_file "$conf"

  {
    echo "$FLS_MARKER"
    echo "PasswordAuthentication no"
    echo "PubkeyAuthentication yes"
    echo "KbdInteractiveAuthentication no"
    echo "ChallengeResponseAuthentication no"
    echo "PermitRootLogin prohibit-password"
    [[ "${SSH_PORT:-22}" != "22" ]] && echo "Port ${SSH_PORT}"
  } | write_file "$conf" 0644 root

  # --- Validieren VOR Reload ---
  if [[ "${DRY_RUN:-false}" == true ]]; then
    ui_say "  ${C_YEL}[dry-run]${C_RESET} würde 'sshd -t' prüfen und ssh neu laden"
    return 0
  fi

  if sshd -t 2>/tmp/sshd-test.err; then
    run systemctl reload ssh 2>/dev/null || run systemctl reload sshd
    log_info "55-ssh-harden: sshd-Konfiguration gültig, neu geladen."
  else
    log_error "55-ssh-harden: sshd-Konfigtest fehlgeschlagen — rolle Drop-in zurück!"
    rm -f "$conf"
    cat /tmp/sshd-test.err >>"$FLS_LOG" 2>/dev/null || true
    return 1
  fi
}
