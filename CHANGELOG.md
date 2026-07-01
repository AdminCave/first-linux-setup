# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-07-01

### Changed
- CI: bump `actions/checkout` v4 → v5 in the release workflow (Node 20 deprecation).

## [0.1.0] - 2026-07-01

### Added
- One-liner bootstrap + `setup.sh` orchestrator (detect → config → hooks → modules → summary).
- Environment detection: Proxmox VE/PBS before Debian/Ubuntu; desktop / virt / container /
  bare-metal; sensitive roles (Samba AD DC, linuxmuster.net, DNS/NTP/mail servers).
- Layered Bash config: `defaults → profile → config.conf → FLS_CONFIG (file/URL) → ENV`,
  with optional Basic-Auth for remote configs via a temporary netrc.
- Profiles: `proxmox-ve`, `pbs`, `debian-server/-desktop`, `ubuntu-server/-desktop`, `generic`.
- Modules: `update`, `locale-keyboard`, `time-ntp` (protects existing time config),
  `packages` (+ bare-metal-only group), `guest-agent` (`qemu-guest-agent` in VMs),
  `bashrc`, `fastfetch`, `ssh-keys`, `ssh-harden` (lockout failsafe + `sshd -t`),
  `passwords`, `fail2ban`, `proxmox-repos` (PVE/Ceph/PBS deb822), `proxmox-tuning`
  (swappiness, ZFS ARC).
- Hook system (`hooks/pre.d`, `hooks/post.d`), `--dry-run`, logging + run summary, backups.
- Release workflow producing release assets and an always-latest stable URL.
- Test suite under `tests/` (bats-core): static gates (`bash -n`, `shellcheck`), unit tests
  (detection, config layering, module gating, SSH-harden lockout failsafe, util helpers)
  and integration tests (`dryrun`, `real_run`). Runner: `tests/run.sh`.
- `/test` skill to run the suite on a real Debian box via Crabbox; release workflow runs
  the static + unit gate before packaging.

### Changed
- Renamed the internal dry-run wrapper `run` → `fls_run` (avoids a name collision with the
  bats `run` builtin and is less collision-prone in general).

### Fixed
- `setup.sh` exited non-zero on real (non-dry) runs: `log_summary` lacked a trailing
  newline (tripping `set -e` at the summary `read`) and the final `[[ … ]] &&` line became
  the script's exit status. Both fixed and guarded by integration tests.

[Unreleased]: https://github.com/AdminCave/first-linux-setup/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/AdminCave/first-linux-setup/releases/tag/v0.1.1
[0.1.0]: https://github.com/AdminCave/first-linux-setup/releases/tag/v0.1.0
