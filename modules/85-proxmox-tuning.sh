#!/usr/bin/env bash
# Module 85-proxmox-tuning — swappiness + ZFS ARC (Proxmox profiles only)
# shellcheck shell=bash
module_run() {
  case "$FLS_PROFILE" in
    proxmox-ve|pbs) : ;;
    *) log_info "85-proxmox-tuning: no Proxmox profile — skipped."; return 0 ;;
  esac

  # --- swappiness ---
  if [[ -n "${SWAPPINESS:-}" ]]; then
    printf '%s\n' "$FLS_MARKER" "vm.swappiness = ${SWAPPINESS}" \
      | write_file /etc/sysctl.d/99-admincave.conf 0644 root
    fls_run sysctl -w "vm.swappiness=${SWAPPINESS}"
    log_info "85-proxmox-tuning: vm.swappiness=${SWAPPINESS}"
  fi

  # --- ZFS ARC (only if ZFS is in use) ---
  if ! have zpool && ! modinfo zfs >/dev/null 2>&1; then
    log_info "85-proxmox-tuning: no ZFS detected — ARC tuning skipped."
    return 0
  fi

  local arc_min="${ZFS_ARC_MIN:-}" arc_max="${ZFS_ARC_MAX:-}"
  if [[ "${ZFS_ARC_PROMPT:-true}" == true && "${ASSUME_YES:-false}" != true && "${DRY_RUN:-false}" != true ]]; then
    local total_gib; total_gib="$(awk '/MemTotal/{printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null)"
    ui_say "ZFS ARC tuning (total RAM: ${total_gib:-?} GiB). Leave empty = do not change."
    arc_min="$(prompt_value 'ZFS ARC min (e.g. 2G)' "$arc_min")"
    arc_max="$(prompt_value 'ZFS ARC max (e.g. 8G)' "$arc_max")"
  fi

  if [[ -z "$arc_min" && -z "$arc_max" ]]; then
    log_info "85-proxmox-tuning: no ARC values provided — skipped."
    return 0
  fi

  local line="options zfs"
  [[ -n "$arc_min" ]] && line+=" zfs_arc_min=$(size_to_bytes "$arc_min")"
  [[ -n "$arc_max" ]] && line+=" zfs_arc_max=$(size_to_bytes "$arc_max")"

  backup_file /etc/modprobe.d/zfs.conf
  printf '%s\n' "$FLS_MARKER" "$line" | write_file /etc/modprobe.d/zfs.conf 0644 root
  log_info "85-proxmox-tuning: $line"

  # MANDATORY after a modprobe.d change:
  fls_run update-initramfs -u -k all
  log_warn "85-proxmox-tuning: ARC limit takes effect after reboot."
}
