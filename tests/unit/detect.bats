#!/usr/bin/env bats
# Unit tests: lib/detect.sh (profile derivation, bare-metal, roles)

load '../helpers/setup'

setup() {
  load_libs
  setup_shims
  unset XDG_CURRENT_DESKTOP
  # neutralize the project's detection helpers; tests opt back in explicitly
  have()          { return 1; }
  pkg_installed() { return 1; }
  svc_active()    { return 1; }
  # external commands used directly by detect_all
  shim systemctl <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  shim systemd-detect-virt <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "-c" ] && exit 1
echo none
EOF
  shim dpkg-query <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  # os-release fixture (overridable per test)
  OSR="$BATS_TEST_TMPDIR/os-release"
  export FLS_OS_RELEASE="$OSR"
}

@test "is_bare_metal: physical yes, VM no, container no" {
  DETECTED_VIRT=none DETECTED_CONTAINER=no;  run is_bare_metal; [ "$status" -eq 0 ]
  DETECTED_VIRT=kvm  DETECTED_CONTAINER=no;  run is_bare_metal; [ "$status" -ne 0 ]
  DETECTED_VIRT=none DETECTED_CONTAINER=yes; run is_bare_metal; [ "$status" -ne 0 ]
}

@test "role_present: matches only listed roles" {
  SENSITIVE_ROLES=" samba-ad-dc linuxmuster"
  run role_present samba-ad-dc; [ "$status" -eq 0 ]
  run role_present dns-server;  [ "$status" -ne 0 ]
}

@test "profile: plain Debian -> debian-server" {
  printf 'ID=debian\nVERSION_ID=13\nVERSION_CODENAME=trixie\n' >"$OSR"
  detect_all
  [ "$DETECTED_OS_ID" = debian ]
  [ "$DETECTED_PROFILE" = debian-server ]
}

@test "profile: Ubuntu -> ubuntu-server" {
  printf 'ID=ubuntu\nVERSION_ID=26.04\nVERSION_CODENAME=resolute\n' >"$OSR"
  detect_all
  [ "$DETECTED_PROFILE" = ubuntu-server ]
}

@test "profile: PVE marker wins over Debian os-release" {
  printf 'ID=debian\nVERSION_ID=13\nVERSION_CODENAME=trixie\n' >"$OSR"
  have() { [ "$1" = pveversion ] && return 0; return 1; }   # pretend PVE present
  detect_all
  [ "$DETECTED_PVE" = yes ]
  [ "$DETECTED_PROFILE" = proxmox-ve ]
}

@test "profile: PBS marker -> pbs" {
  printf 'ID=debian\nVERSION_ID=13\nVERSION_CODENAME=trixie\n' >"$OSR"
  have() { [ "$1" = proxmox-backup-manager ] && return 0; return 1; }
  detect_all
  [ "$DETECTED_PBS" = yes ]
  [ "$DETECTED_PROFILE" = pbs ]
}

@test "sensitive roles: samba-ad-dc detected via package" {
  printf 'ID=debian\nVERSION_ID=13\n' >"$OSR"
  pkg_installed() { [ "$1" = samba-ad-dc ] && return 0; return 1; }
  detect_all
  run role_present samba-ad-dc
  [ "$status" -eq 0 ]
}
