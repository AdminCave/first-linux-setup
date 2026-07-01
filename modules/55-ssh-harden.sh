#!/usr/bin/env bash
# Module 55-ssh-harden — Harden SSH (key login only)
# FAILSAFE: NEVER disable password login when no keys are present.
# shellcheck shell=bash
module_run() {
  [[ "${SSH_HARDEN:-false}" == true ]] || { log_info "55-ssh-harden: disabled."; return 0; }

  # --- FAILSAFE: at least one valid key for the target user? ---
  local user="${SSH_KEYS_TARGET_USER:-root}"
  local home akf
  home="$(getent passwd "$user" | cut -d: -f6)"
  akf="$home/.ssh/authorized_keys"
  if [[ ! -s "$akf" ]] || ! grep -qE '^(ssh|ecdsa|sk-)' "$akf" 2>/dev/null; then
    log_error "55-ssh-harden: ABORT — no SSH keys for '$user' ($akf). Lockout protection."
    return 1
  fi
  log_info "55-ssh-harden: keys present for '$user' — applying hardening."

  # --- sshd configuration as drop-in (with backup) ---
  local dropdir="/etc/ssh/sshd_config.d"
  local conf="$dropdir/60-admincave-hardening.conf"
  fls_run install -d -m 0755 "$dropdir"
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

  # --- Validate BEFORE reload ---
  if [[ "${DRY_RUN:-false}" == true ]]; then
    ui_say "  ${C_YEL}[dry-run]${C_RESET} would check 'sshd -t' and reload ssh"
    return 0
  fi

  if sshd -t 2>/tmp/sshd-test.err; then
    fls_run systemctl reload ssh 2>/dev/null || fls_run systemctl reload sshd
    log_info "55-ssh-harden: sshd configuration valid, reloaded."
  else
    log_error "55-ssh-harden: sshd config test failed — rolling back drop-in!"
    rm -f "$conf"
    cat /tmp/sshd-test.err >>"$FLS_LOG" 2>/dev/null || true
    return 1
  fi
}
