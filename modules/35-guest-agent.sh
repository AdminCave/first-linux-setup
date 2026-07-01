#!/usr/bin/env bash
# Modul 35-guest-agent — Gast-Agent in VMs
# Proxmox/KVM-Gast -> qemu-guest-agent. Bare-Metal & Container: nichts.
# Hinweis: Der Agent braucht einen host-seitig aktivierten virtio-Kanal
# (Proxmox: qm set <VMID> --agent enabled=1), sonst startet der Dienst nicht.
# shellcheck shell=bash
module_run() {
  local mode="${GUEST_AGENT_INSTALL:-auto}"
  [[ "$mode" == false ]] && { log_info "35-guest-agent: deaktiviert."; return 0; }

  # Nur in echten VMs (kein Bare-Metal, kein Container)
  if is_bare_metal || [[ "${DETECTED_CONTAINER:-no}" == yes ]]; then
    log_info "35-guest-agent: keine VM (virt=${DETECTED_VIRT}, container=${DETECTED_CONTAINER}) — übersprungen."
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive
  case "$DETECTED_VIRT" in
    kvm|qemu)
      if pkg_installed qemu-guest-agent; then
        log_info "35-guest-agent: qemu-guest-agent bereits installiert."
      else
        log_info "35-guest-agent: installiere qemu-guest-agent (virt=$DETECTED_VIRT)"
        run apt-get -y install qemu-guest-agent || { log_warn "35-guest-agent: Installation fehlgeschlagen."; return 1; }
      fi
      run systemctl enable qemu-guest-agent
      if [[ "${DRY_RUN:-false}" == true ]]; then
        ui_say "  ${C_YEL}[dry-run]${C_RESET} würde qemu-guest-agent starten"
      else
        systemctl start qemu-guest-agent 2>/dev/null \
          || log_warn "35-guest-agent: Dienst nicht gestartet — vermutlich fehlt der virtio-Kanal (Proxmox: 'qm set <VMID> --agent enabled=1')."
      fi
      log_info "35-guest-agent: qemu-guest-agent eingerichtet."
      ;;
    *)
      log_info "35-guest-agent: VM-Typ '$DETECTED_VIRT' — kein Agent-Mapping hinterlegt, übersprungen."
      ;;
  esac
}
