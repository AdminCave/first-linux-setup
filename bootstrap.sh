#!/usr/bin/env bash
# =============================================================================
# AdminCave · first-linux-setup · bootstrap
# -----------------------------------------------------------------------------
# Fetched by the one-liner, downloads the toolkit and starts setup.sh.
#
# Stable (recommended):
#   bash -c "$(curl -fsSL \
#     https://github.com/AdminCave/first-linux-setup/releases/latest/download/bootstrap.sh)"
#
# Source selection via FLS_VERSION:
#   stable   (default) latest published release           -> releases/latest
#   vX.Y.Z            exactly this release                 -> releases/download/vX.Y.Z
#   dev              current Git branch (FLS_REF, default main)
#
# Further parameters (prepended as ENV):
#   FLS_REPO        Repo (default: AdminCave/first-linux-setup) — for forks
#   FLS_REF         Git branch/tag (implies dev mode)
#   FLS_WORKDIR     Target directory (default: /opt/first-linux-setup)
#   FLS_CONFIG / FLS_CONFIG_USER / FLS_CONFIG_PASS   passed through to setup.sh
#   FLS_YES=true    Unattended (no prompts)
# =============================================================================
set -euo pipefail

FLS_REPO="${FLS_REPO:-AdminCave/first-linux-setup}"
FLS_VERSION="${FLS_VERSION:-stable}"
FLS_REF="${FLS_REF:-}"
FLS_WORKDIR="${FLS_WORKDIR:-/opt/first-linux-setup}"
PKG="first-linux-setup"

err() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || err "Please run as root (sudo -i)."
command -v tar >/dev/null 2>&1 || err "'tar' is required."
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 \
  || err "'curl' or 'wget' is required."

# --- Determine download source ---
if [[ -n "$FLS_REF" || "$FLS_VERSION" == dev ]]; then
  ref="${FLS_REF:-main}"
  url="https://codeload.github.com/${FLS_REPO}/tar.gz/${ref}"
  printf '>> Source: git-ref %s (development)\n' "$ref"
elif [[ "$FLS_VERSION" == stable ]]; then
  url="https://github.com/${FLS_REPO}/releases/latest/download/${PKG}.tar.gz"
  printf '>> Source: latest stable release\n'
else
  url="https://github.com/${FLS_REPO}/releases/download/${FLS_VERSION}/${PKG}.tar.gz"
  printf '>> Source: release %s\n' "$FLS_VERSION"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf '>> Downloading %s ...\n' "$url"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$url" -o "$tmp/src.tar.gz" || err "Download failed: $url"
else
  wget -qO "$tmp/src.tar.gz" "$url" || err "Download failed: $url"
fi

tar -xzf "$tmp/src.tar.gz" -C "$tmp"

# Robustly resolve tarball layout (release: PKG/…, codeload: repo-ref/…)
if [[ -f "$tmp/setup.sh" ]]; then
  srcdir="$tmp"
else
  srcdir="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
fi
[[ -f "$srcdir/setup.sh" ]] || err "setup.sh not found in the downloaded package."

mkdir -p "$FLS_WORKDIR"
cp -a "$srcdir/." "$FLS_WORKDIR/"
chmod +x "$FLS_WORKDIR/setup.sh" 2>/dev/null || true

printf '>> Starting setup ...\n'
exec bash "$FLS_WORKDIR/setup.sh" "$@"
