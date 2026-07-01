#!/usr/bin/env bash
# Module 30-packages — APT repos, packages, files, services
# shellcheck shell=bash
module_run() {
  export DEBIAN_FRONTEND=noninteractive

  # --- APT repos: "name|deb_line|key_url|format(list|sources)" ---
  local spec name debline keyurl fmt
  for spec in "${APT_REPOS[@]}"; do
    [[ -n "$spec" ]] || continue
    IFS='|' read -r name debline keyurl fmt <<<"$spec"
    fmt="${fmt:-list}"
    if [[ -n "$keyurl" ]]; then
      log_info "30-packages: keyring for $name"
      fls_run bash -c "curl -fsSL '$keyurl' | gpg --dearmor -o '/usr/share/keyrings/${name}.gpg'"
    fi
    if [[ "$fmt" == sources ]]; then
      printf '%s\n' "$debline" | write_file "/etc/apt/sources.list.d/${name}.sources" 0644 root
    else
      printf '%s\n' "$debline" | write_file "/etc/apt/sources.list.d/${name}.list" 0644 root
    fi
  done
  [[ ${#APT_REPOS[@]} -gt 0 ]] && fls_run apt-get update

  # --- Install packages ---
  if [[ ${#PACKAGES_INSTALL[@]} -gt 0 ]]; then
    log_info "30-packages: installing ${#PACKAGES_INSTALL[@]} packages"
    fls_run apt-get -y install "${PACKAGES_INSTALL[@]}"
  fi

  # --- Bare-metal packages (only on physical hardware) ---
  if [[ ${#PACKAGES_INSTALL_BAREMETAL[@]} -gt 0 ]]; then
    if is_bare_metal; then
      log_info "30-packages: bare-metal — installing ${PACKAGES_INSTALL_BAREMETAL[*]}"
      fls_run apt-get -y install "${PACKAGES_INSTALL_BAREMETAL[@]}"
    else
      log_info "30-packages: VM/container (virt=${DETECTED_VIRT}, container=${DETECTED_CONTAINER}) — bare-metal packages skipped."
    fi
  fi

  # --- Remove packages ---
  local p purge=()
  for p in "${PACKAGES_REMOVE[@]}"; do
    [[ -n "$p" ]] && pkg_installed "$p" && purge+=("$p")
  done
  if [[ ${#purge[@]} -gt 0 ]]; then
    log_info "30-packages: removing ${purge[*]}"
    fls_run apt-get -y purge "${purge[@]}"
  fi

  # --- Remove files (with backup) ---
  local f
  for f in "${FILES_REMOVE[@]}"; do
    [[ -e "$f" ]] || continue
    backup_file "$f"
    log_info "30-packages: removing file $f"
    fls_run rm -f "$f"
  done

  # --- Deploy files: "source:target:perms" ---
  local d src dst perms
  for d in "${FILES_DEPLOY[@]}"; do
    [[ -n "$d" ]] || continue
    IFS=':' read -r src dst perms <<<"$d"
    [[ "$src" != /* ]] && src="$FLS_DIR/$src"
    [[ -r "$src" ]] || { log_warn "30-packages: source missing: $src"; continue; }
    backup_file "$dst"
    fls_run install -m "${perms:-0644}" "$src" "$dst"
    log_info "30-packages: deploy $src -> $dst (${perms:-0644})"
  done

  # --- Enable services ---
  local s
  for s in "${SERVICES_ENABLE[@]}"; do
    [[ -n "$s" ]] && fls_run systemctl enable --now "$s"
  done
}
