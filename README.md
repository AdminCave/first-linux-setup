# first-linux-setup

Part of **[AdminCave](https://github.com/AdminCave)** — tooling that makes admins' lives easier.

`first-linux-setup` is a **one-liner base setup** for fresh Linux servers and clients.
It **auto-detects the environment**, applies a matching profile, and performs the usual
first-time configuration (bashrc, SSH, packages, hardening, Proxmox repos …). The tool is
**forkable** and configurable via a Bash config plus your own **hook scripts**.

> ⚠️ **Status:** Under active development. The framework and all modules are implemented
> and tested via dry-run, but **not yet verified on every real target** (PVE/PBS/Ubuntu).
> Always do the first run with `--dry-run`.

---

## Contents

- [Supported systems](#supported-systems)
- [Quick start](#quick-start-one-liner)
- [Parameters & CLI options](#parameters--cli-options)
- [How detection works](#how-detection-works)
- [Configuration](#configuration)
- [Config reference](#config-reference)
- [Modules](#modules)
- [Safety model](#safety-model)
- [Hooks](#hooks-your-own-extensions)
- [Forking & your own config](#forking--your-own-config)
- [Project structure](#project-structure)
- [Releases & versioning](#releases--versioning)

---

## Supported systems

Detected (each: the current version, as of 2026):

| System | Version | Profile |
|---|---|---|
| Proxmox VE | 9.x (Debian 13 „trixie") | `proxmox-ve` |
| Proxmox Backup Server | 4.x | `pbs` |
| Debian | 13 „trixie" | `debian-server` / `debian-desktop` |
| Ubuntu | 26.04 LTS | `ubuntu-server` / `ubuntu-desktop` |
| anything else | — | `generic` (conservative) |

> **Important:** Proxmox VE/PBS report themselves as „Debian trixie" in `/etc/os-release`.
> The tool therefore checks for Proxmox markers **first** and only falls back to
> Debian/Ubuntu afterwards.

---

## Quick start (one-liner)

**Stable (recommended)** — the URL always points to the latest release:

```bash
bash -c "$(curl -fsSL https://github.com/AdminCave/first-linux-setup/releases/latest/download/bootstrap.sh)"
```

**Recommended for the first run** — preview what would happen (arguments after `--`):

```bash
bash -c "$(curl -fsSL https://github.com/AdminCave/first-linux-setup/releases/latest/download/bootstrap.sh)" -- --dry-run
```

Must run as **root** (`sudo -i`). Requires `curl` (or `wget`) and `tar`.

Pick a version: `FLS_VERSION=stable` (default), `FLS_VERSION=vX.Y.Z` (pinned), or
`FLS_VERSION=dev` (current `main` branch).

---

## Parameters & CLI options

### ENV variables (prepend to the one-liner)

| Variable | Default | Meaning |
|---|---|---|
| `FLS_REPO` | `AdminCave/first-linux-setup` | Source repo — set to your own for forks |
| `FLS_VERSION` | `stable` | `stable` (latest release), `vX.Y.Z` (pinned), or `dev` (git branch) |
| `FLS_REF` | — | Git branch/tag (implies `dev` mode) |
| `FLS_WORKDIR` | `/opt/first-linux-setup` | Install target directory |
| `FLS_CONFIG` | — | Path **or** `http[s]` URL to the admin config |
| `FLS_CONFIG_USER` | — | Basic-Auth user for the config URL |
| `FLS_CONFIG_PASS` | — | Basic-Auth password (used via a temporary netrc, not visible in `ps`) |
| `FLS_PROFILE` | — | Force a profile (instead of auto-detection) |
| `FLS_YES` | `false` | Unattended mode (no prompts) |

Example with a protected remote config:

```bash
FLS_CONFIG=https://internal.example/srv.conf \
FLS_CONFIG_USER=deploy FLS_CONFIG_PASS='secret' \
bash -c "$(curl -fsSL https://github.com/AdminCave/first-linux-setup/releases/latest/download/bootstrap.sh)"
```

### CLI options (`setup.sh`)

| Option | Meaning |
|---|---|
| `--dry-run` | Only show what would happen, change nothing |
| `-y`, `--yes` | Unattended (no prompts) |
| `--profile <name>` | Force a profile |
| `--config <path\|url>` | Load an admin config |
| `-h`, `--help` | Help |

---

## How detection works

`lib/detect.sh` determines, in this order:

1. **Proxmox VE?** — package `proxmox-ve`, `/etc/pve`, `pveversion`
2. **Proxmox Backup Server?** — package `proxmox-backup-server`, `proxmox-backup-manager`
3. **OS** from `/etc/os-release` (`debian` / `ubuntu`)
4. **Desktop?** — `graphical.target`, `$XDG_CURRENT_DESKTOP`, display manager (gdm/sddm/lightdm)
5. **Virtualization / bare-metal** — `systemd-detect-virt` (VM/container vs. physical hardware).
   Hardware tools (`PACKAGES_INSTALL_BAREMETAL`) are installed on bare-metal only.
6. **Sensitive roles** — Samba AD DC, linuxmuster.net, DNS/NTP/mail servers (see [Safety model](#safety-model))

The result is the active **profile** (`$FLS_PROFILE`), which selects the default config.

---

## Configuration

Settings are loaded in **layers** — later ones override earlier ones:

```
profiles/defaults.conf → profiles/<profile>.conf → config.conf → FLS_CONFIG (file/URL) → ENV
```

- **`profiles/defaults.conf`** — documented defaults (avoid changing this in a fork)
- **`profiles/<profile>.conf`** — profile-specific overrides (e.g. chrony on Proxmox)
- **`config.conf`** — **your** admin config (edit this)
- **`FLS_CONFIG`** — a central config via file/URL (handy for many hosts)

---

## Config reference

All keys with their defaults (from `profiles/defaults.conf`):

```bash
# System / updates
RUN_UPDATE=true            # apt update
RUN_UPGRADE=true           # apt dist-upgrade + autoremove
TIMEZONE="Europe/Berlin"

# Locale / keyboard   (MANAGE: auto|always|never)
LOCALE_MANAGE="auto"
LOCALE="de_DE.UTF-8"
KEYMAP="de"

# Time / NTP
NTP_MANAGE="auto"          # auto = leave alone if already set up (DC etc.)
NTP_BACKEND="timesyncd"    # timesyncd|chrony  (the Proxmox profile uses chrony)
NTP_SERVERS=()

# Guest agent (VMs only)
GUEST_AGENT_INSTALL="auto" # auto = by VM type (kvm/qemu -> qemu-guest-agent); true|false

# bashrc  (template: assets/bashrc.template)
DEPLOY_BASHRC=true
BASHRC_ALL_USERS=true      # root + /etc/skel + all login users
BASHRC_BACKUP=true

# fastfetch  (template: assets/fastfetch.jsonc)
INSTALL_FASTFETCH=true

# Packages / files / repos
PACKAGES_INSTALL=()                                              # everywhere
PACKAGES_INSTALL_BAREMETAL=(lshw lm-sensors smartmontools gdisk) # physical HW only
PACKAGES_REMOVE=()
FILES_REMOVE=()            # e.g. /etc/motd
FILES_DEPLOY=()            # "source:target:perms"
APT_REPOS=()              # "name|deb_line|key_url|format(list|sources)"
SERVICES_ENABLE=()

# SSH
SSH_KEYS_TARGET_USER="root"
SSH_KEYS_ADD=()            # full keys
SSH_KEYS_REMOVE=()         # patterns
SSH_KEYS_KEEP_ONLY=()      # if set: remove ALL other keys!
SSH_HARDEN=true            # key-only login (with lockout failsafe)
SSH_PORT=22

# Passwords
PROMPT_ROOT_PASSWORD=true
ADMIN_USERS_PROMPT=(master admin administrator sysadmin sysop linux-admin linuxadmin operator superadmin)

# fail2ban
FAIL2BAN_ENABLE=true
FAIL2BAN_SSH_MAXRETRY=10
FAIL2BAN_SSH_BANTIME=3600
FAIL2BAN_SSH_FINDTIME=600

# Proxmox VE / PBS — repos (deb822)
PVE_DISABLE_ENTERPRISE=true
PVE_SWITCH_NOSUB_REPO=true
PVE_DISABLE_CEPH_ENTERPRISE=true
PVE_SWITCH_CEPH_NOSUB=true
PVE_REMOVE_SUB_NAG=false   # optional; patches proxmoxlib.js (reverted by updates)
PBS_DISABLE_ENTERPRISE=true
PBS_SWITCH_NOSUB_REPO=true

# Proxmox — tuning
SWAPPINESS=10
ZFS_ARC_PROMPT=true        # ask for min/max interactively
ZFS_ARC_MIN=""             # e.g. "2G" (empty = do not set)
ZFS_ARC_MAX=""             # e.g. "8G"
```

---

## Modules

Run in this order; each is **idempotent** and toggled via config:

| # | Module | What it does |
|---|---|---|
| 10 | `update` | `apt update`, `dist-upgrade`, `autoremove` |
| 20 | `locale-keyboard` | timezone, locale, keyboard layout |
| 25 | `time-ntp` | time sync (timesyncd/chrony); protects an existing setup |
| 30 | `packages` | install/remove packages (+ bare-metal-only group), files, APT repos, services |
| 35 | `guest-agent` | in VMs: guest agent (Proxmox/KVM → `qemu-guest-agent`) |
| 40 | `bashrc` | bashrc template → root + /etc/skel + all login users |
| 45 | `fastfetch` | install fastfetch + deploy config |
| 50 | `ssh-keys` | manage `authorized_keys` (add/remove/keep-only) |
| 55 | `ssh-harden` | key-only login, `sshd -t` check, **lockout failsafe** |
| 60 | `passwords` | root & admin-user passwords (prompt per user) |
| 70 | `fail2ban` | fail2ban + SSH jail |
| 80 | `proxmox-repos` | enterprise → no-subscription (PVE, Ceph, PBS) |
| 85 | `proxmox-tuning` | `vm.swappiness`, ZFS ARC min/max (+ `update-initramfs`) |

The Proxmox modules (80/85) only run on `proxmox-ve`/`pbs` profiles.

---

## Safety model

- **Lockout protection:** SSH hardening disables password login **only** when valid keys
  exist for the target user. The sshd config is validated with `sshd -t` before reload and
  rolled back automatically on error.
- **Intentional config is never clobbered:** if the tool detects a sensitive role
  (Samba AD **DC**, **linuxmuster.net**, DNS/NTP/mail server) or an existing, non-tool-managed
  NTP config, it skips the affected module (`*_MANAGE=auto`). Force with `*_MANAGE=always`.
- **Backups:** before changing an existing file, `file.bak.<timestamp>` is created.
- **Traceability:** everything is logged to `/var/log/admincave-setup.log`; a summary with
  warning/error counts is printed at the end.
- **Dry-run:** `--dry-run` shows every action without changing anything.

---

## Hooks (your own extensions)

Your own scripts are executed automatically:

- `hooks/pre.d/*.sh` — **before** all modules
- `hooks/post.d/*.sh` — **after** all modules

Order = alphabetical (number prefix, e.g. `10-foo.sh`). Examples are provided as
`*.sh.example` — copy to `*.sh` to activate.

---

## Forking & your own config

1. Fork the repo.
2. Adjust `config.conf` (SSH keys, packages, options …).
3. Run the one-liner with `FLS_REPO=YourName/first-linux-setup` — or use your fork's raw link.

Alternatively, keep the config **out** of the repo and serve it centrally via
`FLS_CONFIG=https://…` (optionally with Basic-Auth) for many hosts.

---

## Project structure

```
bootstrap.sh            One-liner loader (downloads toolkit, runs setup.sh)
setup.sh                Orchestrator: detect → config → hooks → modules → summary
lib/
  detect.sh             OS / profile / role detection
  config.sh             Load config layers (incl. URL + netrc auth)
  ui.sh                 Output (colors only on TTY) + prompts
  log.sh                Logging + summary
  util.sh               run/dry-run, backups, file helpers, hooks
modules/                one task each (10-… to 85-…)
profiles/               defaults + one .conf per profile
assets/                 bashrc.template · fastfetch.jsonc
hooks/pre.d | post.d/   your own *.sh
config.conf             your admin config
```

---

## Releases & versioning

- Releases are cut from **SemVer tags `vX.Y.Z`**.
- `.github/workflows/release.yml` packages the runtime files into
  `first-linux-setup.tar.gz` + `SHA256SUMS` and uploads them together with `bootstrap.sh`
  as **release assets**, marking the release as `latest`.
- **Always-works stable URL:**
  `https://github.com/AdminCave/first-linux-setup/releases/latest/download/bootstrap.sh`
  — this `bootstrap.sh` pulls the toolkit tarball from the **same** latest release, so
  bootstrap and toolkit are always version-consistent.
- **Pin a version:** `FLS_VERSION=vX.Y.Z`. **Dev/bleeding edge:** `FLS_VERSION=dev`.

See [`CHANGELOG.md`](CHANGELOG.md) for the version history.

---

## License

To be determined.
