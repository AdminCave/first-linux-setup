#!/usr/bin/env bash
# Module 25-time-ntp — Time synchronization (timesyncd or chrony)
# Safety: if time is already INTENTIONALLY configured (DC, linuxmuster,
# dedicated NTP daemon, existing NTP server config), touch NOTHING.
# shellcheck shell=bash

# _ntp_intentional — 0 if an intentional time configuration is detected
_ntp_intentional() {
  # The reason is returned via echo (exit 0 = intentional config detected).
  # Roles that typically provide time themselves / are critical
  local r
  for r in ntp-server ntp-daemon samba-ad-dc linuxmuster; do
    if role_present "$r"; then printf '%s' "role:$r"; return 0; fi
  done
  # Existing chrony server/pool lines that do NOT originate from us
  local f
  for f in /etc/chrony/chrony.conf /etc/chrony/conf.d/*.conf; do
    [[ -f "$f" ]] || continue
    grep -q "$FLS_MARKER" "$f" 2>/dev/null && continue
    if grep -qiE '^\s*(server|pool)\s' "$f" 2>/dev/null; then printf '%s' "chrony:$f"; return 0; fi
  done
  # Existing timesyncd NTP= servers that do NOT originate from us
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
      log_warn "25-time-ntp: already configured time synchronization detected ($reason) — left untouched (MANAGE=auto). To force: NTP_MANAGE=always."
      return 0
    }
  fi

  local backend="${NTP_BACKEND:-timesyncd}"
  export DEBIAN_FRONTEND=noninteractive

  case "$backend" in
    chrony)
      pkg_installed chrony || { log_info "25-time-ntp: installing chrony"; fls_run apt-get -y install chrony; }
      if [[ ${#NTP_SERVERS[@]} -gt 0 ]]; then
        { echo "$FLS_MARKER"; local s; for s in "${NTP_SERVERS[@]}"; do echo "server $s iburst"; done; } \
          | write_file /etc/chrony/conf.d/admincave.conf 0644 root
      fi
      fls_run systemctl enable --now chrony
      log_info "25-time-ntp: chrony active (servers: ${NTP_SERVERS[*]:-distribution default})."
      ;;
    timesyncd|*)
      pkg_installed systemd-timesyncd || { log_info "25-time-ntp: installing systemd-timesyncd"; fls_run apt-get -y install systemd-timesyncd; }
      if [[ ${#NTP_SERVERS[@]} -gt 0 ]]; then
        printf '%s\n[Time]\nNTP=%s\n' "$FLS_MARKER" "${NTP_SERVERS[*]}" \
          | write_file /etc/systemd/timesyncd.conf.d/admincave.conf 0644 root
      fi
      fls_run systemctl enable --now systemd-timesyncd
      fls_run timedatectl set-ntp true
      log_info "25-time-ntp: systemd-timesyncd active (servers: ${NTP_SERVERS[*]:-distribution default})."
      ;;
  esac
}
