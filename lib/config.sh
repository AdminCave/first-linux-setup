#!/usr/bin/env bash
# lib/config.sh — Config-Schichten laden
# Reihenfolge (spätere überschreiben frühere):
#   profiles/defaults.conf -> profiles/<profil>.conf -> config.conf
#   -> FLS_CONFIG (Pfad ODER http[s]-URL) -> ENV (bereits gesetzt)
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

# Lädt Config von lokalem Pfad oder URL (optional Basic-Auth via netrc-Tempfile)
_load_external_config() {
  local src="$1"
  if [[ "$src" != http://* && "$src" != https://* ]]; then
    _source_conf "$src"
    return
  fi

  have curl || { log_error "curl wird für FLS_CONFIG-URL benötigt."; return 1; }
  local tmp netrc="" host
  tmp="$(mktemp)"

  if [[ -n "${FLS_CONFIG_USER:-}" ]]; then
    # Passwort NICHT via -u (wäre in 'ps' sichtbar) -> temporäres netrc, chmod 600
    netrc="$(mktemp)"; chmod 600 "$netrc"
    host="${src#*://}"; host="${host%%/*}"
    printf 'machine %s login %s password %s\n' \
      "$host" "$FLS_CONFIG_USER" "${FLS_CONFIG_PASS:-}" >"$netrc"
  fi

  log_info "Lade externe Config: $src"
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
    log_info "Externe Config geladen."
  else
    log_error "Download der externen Config fehlgeschlagen: $src"
  fi
  rm -f "$tmp"
}
