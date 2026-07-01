#!/usr/bin/env bash
# Module 45-fastfetch — Install fastfetch + deploy config
# shellcheck shell=bash
module_run() {
  [[ "${INSTALL_FASTFETCH:-false}" == true ]] || { log_info "45-fastfetch: disabled."; return 0; }
  local cfg="$FLS_DIR/assets/fastfetch.jsonc"
  [[ -r "$cfg" ]] || { log_error "45-fastfetch: config template missing: $cfg"; return 1; }

  if ! have fastfetch; then
    log_info "45-fastfetch: installing fastfetch"
    export DEBIAN_FRONTEND=noninteractive
    fls_run apt-get -y install fastfetch || log_warn "45-fastfetch: apt installation failed (package may not be available)."
  fi

  # Deploy config per target home (root + /etc/skel + login users)
  local targets=("root:/root" "root:/etc/skel") line
  while IFS= read -r line; do targets+=("${line%%:*}:${line##*:}"); done < <(login_users)

  local entry owner home dest
  for entry in "${targets[@]}"; do
    owner="${entry%%:*}"; home="${entry##*:}"
    dest="$home/.config/fastfetch/config.jsonc"
    # Idempotency: already identical -> do nothing
    if cmp -s "$cfg" "$dest" 2>/dev/null; then
      log_info "45-fastfetch: $dest already up to date — skipped."
      continue
    fi
    if [[ "${DRY_RUN:-false}" == true ]]; then
      ui_say "  ${C_YEL}[dry-run]${C_RESET} $cfg -> $dest (owner=$owner)"
    else
      install -d -m 0755 "$(dirname "$dest")"
      install -m 0644 "$cfg" "$dest"
      chown -R "$owner" "$home/.config/fastfetch" 2>/dev/null || true
    fi
    log_info "45-fastfetch: -> $dest"
  done
}
