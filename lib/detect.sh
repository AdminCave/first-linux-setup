#!/usr/bin/env bash
# lib/detect.sh — Environment detection
# IMPORTANT: Check Proxmox VE/PBS FIRST — a PVE host identifies itself in
# /etc/os-release as "Debian trixie".
# shellcheck shell=bash
# detect_all sets DETECTED_* globals consumed by setup.sh and modules (cross-file):
# shellcheck disable=SC2034

detect_all() {
  DETECTED_OS_ID="unknown"; DETECTED_OS_VER=""; DETECTED_CODENAME=""
  local os_release="${FLS_OS_RELEASE:-/etc/os-release}"
  if [[ -r "$os_release" ]]; then
    # shellcheck disable=SC1090,SC1091
    . "$os_release"
    DETECTED_OS_ID="${ID:-unknown}"
    DETECTED_OS_VER="${VERSION_ID:-}"
    DETECTED_CODENAME="${VERSION_CODENAME:-}"
  fi

  DETECTED_VIRT="$(systemd-detect-virt 2>/dev/null || echo none)"
  DETECTED_CONTAINER=no
  if systemd-detect-virt -c >/dev/null 2>&1 \
     || [[ -f /run/systemd/container || -f /.dockerenv ]] \
     || grep -qa 'container=' /proc/1/environ 2>/dev/null; then
    DETECTED_CONTAINER=yes
  fi

  # --- Desktop environment? ---
  DETECTED_DESKTOP=no
  if systemctl get-default 2>/dev/null | grep -q 'graphical.target' \
     || [[ -n "${XDG_CURRENT_DESKTOP:-}" ]] \
     || have gnome-shell || have startplasma-x11 \
     || pkg_installed gdm3 || pkg_installed sddm || pkg_installed lightdm; then
    DETECTED_DESKTOP=yes
  fi

  # --- Proxmox FIRST ---
  DETECTED_PVE=no; DETECTED_PBS=no
  if have pveversion || pkg_installed proxmox-ve || [[ -d /etc/pve ]]; then
    DETECTED_PVE=yes
  fi
  if have proxmox-backup-manager || pkg_installed proxmox-backup-server; then
    DETECTED_PBS=yes
  fi

  # --- Derive profile ---
  if   [[ "$DETECTED_PVE" == yes ]]; then DETECTED_PROFILE="proxmox-ve"
  elif [[ "$DETECTED_PBS" == yes ]]; then DETECTED_PROFILE="pbs"
  elif [[ "$DETECTED_OS_ID" == debian ]]; then
    [[ "$DETECTED_DESKTOP" == yes ]] && DETECTED_PROFILE="debian-desktop" || DETECTED_PROFILE="debian-server"
  elif [[ "$DETECTED_OS_ID" == ubuntu ]]; then
    [[ "$DETECTED_DESKTOP" == yes ]] && DETECTED_PROFILE="ubuntu-desktop" || DETECTED_PROFILE="ubuntu-server"
  else
    DETECTED_PROFILE="generic"
  fi

  detect_sensitive_roles
}

# Detects intentionally configured roles that we must NOT override.
# Sets SENSITIVE_ROLES (space-separated). Check via role_present <name>.
detect_sensitive_roles() {
  SENSITIVE_ROLES=""

  # Samba Active Directory Domain Controller
  if pkg_installed samba-ad-dc || svc_active samba-ad-dc \
     || { have samba-tool && svc_active samba; }; then
    SENSITIVE_ROLES+=" samba-ad-dc"
  fi
  # linuxmuster.net (school server: AD-DC + provides time/DNS/DHCP among others)
  if dpkg-query -W -f='${Package}\n' 'linuxmuster*' 2>/dev/null | grep -q . \
     || [[ -d /etc/linuxmuster || -d /usr/share/linuxmuster ]]; then
    SENSITIVE_ROLES+=" linuxmuster"
  fi
  # DNS server
  if svc_active named || svc_active bind9 || svc_active unbound; then
    SENSITIVE_ROLES+=" dns-server"
  fi
  # Dedicated NTP daemon (instead of timesyncd) — intentionally configured
  if svc_active ntp || svc_active ntpsec || svc_active openntpd; then
    SENSITIVE_ROLES+=" ntp-daemon"
  fi
  # NTP *server* (chrony with 'allow' = provides time for others)
  if pkg_installed chrony && grep -rqsiE '^\s*allow\b' /etc/chrony 2>/dev/null; then
    SENSITIVE_ROLES+=" ntp-server"
  fi
  # Mail server
  if svc_active postfix || svc_active dovecot || svc_active exim4; then
    SENSITIVE_ROLES+=" mail-server"
  fi
}

# role_present <name> -> 0 if role detected
role_present() { [[ " ${SENSITIVE_ROLES} " == *" $1 "* ]]; }

# is_bare_metal -> 0 on physical hardware (no VM, no container)
is_bare_metal() { [[ "${DETECTED_VIRT:-none}" == none && "${DETECTED_CONTAINER:-no}" == no ]]; }
