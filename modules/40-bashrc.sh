#!/usr/bin/env bash
# Modul 40-bashrc — bashrc-Template ausrollen (root + /etc/skel + alle Login-User)
# shellcheck shell=bash
module_run() {
  [[ "${DEPLOY_BASHRC:-false}" == true ]] || { log_info "40-bashrc: deaktiviert."; return 0; }
  local tpl="$FLS_DIR/assets/bashrc.template"
  [[ -r "$tpl" ]] || { log_error "40-bashrc: Template fehlt: $tpl"; return 1; }

  # Zielmenge: "owner:home"
  local targets=("root:/root" "root:/etc/skel")
  if [[ "${BASHRC_ALL_USERS:-true}" == true ]]; then
    local line
    while IFS= read -r line; do
      targets+=("${line%%:*}:${line##*:}")
    done < <(login_users)
  fi

  local entry owner home dest
  for entry in "${targets[@]}"; do
    owner="${entry%%:*}"; home="${entry##*:}"
    [[ -d "$home" ]] || { run install -d -m 0755 "$home"; }
    dest="$home/.bashrc"
    # Idempotenz: bereits identisch -> nichts tun
    if cmp -s "$tpl" "$dest" 2>/dev/null; then
      log_info "40-bashrc: $dest bereits aktuell — übersprungen."
      continue
    fi
    [[ "${BASHRC_BACKUP:-true}" == true ]] && backup_file "$dest"
    if [[ "${DRY_RUN:-false}" == true ]]; then
      ui_say "  ${C_YEL}[dry-run]${C_RESET} $tpl -> $dest (owner=$owner)"
    else
      install -m 0644 "$tpl" "$dest"
      chown "$owner" "$dest" 2>/dev/null || true
    fi
    log_info "40-bashrc: -> $dest (owner=$owner)"
  done
}
