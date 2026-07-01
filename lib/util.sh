#!/usr/bin/env bash
# lib/util.sh — Helper functions: root check, dry-run wrapper, backups, hooks
# shellcheck shell=bash

FLS_MARKER="# Managed by AdminCave first-linux-setup"

require_root() {
  [[ "$(id -u)" -eq 0 ]] || { log_error "Root privileges required."; exit 1; }
}

have()           { command -v "$1" >/dev/null 2>&1; }
pkg_installed()  { dpkg -s "$1" >/dev/null 2>&1; }
svc_active()     { systemctl is-active --quiet "$1" 2>/dev/null; }

# fls_run <cmd...> — executes or only displays (DRY_RUN)
fls_run() {
  if [[ "${DRY_RUN:-false}" == true ]]; then
    ui_say "  ${C_YEL}[dry-run]${C_RESET} $*"; _log DRYRUN "$*"
  else
    _log RUN "$*"; "$@"
  fi
}

# backup_file <path> — creates a timestamped .bak (if the file exists)
backup_file() {
  local f="$1"
  [[ -e "$f" ]] || return 0
  local b; b="${f}.bak.$(date +%Y%m%d%H%M%S)"
  fls_run cp -a "$f" "$b" && log_info "Backup: $f -> $b"
}

# is_managed <path> — was the file created by this tool?
is_managed() { [[ -f "$1" ]] && grep -q "$FLS_MARKER" "$1" 2>/dev/null; }

# size_to_bytes "8G" / "512M" / "1024" -> bytes (for ZFS ARC etc.)
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

# write_file <dest> <mode> <owner> — content via stdin; dry-run-safe, creates parent
write_file() {
  local dest="$1" mode="${2:-0644}" owner="${3:-root}" content
  content="$(cat)"
  if [[ "${DRY_RUN:-false}" == true ]]; then
    ui_say "  ${C_YEL}[dry-run]${C_RESET} write $dest (mode=$mode owner=$owner, $(printf '%s\n' "$content" | grep -c '' ) lines)"
    _log DRYRUN "write $dest"
    return 0
  fi
  install -d -m 0755 "$(dirname "$dest")"
  printf '%s\n' "$content" >"$dest"
  chmod "$mode" "$dest"
  chown "$owner" "$dest" 2>/dev/null || true
  _log RUN "write $dest"
}

# login_users — prints "user:home" for real login users (UID>=1000, login shell)
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

# run_hooks <directory> — executes *.sh in alphabetical order
run_hooks() {
  local dir="$1" h
  [[ -d "$dir" ]] || return 0
  shopt -s nullglob
  for h in "$dir"/*.sh; do
    log_step "Hook: $(basename "$h")"
    fls_run bash "$h" || log_warn "Hook $(basename "$h") rc=$?"
  done
  shopt -u nullglob
}
