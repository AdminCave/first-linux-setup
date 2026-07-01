#!/usr/bin/env bash
# Modul 30-packages — APT-Repos, Pakete, Dateien, Dienste
# shellcheck shell=bash
module_run() {
  export DEBIAN_FRONTEND=noninteractive

  # --- APT-Repos: "name|deb_line|key_url|format(list|sources)" ---
  local spec name debline keyurl fmt
  for spec in "${APT_REPOS[@]}"; do
    [[ -n "$spec" ]] || continue
    IFS='|' read -r name debline keyurl fmt <<<"$spec"
    fmt="${fmt:-list}"
    if [[ -n "$keyurl" ]]; then
      log_info "30-packages: Keyring für $name"
      run bash -c "curl -fsSL '$keyurl' | gpg --dearmor -o '/usr/share/keyrings/${name}.gpg'"
    fi
    if [[ "$fmt" == sources ]]; then
      printf '%s\n' "$debline" | write_file "/etc/apt/sources.list.d/${name}.sources" 0644 root
    else
      printf '%s\n' "$debline" | write_file "/etc/apt/sources.list.d/${name}.list" 0644 root
    fi
  done
  [[ ${#APT_REPOS[@]} -gt 0 ]] && run apt-get update

  # --- Pakete installieren ---
  if [[ ${#PACKAGES_INSTALL[@]} -gt 0 ]]; then
    log_info "30-packages: installiere ${#PACKAGES_INSTALL[@]} Pakete"
    run apt-get -y install "${PACKAGES_INSTALL[@]}"
  fi

  # --- Bare-Metal-Pakete (nur auf physischer Hardware) ---
  if [[ ${#PACKAGES_INSTALL_BAREMETAL[@]} -gt 0 ]]; then
    if is_bare_metal; then
      log_info "30-packages: Bare-Metal — installiere ${PACKAGES_INSTALL_BAREMETAL[*]}"
      run apt-get -y install "${PACKAGES_INSTALL_BAREMETAL[@]}"
    else
      log_info "30-packages: VM/Container (virt=${DETECTED_VIRT}, container=${DETECTED_CONTAINER}) — Bare-Metal-Pakete übersprungen."
    fi
  fi

  # --- Pakete entfernen ---
  local p purge=()
  for p in "${PACKAGES_REMOVE[@]}"; do
    [[ -n "$p" ]] && pkg_installed "$p" && purge+=("$p")
  done
  if [[ ${#purge[@]} -gt 0 ]]; then
    log_info "30-packages: entferne ${purge[*]}"
    run apt-get -y purge "${purge[@]}"
  fi

  # --- Dateien entfernen (mit Backup) ---
  local f
  for f in "${FILES_REMOVE[@]}"; do
    [[ -e "$f" ]] || continue
    backup_file "$f"
    log_info "30-packages: entferne Datei $f"
    run rm -f "$f"
  done

  # --- Dateien deployen: "quelle:ziel:perms" ---
  local d src dst perms
  for d in "${FILES_DEPLOY[@]}"; do
    [[ -n "$d" ]] || continue
    IFS=':' read -r src dst perms <<<"$d"
    [[ "$src" != /* ]] && src="$FLS_DIR/$src"
    [[ -r "$src" ]] || { log_warn "30-packages: Quelle fehlt: $src"; continue; }
    backup_file "$dst"
    run install -m "${perms:-0644}" "$src" "$dst"
    log_info "30-packages: deploy $src -> $dst (${perms:-0644})"
  done

  # --- Dienste aktivieren ---
  local s
  for s in "${SERVICES_ENABLE[@]}"; do
    [[ -n "$s" ]] && run systemctl enable --now "$s"
  done
}
