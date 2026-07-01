# tests/helpers/setup.bash — shared helpers for the bats suite
# shellcheck shell=bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

# load_libs — source the toolkit libraries for unit tests (dry-run, unattended)
load_libs() {
  export FLS_DIR="$REPO_ROOT"
  export DRY_RUN="${DRY_RUN:-true}"
  export ASSUME_YES="${ASSUME_YES:-true}"
  export FLS_LOG="${BATS_TEST_TMPDIR:-/tmp}/fls-test.log"
  # shellcheck source=/dev/null
  source "$FLS_DIR/lib/log.sh"
  # shellcheck source=/dev/null
  source "$FLS_DIR/lib/ui.sh"
  # shellcheck source=/dev/null
  source "$FLS_DIR/lib/util.sh"
  # shellcheck source=/dev/null
  source "$FLS_DIR/lib/detect.sh"
  # shellcheck source=/dev/null
  source "$FLS_DIR/lib/config.sh"
}

# setup_shims — prepare a bin dir on PATH for fake external commands
setup_shims() {
  SHIMBIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$SHIMBIN"
  PATH="$SHIMBIN:$PATH"
}

# shim <name>  (body via stdin) — create a fake executable on PATH
shim() {
  local name="$1"
  cat >"$SHIMBIN/$name"
  chmod +x "$SHIMBIN/$name"
}

# run_module <NN-name> — source a module and call module_run (current shell)
run_module() {
  local mod="$1" rc
  # shellcheck source=/dev/null
  source "$FLS_DIR/modules/$mod.sh"
  module_run
  rc=$?
  unset -f module_run
  return $rc
}
