#!/usr/bin/env bash
# Modul 80-proxmox-repos — Enterprise -> No-Subscription (PVE, Ceph, PBS)
# deb822 .sources (PVE9/PBS4). Keyring: /usr/share/keyrings/proxmox-archive-keyring.gpg
# shellcheck shell=bash

_pmx_keyring="/usr/share/keyrings/proxmox-archive-keyring.gpg"

# _deb822_disable <datei> — setzt/ergänzt "Enabled: no" (Datei bleibt erhalten)
_deb822_disable() {
  local f="$1"
  [[ -f "$f" ]] || { log_info "80-proxmox-repos: $f nicht vorhanden — nichts zu deaktivieren."; return 0; }
  backup_file "$f"
  if grep -qiE '^\s*Enabled:' "$f"; then
    run sed -i -E 's/^\s*Enabled:.*/Enabled: no/I' "$f"
  else
    if [[ "${DRY_RUN:-false}" == true ]]; then
      ui_say "  ${C_YEL}[dry-run]${C_RESET} würde 'Enabled: no' an $f anhängen"
    else
      printf 'Enabled: no\n' >>"$f"
    fi
  fi
  log_info "80-proxmox-repos: $f deaktiviert (Enabled: no)."
}

module_run() {
  case "$FLS_PROFILE" in
    proxmox-ve|pbs) : ;;
    *) log_info "80-proxmox-repos: kein Proxmox-Profil — übersprungen."; return 0 ;;
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
      log_info "80-proxmox-repos: PVE No-Subscription gesetzt."
    fi

    # --- Ceph: Release-Codename AUSLESEN, nicht raten ---
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
          log_info "80-proxmox-repos: Ceph No-Subscription gesetzt ($ceph_rel)."
        else
          log_warn "80-proxmox-repos: Ceph-Release nicht ermittelbar (keine ceph.sources) — Ceph No-Sub übersprungen."
        fi
      fi
    fi

    # optional: Subscription-Nag (patcht proxmoxlib.js, wird bei Updates überschrieben)
    if [[ "${PVE_REMOVE_SUB_NAG:-false}" == true ]]; then
      log_warn "80-proxmox-repos: PVE_REMOVE_SUB_NAG=true — TODO JS-Patch (bewusst optional, update-flüchtig)."
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
      log_info "80-proxmox-repos: PBS No-Subscription gesetzt."
    fi
  fi

  run apt-get update
}
