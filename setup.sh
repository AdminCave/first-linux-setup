#!/usr/bin/env bash
# =============================================================================
# AdminCave · first-linux-setup · Orchestrator
# -----------------------------------------------------------------------------
# Flow: load libs -> arguments -> detection -> config -> pre-hooks
#         -> modules in order -> post-hooks -> summary
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

Usage: setup.sh [options]
  --dry-run            Only show what would happen (no changes)
  -y, --yes            Unattended: no prompts (uses config defaults)
  --profile <name>     Force profile (instead of auto-detection)
  --config <path|url>  Load admin config (path or http[s] URL)
  -h, --help           This help

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
    *)              printf 'Unknown argument: %s\n' "$1" >&2 ;;
  esac
  shift
done
export DRY_RUN ASSUME_YES

require_root
log_init
log_info "AdminCave first-linux-setup started"
[[ "$DRY_RUN" == true ]] && log_warn "DRY-RUN active — NO changes will be made."

# --- Detection -------------------------------------------------------------
detect_all
FLS_PROFILE="${FORCE_PROFILE:-$DETECTED_PROFILE}"
export FLS_PROFILE
log_info "Profile: $FLS_PROFILE (OS=$DETECTED_OS_ID $DETECTED_OS_VER, Desktop=$DETECTED_DESKTOP, Virt=$DETECTED_VIRT)"
[[ -n "${SENSITIVE_ROLES// }" ]] && \
  log_warn "Sensitive roles detected:${SENSITIVE_ROLES} — affected modules will be protected."

# --- Config ----------------------------------------------------------------
config_load "$FLS_PROFILE"

# --- pre-hooks -------------------------------------------------------------
run_hooks "$FLS_DIR/hooks/pre.d"

# --- Modules ---------------------------------------------------------------
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
  [[ -f "$f" ]] || { log_warn "Module missing: $m"; continue; }
  log_step "Module: $m"
  # shellcheck source=/dev/null
  source "$f"
  if declare -F module_run >/dev/null; then
    ( module_run ) || log_warn "Module $m aborted (rc=$?)"
    unset -f module_run
  fi
done

# --- post-hooks ------------------------------------------------------------
run_hooks "$FLS_DIR/hooks/post.d"

read -r _w _e < <(log_summary) || true
log_info "Done — profile=$FLS_PROFILE, warnings=$_w, errors=$_e. Log: $FLS_LOG"
[[ "$DRY_RUN" == true ]] && log_warn "DRY-RUN: NO changes were made."
exit 0
