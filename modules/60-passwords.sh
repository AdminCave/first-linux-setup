#!/usr/bin/env bash
# Modul 60-passwords — root- und Admin-User-Passwörter (mit Rückfrage pro User)
# shellcheck shell=bash
_change_pw() {
  local u="$1"
  if [[ "${DRY_RUN:-false}" == true ]]; then
    ui_say "  ${C_YEL}[dry-run]${C_RESET} würde 'passwd $u' interaktiv aufrufen"
    return 0
  fi
  passwd "$u" || log_warn "60-passwords: passwd für '$u' abgebrochen."
}

module_run() {
  # root
  if [[ "${PROMPT_ROOT_PASSWORD:-true}" == true ]]; then
    if ask_yes_no "root-Passwort jetzt ändern?" n; then
      log_info "60-passwords: ändere root-Passwort"
      _change_pw root
    fi
  fi

  # Admin-User: nur wenn vorhanden, dann fragen
  local u
  for u in "${ADMIN_USERS_PROMPT[@]}"; do
    [[ -n "$u" ]] || continue
    if id -u "$u" >/dev/null 2>&1; then
      if ask_yes_no "Benutzer '$u' existiert — Passwort ändern?" n; then
        log_info "60-passwords: ändere Passwort für '$u'"
        _change_pw "$u"
      fi
    fi
  done
}
