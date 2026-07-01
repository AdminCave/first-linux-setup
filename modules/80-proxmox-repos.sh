#!/usr/bin/env bash
# Module 80-proxmox-repos — Enterprise -> No-Subscription (PVE, Ceph, PBS)
# deb822 .sources (PVE9/PBS4). Keyring: /usr/share/keyrings/proxmox-archive-keyring.gpg
# shellcheck shell=bash

_pmx_keyring="/usr/share/keyrings/proxmox-archive-keyring.gpg"

# _deb822_disable <file> — sets/adds "Enabled: no" (file is kept)
_deb822_disable() {
  local f="$1"
  [[ -f "$f" ]] || { log_info "80-proxmox-repos: $f not present — nothing to disable."; return 0; }
  backup_file "$f"
  if grep -qiE '^\s*Enabled:' "$f"; then
    fls_run sed -i -E 's/^\s*Enabled:.*/Enabled: no/I' "$f"
  else
    if [[ "${DRY_RUN:-false}" == true ]]; then
      ui_say "  ${C_YEL}[dry-run]${C_RESET} would append 'Enabled: no' to $f"
    else
      printf 'Enabled: no\n' >>"$f"
    fi
  fi
  log_info "80-proxmox-repos: $f disabled (Enabled: no)."
}

module_run() {
  case "$FLS_PROFILE" in
    proxmox-ve|pbs) : ;;
    *) log_info "80-proxmox-repos: no Proxmox profile — skipped."; return 0 ;;
  esac
  local ld="/etc/apt/sources.list.d"

  if [[ "$FLS_PROFILE" == proxmox-ve ]]; then
    [[ "${PVE_DISABLE_ENTERPRISE:-false}" == true ]] && _deb822_disable "$ld/pve-enterprise.sources"
    if [[ "${PVE_SWITCH_NOSUB_REPO:-false}" == true ]]; then
      {
        echo "$FLS_MARKER"
        echo "Types: deb"
        echo "URIs: http://download.proxmox.com/debian/pve"
        echo "Suites: ${DETECTED_CODENAME:-trixie}"
        echo "Components: pve-no-subscription"
        echo "Signed-By: $_pmx_keyring"
      } | write_file "$ld/pve-no-subscription.sources" 0644 root
      log_info "80-proxmox-repos: PVE No-Subscription set."
    fi

    # --- Ceph: READ the release codename, don't guess ---
    if [[ "${PVE_DISABLE_CEPH_ENTERPRISE:-false}" == true || "${PVE_SWITCH_CEPH_NOSUB:-false}" == true ]]; then
      local ceph_f="$ld/ceph.sources" ceph_rel=""
      if [[ -f "$ceph_f" ]]; then
        ceph_rel="$(grep -oE 'ceph-[a-z]+' "$ceph_f" | head -n1)"
      fi
      [[ "${PVE_DISABLE_CEPH_ENTERPRISE:-false}" == true ]] && _deb822_disable "$ceph_f"
      if [[ "${PVE_SWITCH_CEPH_NOSUB:-false}" == true ]]; then
        if [[ -n "$ceph_rel" ]]; then
          {
            echo "$FLS_MARKER"
            echo "Types: deb"
            echo "URIs: http://download.proxmox.com/debian/${ceph_rel}"
            echo "Suites: ${DETECTED_CODENAME:-trixie}"
            echo "Components: no-subscription"
            echo "Signed-By: $_pmx_keyring"
          } | write_file "$ld/ceph-no-subscription.sources" 0644 root
          log_info "80-proxmox-repos: Ceph No-Subscription set ($ceph_rel)."
        else
          log_warn "80-proxmox-repos: Ceph release not determinable (no ceph.sources) — Ceph No-Sub skipped."
        fi
      fi
    fi

    # optional: subscription nag (patches proxmoxlib.js, overwritten on updates)
    if [[ "${PVE_REMOVE_SUB_NAG:-false}" == true ]]; then
      log_warn "80-proxmox-repos: PVE_REMOVE_SUB_NAG=true — TODO JS patch (deliberately optional, update-volatile)."
    fi
  fi

  if [[ "$FLS_PROFILE" == pbs ]]; then
    [[ "${PBS_DISABLE_ENTERPRISE:-false}" == true ]] && _deb822_disable "$ld/pbs-enterprise.sources"
    if [[ "${PBS_SWITCH_NOSUB_REPO:-false}" == true ]]; then
      {
        echo "$FLS_MARKER"
        echo "Types: deb"
        echo "URIs: http://download.proxmox.com/debian/pbs"
        echo "Suites: ${DETECTED_CODENAME:-trixie}"
        echo "Components: pbs-no-subscription"
        echo "Signed-By: $_pmx_keyring"
      } | write_file "$ld/pbs-no-subscription.sources" 0644 root
      log_info "80-proxmox-repos: PBS No-Subscription set."
    fi
  fi

  fls_run apt-get update
}
