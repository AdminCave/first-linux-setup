#!/usr/bin/env bash
# Modul 85-proxmox-tuning — swappiness + ZFS-ARC (nur Proxmox-Profile)
# shellcheck shell=bash
module_run() {
  case "$FLS_PROFILE" in
    proxmox-ve|pbs) : ;;
    *) log_info "85-proxmox-tuning: kein Proxmox-Profil — übersprungen."; return 0 ;;
  esac

  # --- swappiness ---
  if [[ -n "${SWAPPINESS:-}" ]]; then
    printf '%s\n' "$FLS_MARKER" "vm.swappiness = ${SWAPPINESS}" \
      | write_file /etc/sysctl.d/99-admincave.conf 0644 root
    run sysctl -w "vm.swappiness=${SWAPPINESS}"
    log_info "85-proxmox-tuning: vm.swappiness=${SWAPPINESS}"
  fi

  # --- ZFS ARC (nur wenn ZFS im Einsatz) ---
  if ! have zpool && ! modinfo zfs >/dev/null 2>&1; then
    log_info "85-proxmox-tuning: kein ZFS erkannt — ARC-Tuning übersprungen."
    return 0
  fi

  local arc_min="${ZFS_ARC_MIN:-}" arc_max="${ZFS_ARC_MAX:-}"
  if [[ "${ZFS_ARC_PROMPT:-true}" == true && "${ASSUME_YES:-false}" != true && "${DRY_RUN:-false}" != true ]]; then
    local total_gib; total_gib="$(awk '/MemTotal/{printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null)"
    ui_say "ZFS-ARC-Tuning (RAM gesamt: ${total_gib:-?} GiB). Leer lassen = nicht ändern."
    arc_min="$(prompt_value 'ZFS ARC min (z.B. 2G)' "$arc_min")"
    arc_max="$(prompt_value 'ZFS ARC max (z.B. 8G)' "$arc_max")"
  fi

  if [[ -z "$arc_min" && -z "$arc_max" ]]; then
    log_info "85-proxmox-tuning: keine ARC-Werte angegeben — übersprungen."
    return 0
  fi

  local line="options zfs"
  [[ -n "$arc_min" ]] && line+=" zfs_arc_min=$(size_to_bytes "$arc_min")"
  [[ -n "$arc_max" ]] && line+=" zfs_arc_max=$(size_to_bytes "$arc_max")"

  backup_file /etc/modprobe.d/zfs.conf
  printf '%s\n' "$FLS_MARKER" "$line" | write_file /etc/modprobe.d/zfs.conf 0644 root
  log_info "85-proxmox-tuning: $line"

  # PFLICHT nach modprobe.d-Änderung:
  run update-initramfs -u -k all
  log_warn "85-proxmox-tuning: ARC-Limit greift nach Reboot."
}
