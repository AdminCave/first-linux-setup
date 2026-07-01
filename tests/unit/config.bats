#!/usr/bin/env bats
# Unit tests: lib/config.sh layering precedence

load '../helpers/setup'

setup() { load_libs; }

@test "precedence: config.conf > profile > defaults; unset keys fall through" {
  local d="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$d/profiles"
  printf 'FOO=default\nBAR=default\nBAZ=default\n' >"$d/profiles/defaults.conf"
  printf 'FOO=profile\nBAR=profile\n'             >"$d/profiles/myprof.conf"
  printf 'FOO=adminconf\n'                        >"$d/config.conf"
  FLS_DIR="$d"
  config_load myprof
  [ "$FOO" = adminconf ]   # config.conf wins
  [ "$BAR" = profile ]     # profile wins over defaults
  [ "$BAZ" = default ]     # only in defaults
}

@test "missing profile file is tolerated" {
  local d="$BATS_TEST_TMPDIR/repo2"
  mkdir -p "$d/profiles"
  printf 'FOO=default\n' >"$d/profiles/defaults.conf"
  FLS_DIR="$d"
  run config_load does-not-exist
  [ "$status" -eq 0 ]
}

@test "local FLS_CONFIG file is applied last" {
  local d="$BATS_TEST_TMPDIR/repo3"
  mkdir -p "$d/profiles"
  printf 'FOO=default\n'  >"$d/profiles/defaults.conf"
  printf 'FOO=adminconf\n'>"$d/config.conf"
  local ext="$BATS_TEST_TMPDIR/ext.conf"; printf 'FOO=external\n' >"$ext"
  FLS_DIR="$d" FLS_CONFIG="$ext"
  config_load default
  [ "$FOO" = external ]
}
