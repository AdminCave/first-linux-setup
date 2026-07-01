#!/usr/bin/env bash
# lib/log.sh — Logging (Datei + Konsole über lib/ui.sh)
# shellcheck shell=bash

FLS_LOG="${FLS_LOG:-/var/log/admincave-setup.log}"

log_init() {
  if ! { mkdir -p "$(dirname "$FLS_LOG")" 2>/dev/null && : >>"$FLS_LOG" 2>/dev/null; }; then
    FLS_LOG="/tmp/admincave-setup.log"
    : >>"$FLS_LOG" 2>/dev/null || FLS_LOG="/dev/null"
  fi
  _log INFO "===== Lauf gestartet ($(date '+%F %T')) ====="
}

_log() {
  local lvl="$1"; shift
  printf '%s [%-6s] %s\n' "$(date '+%F %T')" "$lvl" "$*" >>"$FLS_LOG" 2>/dev/null || true
}

log_info()  { _log INFO  "$*"; ui_say  "$*"; }
log_warn()  { _log WARN  "$*"; ui_warn "$*"; }
log_error() { _log ERROR "$*"; ui_err  "$*"; }
log_step()  { _log STEP  "$*"; ui_step "$*"; }

# log_summary — zählt WARN/ERROR seit dem letzten "Lauf gestartet"-Marker.
# Gibt "<warn> <error>" aus (subshell-sicher, da aus dem Logfile gelesen).
log_summary() {
  [[ -r "$FLS_LOG" ]] || { echo "0 0"; return; }
  awk '
    /===== Lauf gestartet/ { w=0; e=0 }
    /\[WARN/  { w++ }
    /\[ERROR/ { e++ }
    END { printf "%d %d", w+0, e+0 }
  ' "$FLS_LOG"
}
