#!/usr/bin/env bash
# tests/run.sh — static gates + bats suite.
# Usage: tests/run.sh [unit|integration|all]   (default: unit)
# Real integration tests additionally require: root + FLS_ALLOW_REAL=1
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
mode="${1:-unit}"
fail=0

echo "== bash -n =="
for f in bootstrap.sh setup.sh lib/*.sh modules/*.sh tests/*.sh tests/helpers/*.bash; do
  bash -n "$f" || { echo "  FAIL $f"; fail=1; }
done

if command -v shellcheck >/dev/null 2>&1; then
  echo "== shellcheck =="
  # shell=bash / source directives are declared inside the files
  shellcheck -x bootstrap.sh setup.sh lib/*.sh modules/*.sh || fail=1
else
  echo "== shellcheck: not installed — skipped =="
fi

if command -v bats >/dev/null 2>&1; then
  echo "== bats ($mode) =="
  case "$mode" in
    unit)        bats tests/unit || fail=1 ;;
    integration) bats tests/integration || fail=1 ;;
    all)         bats tests/unit tests/integration || fail=1 ;;
    *)           echo "unknown mode: $mode" >&2; fail=1 ;;
  esac
else
  echo "== bats: not installed =="
  echo "   install with: apt-get install -y bats   (or clone bats-core)"
  fail=1
fi

[[ $fail -eq 0 ]] && echo "== ALL GREEN ==" || echo "== FAILURES ($fail) =="
exit $fail
