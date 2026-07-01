#!/usr/bin/env bash
# lib/config.sh — Load config layers
# Order (later ones override earlier ones):
#   profiles/defaults.conf -> profiles/<profile>.conf -> config.conf
#   -> FLS_CONFIG (path OR http[s] URL) -> ENV (already set)
# shellcheck shell=bash

_source_conf() {
  local f="$1"
  [[ -r "$f" ]] || return 0
  log_info "Config: $(basename "$f")"
  # shellcheck disable=SC1090
  . "$f"
}

config_load() {
  local profile="$1"
  _source_conf "$FLS_DIR/profiles/defaults.conf"
  _source_conf "$FLS_DIR/profiles/${profile}.conf"
  _source_conf "$FLS_DIR/config.conf"
  [[ -n "${FLS_CONFIG:-}" ]] && _load_external_config "$FLS_CONFIG"
  return 0
}

# Loads config from a local path or URL (optional basic auth via netrc tempfile)
_load_external_config() {
  local src="$1"
  if [[ "$src" != http://* && "$src" != https://* ]]; then
    _source_conf "$src"
    return
  fi

  have curl || { log_error "curl is required for FLS_CONFIG URL."; return 1; }
  local tmp netrc="" host
  tmp="$(mktemp)"

  if [[ -n "${FLS_CONFIG_USER:-}" ]]; then
    # Do NOT pass the password via -u (would be visible in 'ps') -> temporary netrc, chmod 600
    netrc="$(mktemp)"; chmod 600 "$netrc"
    host="${src#*://}"; host="${host%%/*}"
    printf 'machine %s login %s password %s\n' \
      "$host" "$FLS_CONFIG_USER" "${FLS_CONFIG_PASS:-}" >"$netrc"
  fi

  log_info "Loading external config: $src"
  local ok=true
  if [[ -n "$netrc" ]]; then
    curl -fsSL --netrc-file "$netrc" "$src" -o "$tmp" || ok=false
    rm -f "$netrc"
  else
    curl -fsSL "$src" -o "$tmp" || ok=false
  fi

  if [[ "$ok" == true ]]; then
    # shellcheck disable=SC1090
    . "$tmp"
    log_info "External config loaded."
  else
    log_error "Download of external config failed: $src"
  fi
  rm -f "$tmp"
}
