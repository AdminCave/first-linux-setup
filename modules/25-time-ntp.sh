#!/usr/bin/env bash
# Modul 25-time-ntp — Zeitsynchronisation (timesyncd oder chrony)
# Safety: wenn Zeit bereits ABSICHTLICH eingerichtet ist (DC, linuxmuster,
# dedizierter NTP-Daemon, vorhandene NTP-Server-Config), NICHTS anfassen.
# shellcheck shell=bash

# _ntp_intentional — 0, wenn eine absichtliche Zeit-Konfiguration erkannt wird
_ntp_intentional() {
  # Grund wird per echo zurückgegeben (Exit 0 = absichtliche Config erkannt).
  # Rollen, die typischerweise selbst Zeit bereitstellen / kritisch sind
  local r
  for r in ntp-server ntp-daemon samba-ad-dc linuxmuster; do
    if role_present "$r"; then printf '%s' "Rolle:$r"; return 0; fi
  done
  # Bestehende chrony-Server/-Pool-Zeilen, die NICHT von uns stammen
  local f
  for f in /etc/chrony/chrony.conf /etc/chrony/conf.d/*.conf; do
    [[ -f "$f" ]] || continue
    grep -q "$FLS_MARKER" "$f" 2>/dev/null && continue
    if grep -qiE '^\s*(server|pool)\s' "$f" 2>/dev/null; then printf '%s' "chrony:$f"; return 0; fi
  done
  # Bestehende timesyncd NTP=-Server, die NICHT von uns stammen
  for f in /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf.d/*.conf; do
    [[ -f "$f" ]] || continue
    grep -q "$FLS_MARKER" "$f" 2>/dev/null && continue
    if grep -qiE '^\s*NTP=\S' "$f" 2>/dev/null; then printf '%s' "timesyncd:$f"; return 0; fi
  done
  return 1
}

module_run() {
  local manage="${NTP_MANAGE:-auto}"
  [[ "$manage" == never ]] && { log_info "25-time-ntp: MANAGE=never."; return 0; }

  if [[ "$manage" == auto ]]; then
    local reason; reason="$(_ntp_intentional)" && {
      log_warn "25-time-ntp: bereits eingerichtete Zeit-Synchronisation erkannt ($reason) — nicht angefasst (MANAGE=auto). Für Erzwingen: NTP_MANAGE=always."
      return 0
    }
  fi

  local backend="${NTP_BACKEND:-timesyncd}"
  export DEBIAN_FRONTEND=noninteractive

  case "$backend" in
    chrony)
      pkg_installed chrony || { log_info "25-time-ntp: installiere chrony"; run apt-get -y install chrony; }
      if [[ ${#NTP_SERVERS[@]} -gt 0 ]]; then
        { echo "$FLS_MARKER"; local s; for s in "${NTP_SERVERS[@]}"; do echo "server $s iburst"; done; } \
          | write_file /etc/chrony/conf.d/admincave.conf 0644 root
      fi
      run systemctl enable --now chrony
      log_info "25-time-ntp: chrony aktiv (Server: ${NTP_SERVERS[*]:-Distributionsdefault})."
      ;;
    timesyncd|*)
      pkg_installed systemd-timesyncd || { log_info "25-time-ntp: installiere systemd-timesyncd"; run apt-get -y install systemd-timesyncd; }
      if [[ ${#NTP_SERVERS[@]} -gt 0 ]]; then
        printf '%s\n[Time]\nNTP=%s\n' "$FLS_MARKER" "${NTP_SERVERS[*]}" \
          | write_file /etc/systemd/timesyncd.conf.d/admincave.conf 0644 root
      fi
      run systemctl enable --now systemd-timesyncd
      run timedatectl set-ntp true
      log_info "25-time-ntp: systemd-timesyncd aktiv (Server: ${NTP_SERVERS[*]:-Distributionsdefault})."
      ;;
  esac
}
