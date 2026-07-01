#!/usr/bin/env bash
# Modul 50-ssh-keys — authorized_keys pflegen (Default: root)
# shellcheck shell=bash
module_run() {
  local user="${SSH_KEYS_TARGET_USER:-root}"
  id -u "$user" >/dev/null 2>&1 || { log_error "50-ssh-keys: User '$user' existiert nicht."; return 1; }
  local home; home="$(getent passwd "$user" | cut -d: -f6)"
  [[ -n "$home" ]] || { log_error "50-ssh-keys: kein Home für '$user'."; return 1; }
  local akf="$home/.ssh/authorized_keys"

  if [[ ${#SSH_KEYS_ADD[@]} -eq 0 && ${#SSH_KEYS_REMOVE[@]} -eq 0 && ${#SSH_KEYS_KEEP_ONLY[@]} -eq 0 ]]; then
    log_info "50-ssh-keys: nichts konfiguriert."; return 0
  fi

  # aktuelle Keys in Temp laden
  local tmp; tmp="$(mktemp)"
  [[ -f "$akf" ]] && cp "$akf" "$tmp"

  if [[ ${#SSH_KEYS_KEEP_ONLY[@]} -gt 0 ]]; then
    log_warn "50-ssh-keys: KEEP_ONLY gesetzt — alle anderen Keys werden entfernt."
    : >"$tmp"
    local k; for k in "${SSH_KEYS_KEEP_ONLY[@]}"; do [[ -n "$k" ]] && printf '%s\n' "$k" >>"$tmp"; done
  else
    local pat
    for pat in "${SSH_KEYS_REMOVE[@]}"; do
      [[ -n "$pat" ]] || continue
      grep -vF -- "$pat" "$tmp" >"$tmp.n" || true
      mv "$tmp.n" "$tmp"
    done
    local key
    for key in "${SSH_KEYS_ADD[@]}"; do
      [[ -n "$key" ]] || continue
      grep -qF -- "$key" "$tmp" 2>/dev/null || printf '%s\n' "$key" >>"$tmp"
    done
  fi

  local n; n="$(grep -c . "$tmp" 2>/dev/null || echo 0)"
  if [[ "${DRY_RUN:-false}" == true ]]; then
    ui_say "  ${C_YEL}[dry-run]${C_RESET} würde $akf schreiben ($n Keys)"
  else
    install -d -m 0700 -o "$user" -g "$user" "$home/.ssh" 2>/dev/null || install -d -m 0700 "$home/.ssh"
    [[ -f "$akf" ]] && backup_file "$akf"
    install -m 0600 "$tmp" "$akf"
    chown "$user" "$akf" 2>/dev/null || true
    log_info "50-ssh-keys: $akf aktualisiert ($n Keys)."
  fi
  rm -f "$tmp" "$tmp.n" 2>/dev/null || true
}
