#!/usr/bin/env bash
# Module 35-guest-agent — Guest agent in VMs
# Proxmox/KVM guest -> qemu-guest-agent. Bare-metal & containers: nothing.
# Note: the agent needs a virtio channel enabled on the host side
# (Proxmox: qm set <VMID> --agent enabled=1), otherwise the service won't start.
# shellcheck shell=bash
module_run() {
  local mode="${GUEST_AGENT_INSTALL:-auto}"
  [[ "$mode" == false ]] && { log_info "35-guest-agent: disabled."; return 0; }

  # Only in real VMs (no bare-metal, no container)
  if is_bare_metal || [[ "${DETECTED_CONTAINER:-no}" == yes ]]; then
    log_info "35-guest-agent: not a VM (virt=${DETECTED_VIRT}, container=${DETECTED_CONTAINER}) — skipped."
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive
  case "$DETECTED_VIRT" in
    kvm|qemu)
      if pkg_installed qemu-guest-agent; then
        log_info "35-guest-agent: qemu-guest-agent already installed."
      else
        log_info "35-guest-agent: installing qemu-guest-agent (virt=$DETECTED_VIRT)"
        fls_run apt-get -y install qemu-guest-agent || { log_warn "35-guest-agent: installation failed."; return 1; }
      fi
      fls_run systemctl enable qemu-guest-agent
      if [[ "${DRY_RUN:-false}" == true ]]; then
        ui_say "  ${C_YEL}[dry-run]${C_RESET} would start qemu-guest-agent"
      else
        systemctl start qemu-guest-agent 2>/dev/null \
          || log_warn "35-guest-agent: service not started — the virtio channel is probably missing (Proxmox: 'qm set <VMID> --agent enabled=1')."
      fi
      log_info "35-guest-agent: qemu-guest-agent configured."
      ;;
    *)
      log_info "35-guest-agent: VM type '$DETECTED_VIRT' — no agent mapping defined, skipped."
      ;;
  esac
}
