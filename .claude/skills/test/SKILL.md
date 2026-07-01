---
name: test
description: Run the first-linux-setup test suite on a real Debian box via Crabbox (static gates + bats unit + real integration run). Use before every release and after changes to lib/ or modules/.
---

# Run the test suite via Crabbox

Tests must run on **real Linux**, not just the dev box. Crabbox provides an ephemeral
Debian runner. This skill runs the full suite there and reports the result.

## Layers (see `tests/`)
- **Static:** `bash -n` + `shellcheck` (via `tests/run.sh`).
- **Unit (bats):** `tests/unit/*.bats` — detection, config layering, module gating,
  SSH-harden lockout failsafe, util helpers. Run anywhere, no root.
- **Integration (bats):** `tests/integration/*.bats` — `dryrun` (root) and `real_run`
  (root **and** `FLS_ALLOW_REAL=1`; mutating, SSH-safe). Run on Crabbox only.

## Procedure

1. **Warm a box** and keep the slug:
   ```bash
   crabbox warmup            # note the returned slug (cbx_…)
   ```
2. **Install test deps** on the box (once per box):
   ```bash
   crabbox run --id <slug> -- sudo apt-get update
   crabbox run --id <slug> -- sudo apt-get install -y bats shellcheck
   ```
3. **Static + unit gate** (must be green):
   ```bash
   crabbox run --id <slug> -- bash tests/run.sh unit
   ```
4. **Full run incl. real integration** (root + explicit opt-in; mutates the box):
   ```bash
   crabbox run --id <slug> -- sudo env FLS_ALLOW_REAL=1 bash tests/run.sh all
   ```
5. **On failure**, inspect live and, if the box failed sync sanity, stop it and warm a
   fresh one (don't debug on a bad box):
   ```bash
   crabbox ssh --id <slug>
   ```
6. **Stop** the box when done:
   ```bash
   crabbox stop <slug>
   ```

## Report
Summarize: which layers ran, pass/fail counts, and — for any failure — the failing test
name and the relevant output. Do not report "green" unless step 3 (and, for releases,
step 4) actually passed.

## When to use
- **Before every release** (part of the release checklist) — full run (step 4) must pass.
- After any change under `lib/` or `modules/`, or when adding a module/flow (its new
  bats tests must run here).
