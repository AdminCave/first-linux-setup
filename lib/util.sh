#!/usr/bin/env bash
# lib/util.sh — Hilfsfunktionen: Root-Check, dry-run-Wrapper, Backups, Hooks
# shellcheck shell=bash

FLS_MARKER="# Managed by AdminCave first-linux-setup"

require_root() {
  [[ "$(id -u)" -eq 0 ]] || { log_error "Root-Rechte benötigt."; exit 1; }
}

have()           { command -v "$1" >/dev/null 2>&1; }
pkg_installed()  { dpkg -s "$1" >/dev/null 2>&1; }
svc_active()     { systemctl is-active --quiet "$1" 2>/dev/null; }

# run <cmd...> — führt aus oder zeigt nur an (DRY_RUN)
run() {
  if [[ "${DRY_RUN:-false}" == true ]]; then
    ui_say "  ${C_YEL}[dry-run]${C_RESET} $*"; _log DRYRUN "$*"
  else
    _log RUN "$*"; "$@"
  fi
}

# backup_file <pfad> — legt zeitgestempelte .bak an (sofern vorhanden)
backup_file() {
  local f="$1"
  [[ -e "$f" ]] || return 0
  local b; b="${f}.bak.$(date +%Y%m%d%H%M%S)"
  run cp -a "$f" "$b" && log_info "Backup: $f -> $b"
}

# is_managed <pfad> — wurde die Datei von diesem Tool erzeugt?
is_managed() { [[ -f "$1" ]] && grep -q "$FLS_MARKER" "$1" 2>/dev/null; }

# size_to_bytes "8G" / "512M" / "1024" -> Bytes (für ZFS ARC etc.)
size_to_bytes() {
  local v="${1:-}"; [[ -n "$v" ]] || return 1
  local n="${v%[GgMmKk]}" unit="${v: -1}"
  case "$unit" in
    G|g) echo $(( n * 1024 * 1024 * 1024 )) ;;
    M|m) echo $(( n * 1024 * 1024 )) ;;
    K|k) echo $(( n * 1024 )) ;;
    *)   echo "$v" ;;
  esac
}

# write_file <dest> <mode> <owner> — Inhalt via stdin; dry-run-sicher, legt Parent an
write_file() {
  local dest="$1" mode="${2:-0644}" owner="${3:-root}" content
  content="$(cat)"
  if [[ "${DRY_RUN:-false}" == true ]]; then
    ui_say "  ${C_YEL}[dry-run]${C_RESET} schreibe $dest (mode=$mode owner=$owner, $(printf '%s\n' "$content" | grep -c '' ) Zeilen)"
    _log DRYRUN "write $dest"
    return 0
  fi
  install -d -m 0755 "$(dirname "$dest")"
  printf '%s\n' "$content" >"$dest"
  chmod "$mode" "$dest"
  chown "$owner" "$dest" 2>/dev/null || true
  _log RUN "write $dest"
}

# login_users — gibt "user:home" für echte Login-User (UID>=1000, Login-Shell) aus
login_users() {
  local user uid home shell
  while IFS=: read -r user _ uid _ _ home shell; do
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    (( uid >= 1000 && uid < 65534 )) || continue
    case "$shell" in */bash|*/sh|*/zsh) : ;; *) continue ;; esac
    [[ -d "$home" ]] || continue
    printf '%s:%s\n' "$user" "$home"
  done < /etc/passwd
}

# run_hooks <verzeichnis> — führt *.sh in alphabetischer Reihenfolge aus
run_hooks() {
  local dir="$1" h
  [[ -d "$dir" ]] || return 0
  shopt -s nullglob
  for h in "$dir"/*.sh; do
    log_step "Hook: $(basename "$h")"
    run bash "$h" || log_warn "Hook $(basename "$h") rc=$?"
  done
  shopt -u nullglob
}
