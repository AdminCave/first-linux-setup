#!/usr/bin/env bash
# Modul 45-fastfetch — fastfetch installieren + Config ausrollen
# shellcheck shell=bash
module_run() {
  [[ "${INSTALL_FASTFETCH:-false}" == true ]] || { log_info "45-fastfetch: deaktiviert."; return 0; }
  local cfg="$FLS_DIR/assets/fastfetch.jsonc"
  [[ -r "$cfg" ]] || { log_error "45-fastfetch: Config-Vorlage fehlt: $cfg"; return 1; }

  if ! have fastfetch; then
    log_info "45-fastfetch: installiere fastfetch"
    export DEBIAN_FRONTEND=noninteractive
    run apt-get -y install fastfetch || log_warn "45-fastfetch: apt-Installation fehlgeschlagen (Paket ggf. nicht verfügbar)."
  fi

  # Config je Ziel-Home ausrollen (root + /etc/skel + Login-User)
  local targets=("root:/root" "root:/etc/skel") line
  while IFS= read -r line; do targets+=("${line%%:*}:${line##*:}"); done < <(login_users)

  local entry owner home dest
  for entry in "${targets[@]}"; do
    owner="${entry%%:*}"; home="${entry##*:}"
    dest="$home/.config/fastfetch/config.jsonc"
    # Idempotenz: bereits identisch -> nichts tun
    if cmp -s "$cfg" "$dest" 2>/dev/null; then
      log_info "45-fastfetch: $dest bereits aktuell — übersprungen."
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
