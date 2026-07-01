#!/usr/bin/env bash
# Module 40-bashrc — Deploy bashrc template (root + /etc/skel + all login users)
# shellcheck shell=bash
module_run() {
  [[ "${DEPLOY_BASHRC:-false}" == true ]] || { log_info "40-bashrc: disabled."; return 0; }
  local tpl="$FLS_DIR/assets/bashrc.template"
  [[ -r "$tpl" ]] || { log_error "40-bashrc: template missing: $tpl"; return 1; }

  # Target set: "owner:home"
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
    [[ -d "$home" ]] || { fls_run install -d -m 0755 "$home"; }
    dest="$home/.bashrc"
    # Idempotency: already identical -> do nothing
    if cmp -s "$tpl" "$dest" 2>/dev/null; then
      log_info "40-bashrc: $dest already up to date — skipped."
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
