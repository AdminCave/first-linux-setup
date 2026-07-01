#!/usr/bin/env bash
# Module 60-passwords — root and admin user passwords (with prompt per user)
# shellcheck shell=bash
_change_pw() {
  local u="$1"
  if [[ "${DRY_RUN:-false}" == true ]]; then
    ui_say "  ${C_YEL}[dry-run]${C_RESET} would call 'passwd $u' interactively"
    return 0
  fi
  passwd "$u" || log_warn "60-passwords: passwd for '$u' aborted."
}

module_run() {
  # root
  if [[ "${PROMPT_ROOT_PASSWORD:-true}" == true ]]; then
    if ask_yes_no "Change root password now?" n; then
      log_info "60-passwords: changing root password"
      _change_pw root
    fi
  fi

  # Admin users: only if present, then prompt
  local u
  for u in "${ADMIN_USERS_PROMPT[@]}"; do
    [[ -n "$u" ]] || continue
    if id -u "$u" >/dev/null 2>&1; then
      if ask_yes_no "User '$u' exists — change password?" n; then
        log_info "60-passwords: changing password for '$u'"
        _change_pw "$u"
      fi
    fi
  done
}
