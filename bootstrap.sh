#!/usr/bin/env bash
# =============================================================================
# AdminCave · first-linux-setup · bootstrap
# -----------------------------------------------------------------------------
# Wird vom One-Liner geholt, lädt das Toolkit herunter und startet setup.sh.
#
#   bash -c "$(curl -fsSL \
#     https://raw.githubusercontent.com/AdminCave/first-linux-setup/main/bootstrap.sh)"
#
# Parameter (als ENV vorangestellt):
#   FLS_REPO        Repo (Default: AdminCave/first-linux-setup) — für Forks
#   FLS_REF         Branch/Tag (Default: main)
#   FLS_WORKDIR     Zielverzeichnis (Default: /opt/first-linux-setup)
#   FLS_CONFIG      Pfad ODER URL zur Admin-Config (an setup.sh durchgereicht)
#   FLS_CONFIG_USER / FLS_CONFIG_PASS   Basic-Auth für FLS_CONFIG-URL
#   FLS_YES=true    Unattended (keine Rückfragen)
# =============================================================================
set -euo pipefail

FLS_REPO="${FLS_REPO:-AdminCave/first-linux-setup}"
FLS_REF="${FLS_REF:-main}"
FLS_WORKDIR="${FLS_WORKDIR:-/opt/first-linux-setup}"

err() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || err "Bitte als root ausführen (sudo -i)."
command -v tar >/dev/null 2>&1 || err "'tar' wird benötigt."
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 \
  || err "'curl' oder 'wget' wird benötigt."

tarball="https://codeload.github.com/${FLS_REPO}/tar.gz/${FLS_REF}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf '>> Lade %s@%s ...\n' "$FLS_REPO" "$FLS_REF"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$tarball" -o "$tmp/src.tar.gz" || err "Download fehlgeschlagen: $tarball"
else
  wget -qO "$tmp/src.tar.gz" "$tarball" || err "Download fehlgeschlagen: $tarball"
fi

tar -xzf "$tmp/src.tar.gz" -C "$tmp"
srcdir="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
[[ -d "$srcdir" ]] || err "Entpacktes Quellverzeichnis nicht gefunden."

mkdir -p "$FLS_WORKDIR"
cp -a "$srcdir/." "$FLS_WORKDIR/"
chmod +x "$FLS_WORKDIR/setup.sh" 2>/dev/null || true

printf '>> Starte Setup ...\n'
exec bash "$FLS_WORKDIR/setup.sh" "$@"
