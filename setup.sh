#!/usr/bin/env bash
# =============================================================================
# AdminCave · first-linux-setup · Orchestrator
# -----------------------------------------------------------------------------
# Ablauf: libs laden -> Argumente -> Detection -> Config -> pre-Hooks
#         -> Module der Reihe nach -> post-Hooks -> Zusammenfassung
# =============================================================================
set -euo pipefail

FLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FLS_DIR

# shellcheck source=lib/log.sh
source "$FLS_DIR/lib/log.sh"
# shellcheck source=lib/ui.sh
source "$FLS_DIR/lib/ui.sh"
# shellcheck source=lib/util.sh
source "$FLS_DIR/lib/util.sh"
# shellcheck source=lib/detect.sh
source "$FLS_DIR/lib/detect.sh"
# shellcheck source=lib/config.sh
source "$FLS_DIR/lib/config.sh"

DRY_RUN=false
ASSUME_YES="${FLS_YES:-false}"
FORCE_PROFILE="${FLS_PROFILE:-}"

usage() {
  cat <<EOF
AdminCave first-linux-setup

Verwendung: setup.sh [Optionen]
  --dry-run            Nur anzeigen, was passieren würde (keine Änderungen)
  -y, --yes            Unattended: keine Rückfragen (nutzt Config-Defaults)
  --profile <name>     Profil erzwingen (statt Auto-Erkennung)
  --config <pfad|url>  Admin-Config laden (Pfad oder http[s]-URL)
  -h, --help           Diese Hilfe

ENV: FLS_CONFIG, FLS_CONFIG_USER, FLS_CONFIG_PASS, FLS_REPO, FLS_REF, FLS_YES
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)      DRY_RUN=true ;;
    -y|--yes)       ASSUME_YES=true ;;
    --profile)      FORCE_PROFILE="${2:-}"; shift ;;
    --profile=*)    FORCE_PROFILE="${1#*=}" ;;
    --config)       FLS_CONFIG="${2:-}"; shift ;;
    --config=*)     FLS_CONFIG="${1#*=}" ;;
    -h|--help)      usage; exit 0 ;;
    *)              printf 'Unbekanntes Argument: %s\n' "$1" >&2 ;;
  esac
  shift
done
export DRY_RUN ASSUME_YES

require_root
log_init
log_info "AdminCave first-linux-setup gestartet"
[[ "$DRY_RUN" == true ]] && log_warn "DRY-RUN aktiv — es werden KEINE Änderungen vorgenommen."

# --- Detection -------------------------------------------------------------
detect_all
FLS_PROFILE="${FORCE_PROFILE:-$DETECTED_PROFILE}"
export FLS_PROFILE
log_info "Profil: $FLS_PROFILE (OS=$DETECTED_OS_ID $DETECTED_OS_VER, Desktop=$DETECTED_DESKTOP, Virt=$DETECTED_VIRT)"
[[ -n "${SENSITIVE_ROLES// }" ]] && \
  log_warn "Sensible Rollen erkannt:${SENSITIVE_ROLES} — betroffene Module werden geschützt."

# --- Config ----------------------------------------------------------------
config_load "$FLS_PROFILE"

# --- pre-Hooks -------------------------------------------------------------
run_hooks "$FLS_DIR/hooks/pre.d"

# --- Module ----------------------------------------------------------------
MODULES=(
  10-update
  20-locale-keyboard
  25-time-ntp
  30-packages
  35-guest-agent
  40-bashrc
  45-fastfetch
  50-ssh-keys
  55-ssh-harden
  60-passwords
  70-fail2ban
  80-proxmox-repos
  85-proxmox-tuning
)

for m in "${MODULES[@]}"; do
  f="$FLS_DIR/modules/$m.sh"
  [[ -f "$f" ]] || { log_warn "Modul fehlt: $m"; continue; }
  log_step "Modul: $m"
  # shellcheck source=/dev/null
  source "$f"
  if declare -F module_run >/dev/null; then
    ( module_run ) || log_warn "Modul $m abgebrochen (rc=$?)"
    unset -f module_run
  fi
done

# --- post-Hooks ------------------------------------------------------------
run_hooks "$FLS_DIR/hooks/post.d"

read -r _w _e < <(log_summary)
log_info "Fertig — Profil=$FLS_PROFILE, Warnungen=$_w, Fehler=$_e. Log: $FLS_LOG"
[[ "$DRY_RUN" == true ]] && log_warn "DRY-RUN: es wurden KEINE Änderungen vorgenommen."
