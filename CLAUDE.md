# CLAUDE.md

## Project overview

`first-linux-setup` (GitHub `AdminCave/first-linux-setup`) is part of **AdminCave** —
tooling that makes admins' lives easier. It is a **one-liner base-setup** for fresh
Linux servers/clients: it auto-detects the environment, applies a matching profile,
and performs the usual first-time setup (bashrc, SSH, packages, hardening, Proxmox
repos, …). Pure **Bash**, no runtime deps beyond coreutils/`curl`/`tar`. Built to be
**forked** and configured via a Bash config plus hook scripts.

**Structure**

| Path | Role |
|---|---|
| `bootstrap.sh` | One-liner loader: downloads the toolkit, runs `setup.sh` |
| `setup.sh` | Orchestrator: detect → config → hooks → modules → summary |
| `lib/` | `detect` · `config` · `ui` · `log` · `util` |
| `modules/NN-name.sh` | One idempotent task each, gated by config |
| `profiles/*.conf` | `defaults` + one per detected profile |
| `assets/` | `bashrc.template` · `fastfetch.jsonc` |
| `hooks/pre.d`, `hooks/post.d` | User extensions (`*.sh`, alphabetical) |
| `config.conf` | The admin's own config (adapted in a fork) |

**Supported (always newest):** Proxmox VE 9, Proxmox Backup Server 4, Debian 13
„trixie", Ubuntu 26.04 LTS — with/without desktop. **Detection order matters:** PVE/PBS
must be detected *before* Debian/Ubuntu (they report as Debian in `/etc/os-release`).

## Working style

Act like a senior engineer; Bash / Linux / Proxmox focus.

- **Think first, then code.** For non-trivial changes give a short plan (Step →
  Verification), state assumptions, wait for confirmation. Typos/style fixes don't.
- **Raise ambiguity, don't silently decide.** Multiple plausible readings → name them, ask.
- **Root cause over symptom.** No workarounds that only move the problem.
- **YAGNI.** No speculative abstractions; three similar lines beat a premature helper.
- **Surgical changes.** Touch only what the task needs, match existing style, clean up
  orphans your change creates. Every changed line must trace back to the task.
- **Communication: German**, technical terms and code identifiers in the original.
  Direct and short; honest about limits ("not verified", "assumption"); push back on
  scope creep; interpret dictated input by intent, not literal wording.

## Verify facts — no assumptions (top rule)

This runs on **production Linux/Proxmox hosts** via a one-liner; a wrong assumption can
break real systems.

- Before relying on a version, package name, path, repo format, or command behavior,
  **verify it** against official docs (`WebFetch`/`WebSearch`) or by running it — even
  if this file or the code says otherwise. Example that already bit us: PVE 9 / PBS 4
  moved APT repos to the deb822 `.sources` format.
- Prefer official docs over blog/forum posts for the final implementation.
- Say "not verified" when you haven't checked; don't fabricate command behavior.

## Safety model (project-specific — important)

- **Never clobber intentional config.** `lib/detect.sh` flags sensitive roles (Samba AD
  DC, linuxmuster.net, DNS/NTP/mail servers) and existing non-tool-managed configs;
  modules skip in `*_MANAGE=auto`. Force with `always`.
- **SSH lockout failsafe.** Never disable password login unless valid keys exist for the
  target user; validate with `sshd -t` before reload; roll back on failure.
- **Backups before change** (`file.bak.<timestamp>`), a managed-marker on tool-written
  files, and `--dry-run` that shows every action.
- **Idempotent modules** — safe to re-run (skip when already applied).

## Testing & Definition of Done

Tests are part of "done" — a new module, helper, or flow ships **with** tests.

The suite lives in `tests/` (bats-core) and is driven by `tests/run.sh`:

- **Static:** `bash -n` + `shellcheck` — must be clean.
- **Unit (`tests/unit/*.bats`):** detection, config layering, module gating, the
  SSH-harden lockout failsafe, util helpers — mocked, no root. A new module MUST add
  gating tests (enabled/disabled + skip paths); new logic gets a focused unit test.
- **Integration (`tests/integration/*.bats`):** `dryrun` (root) and `real_run` (root +
  `FLS_ALLOW_REAL=1`; mutating, SSH-safe). Anything that touches the system (packages,
  sshd, repos, ZFS, services) needs a real-run assertion.

**Run everything on real Linux via Crabbox — this is the authoritative gate.** Use the
`/test` skill: it warms an ephemeral Debian box, installs `bats`/`shellcheck`, and runs
`tests/run.sh all`. Locally you can run `tests/run.sh unit` (needs bats-core); the dev box
can't run the root/mutating tests.

Report clearly what ran and on which system; never claim green unless the suite actually
passed. After a push/tag triggers CI, watch it to completion (`gh run watch`).

## Code conventions

- **Bash:** `set -euo pipefail`; quote expansions; `${VAR:-default}` under `set -u`; use
  the `fls_run` wrapper for state-changing commands (dry-run aware); modules define
  `module_run` using `local`; log via `log_info/warn/error/step`; write files through the
  `util.sh` helpers (backup + managed marker).
- **New config options** go into `profiles/defaults.conf` with a comment; profile-specific
  overrides in `profiles/<p>.conf`; the admin edits `config.conf`.
- **Conventional Commits** (`feat/fix/chore/refactor/docs/test/perf`), English messages,
  one logical change per commit, release tags `vX.Y.Z`.
- **Comments only for the non-obvious why** (hidden constraints, workarounds). The what
  is in the code.

## Docs

- **Language: English only. Format: Markdown only** (no second language, no HTML).
- **`README.md`** — user-facing entry: install one-liner, parameters, config reference,
  modules, safety. Keep in sync with every user-visible change.
- **`CHANGELOG.md`** — Keep a Changelog + SemVer; update on every release.
- Deeper topics (only if needed) → `docs/*.md`, English Markdown.
- **Doc update belongs in the same commit** as the code change; use `docs:` only when
  *only* docs change. Fix stale doc statements you notice.

## Release management

- **SemVer tags `vX.Y.Z`** are the release trigger.
- `.github/workflows/release.yml` packages the runtime files into
  `first-linux-setup.tar.gz` + `SHA256SUMS` and uploads them together with `bootstrap.sh`
  as **release assets**, marking the release as `latest`.
- **Always-works stable one-liner** (recommended):

  ```bash
  bash -c "$(curl -fsSL https://github.com/AdminCave/first-linux-setup/releases/latest/download/bootstrap.sh)"
  ```

  The released `bootstrap.sh` pulls the toolkit tarball from the **same** latest release,
  so bootstrap and toolkit are always version-consistent.
- **Pin a version:** `FLS_VERSION=vX.Y.Z` (or the `releases/download/vX.Y.Z/…` URL).
- **Dev / bleeding edge:** `FLS_VERSION=dev` (or `FLS_REF=main`) pulls the git branch tarball.
- **Always run the full test suite before a release** — via the `/test` skill (Crabbox,
  `tests/run.sh all`, incl. the real Debian run). Never tag with a red or unrun suite.
- **Release checklist:** `/test` green → move `CHANGELOG.md` `Unreleased` → `X.Y.Z`/date →
  commit → tag `vX.Y.Z` → push tag → watch CI → verify the stable one-liner + `--dry-run`
  on a clean host.
