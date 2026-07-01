# first-linux-setup

Teil von **[AdminCave](https://github.com/AdminCave)** — Tools, die Admins das Leben leichter machen.

`first-linux-setup` ist ein **One-Liner-Grundsetup** für frische Linux-Server und -Clients.
Es **erkennt die Umgebung automatisch**, wendet ein passendes Profil an und richtet die
üblichen Erst-Einstellungen ein (bashrc, SSH, Pakete, Härtung, Proxmox-Repos …).
Das Tool ist **forkbar** und über eine Bash-Config sowie eigene **Hook-Skripte** anpassbar.

> ⚠️ **Status:** In aktiver Entwicklung. Framework + alle Module sind implementiert und per
> Dry-Run getestet, aber **noch nicht auf allen echten Zielsystemen** (PVE/PBS/Ubuntu) verifiziert.
> Erste Läufe bitte immer mit `--dry-run`.

---

## Inhalt

- [Unterstützte Systeme](#unterstützte-systeme)
- [Schnellstart](#schnellstart-one-liner)
- [Parameter & CLI-Optionen](#parameter--cli-optionen)
- [Wie die Erkennung funktioniert](#wie-die-erkennung-funktioniert)
- [Konfiguration](#konfiguration)
- [Config-Referenz](#config-referenz)
- [Module](#module)
- [Sicherheitskonzept](#sicherheitskonzept)
- [Hooks](#hooks-eigene-erweiterungen)
- [Forken & eigene Config](#forken--eigene-config)
- [Projektstruktur](#projektstruktur)

---

## Unterstützte Systeme

Erkannt werden (jeweils die aktuelle Version, Stand 2026):

| System | Version | Profil |
|---|---|---|
| Proxmox VE | 9.x (Debian 13 „trixie") | `proxmox-ve` |
| Proxmox Backup Server | 4.x | `pbs` |
| Debian | 13 „trixie" | `debian-server` / `debian-desktop` |
| Ubuntu | 26.04 LTS | `ubuntu-server` / `ubuntu-desktop` |
| sonstiges | — | `generic` (konservativ) |

> **Wichtig:** Proxmox VE/PBS melden sich in `/etc/os-release` als „Debian trixie". Das Tool
> prüft deshalb **zuerst** auf Proxmox-Marker und fällt erst dann auf Debian/Ubuntu zurück.

---

## Schnellstart (One-Liner)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/AdminCave/first-linux-setup/main/bootstrap.sh)"
```

**Empfohlen für den ersten Lauf** — erst anschauen, was passieren würde (Argumente nach `--`):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/AdminCave/first-linux-setup/main/bootstrap.sh)" -- --dry-run
```

Muss als **root** laufen (`sudo -i`). Benötigt `curl` (oder `wget`) und `tar`.

---

## Parameter & CLI-Optionen

### ENV-Variablen (dem One-Liner voranstellen)

| Variable | Default | Bedeutung |
|---|---|---|
| `FLS_REPO` | `AdminCave/first-linux-setup` | Quell-Repo — für Forks auf eigenes Repo setzen |
| `FLS_REF` | `main` | Branch oder Tag |
| `FLS_WORKDIR` | `/opt/first-linux-setup` | Zielverzeichnis der Installation |
| `FLS_CONFIG` | — | Pfad **oder** `http[s]`-URL zur Admin-Config |
| `FLS_CONFIG_USER` | — | Basic-Auth-Benutzer für die Config-URL |
| `FLS_CONFIG_PASS` | — | Basic-Auth-Passwort (wird über temporäres netrc genutzt, nicht in `ps` sichtbar) |
| `FLS_PROFILE` | — | Profil erzwingen (statt Auto-Erkennung) |
| `FLS_YES` | `false` | Unattended-Modus (keine Rückfragen) |

Beispiel mit geschützter Remote-Config:

```bash
FLS_CONFIG=https://intern.example/srv.conf \
FLS_CONFIG_USER=deploy FLS_CONFIG_PASS='geheim' \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/AdminCave/first-linux-setup/main/bootstrap.sh)"
```

### CLI-Optionen (`setup.sh`)

| Option | Bedeutung |
|---|---|
| `--dry-run` | Nur anzeigen, nichts ändern |
| `-y`, `--yes` | Unattended (keine Rückfragen) |
| `--profile <name>` | Profil erzwingen |
| `--config <pfad\|url>` | Admin-Config laden |
| `-h`, `--help` | Hilfe |

---

## Wie die Erkennung funktioniert

`lib/detect.sh` ermittelt in dieser Reihenfolge:

1. **Proxmox VE?** — Paket `proxmox-ve`, `/etc/pve`, `pveversion`
2. **Proxmox Backup Server?** — Paket `proxmox-backup-server`, `proxmox-backup-manager`
3. **OS** aus `/etc/os-release` (`debian` / `ubuntu`)
4. **Desktop?** — `graphical.target`, `$XDG_CURRENT_DESKTOP`, Display-Manager (gdm/sddm/lightdm)
5. **Virtualisierung / Bare-Metal** — `systemd-detect-virt` (VM/Container vs. physische Hardware). Hardware-Tools (`PACKAGES_INSTALL_BAREMETAL`) werden nur auf Bare-Metal installiert.
6. **Sensible Rollen** — Samba-AD-DC, linuxmuster.net, DNS-/NTP-/Mailserver (siehe [Sicherheitskonzept](#sicherheitskonzept))

Ergebnis ist das aktive **Profil** (`$FLS_PROFILE`), das die Default-Config bestimmt.

---

## Konfiguration

Die Einstellungen werden **geschichtet** geladen — spätere überschreiben frühere:

```
profiles/defaults.conf → profiles/<profil>.conf → config.conf → FLS_CONFIG (Datei/URL) → ENV
```

- **`profiles/defaults.conf`** — dokumentierte Standardwerte (im Fork möglichst nicht ändern)
- **`profiles/<profil>.conf`** — profil-spezifische Abweichungen (z. B. chrony auf Proxmox)
- **`config.conf`** — **deine** Admin-Config (hier anpassen)
- **`FLS_CONFIG`** — zentrale Config per Datei/URL (praktisch für viele Hosts)

---

## Config-Referenz

Alle Schlüssel mit ihren Defaults (aus `profiles/defaults.conf`):

```bash
# System / Updates
RUN_UPDATE=true            # apt update
RUN_UPGRADE=true           # apt dist-upgrade + autoremove
TIMEZONE="Europe/Berlin"

# Locale / Tastatur   (MANAGE: auto|always|never)
LOCALE_MANAGE="auto"
LOCALE="de_DE.UTF-8"
KEYMAP="de"

# Zeit / NTP
NTP_MANAGE="auto"          # auto = nicht anfassen, wenn schon eingerichtet (DC etc.)
NTP_BACKEND="timesyncd"    # timesyncd|chrony  (Proxmox-Profil nutzt chrony)
NTP_SERVERS=()

# bashrc  (Template: assets/bashrc.template)
DEPLOY_BASHRC=true
BASHRC_ALL_USERS=true      # root + /etc/skel + alle Login-User
BASHRC_BACKUP=true

# fastfetch  (Vorlage: assets/fastfetch.jsonc)
INSTALL_FASTFETCH=true

# Gast-Agent (nur in VMs)
GUEST_AGENT_INSTALL="auto"    # auto = nach VM-Typ (kvm/qemu -> qemu-guest-agent); true|false

# Pakete / Dateien / Repos
PACKAGES_INSTALL=()                                               # überall
PACKAGES_INSTALL_BAREMETAL=(lshw lm-sensors smartmontools gdisk)  # nur physische HW
PACKAGES_REMOVE=()
FILES_REMOVE=()            # z.B. /etc/motd
FILES_DEPLOY=()            # "quelle:ziel:perms"
APT_REPOS=()              # "name|deb_line|key_url|format(list|sources)"
SERVICES_ENABLE=()

# SSH
SSH_KEYS_TARGET_USER="root"
SSH_KEYS_ADD=()            # ganze Keys
SSH_KEYS_REMOVE=()         # Patterns
SSH_KEYS_KEEP_ONLY=()      # falls gesetzt: ALLE anderen Keys entfernen!
SSH_HARDEN=true            # nur Key-Login (mit Aussperr-Failsafe)
SSH_PORT=22

# Passwörter
PROMPT_ROOT_PASSWORD=true
ADMIN_USERS_PROMPT=(master admin administrator sysadmin sysop linux-admin linuxadmin operator superadmin)

# fail2ban
FAIL2BAN_ENABLE=true
FAIL2BAN_SSH_MAXRETRY=10
FAIL2BAN_SSH_BANTIME=3600
FAIL2BAN_SSH_FINDTIME=600

# Proxmox VE / PBS — Repos (deb822)
PVE_DISABLE_ENTERPRISE=true
PVE_SWITCH_NOSUB_REPO=true
PVE_DISABLE_CEPH_ENTERPRISE=true
PVE_SWITCH_CEPH_NOSUB=true
PVE_REMOVE_SUB_NAG=false   # optional; patcht proxmoxlib.js (update-flüchtig)
PBS_DISABLE_ENTERPRISE=true
PBS_SWITCH_NOSUB_REPO=true

# Proxmox — Tuning
SWAPPINESS=10
ZFS_ARC_PROMPT=true        # min/max interaktiv erfragen
ZFS_ARC_MIN=""             # z.B. "2G" (leer = nicht setzen)
ZFS_ARC_MAX=""             # z.B. "8G"
```

---

## Module

Ausgeführt in dieser Reihenfolge; jedes ist **idempotent** und per Config schaltbar:

| # | Modul | Was es tut |
|---|---|---|
| 10 | `update` | `apt update`, `dist-upgrade`, `autoremove` |
| 20 | `locale-keyboard` | Timezone, Locale, Tastaturlayout |
| 25 | `time-ntp` | Zeit-Sync (timesyncd/chrony); schützt bestehende Einrichtung |
| 30 | `packages` | Pakete install/remove (+ Bare-Metal-only-Gruppe), Dateien, APT-Repos, Dienste |
| 35 | `guest-agent` | in VMs: Gast-Agent (Proxmox/KVM → `qemu-guest-agent`) |
| 40 | `bashrc` | bashrc-Template → root + /etc/skel + alle Login-User |
| 45 | `fastfetch` | fastfetch installieren + Config ausrollen |
| 50 | `ssh-keys` | `authorized_keys` pflegen (add/remove/keep-only) |
| 55 | `ssh-harden` | nur Key-Login, `sshd -t`-Check, **Aussperr-Failsafe** |
| 60 | `passwords` | root- & Admin-User-Passwörter (Rückfrage pro User) |
| 70 | `fail2ban` | fail2ban + SSH-Jail |
| 80 | `proxmox-repos` | Enterprise→No-Subscription (PVE, Ceph, PBS) |
| 85 | `proxmox-tuning` | `vm.swappiness`, ZFS-ARC min/max (+ `update-initramfs`) |

Die Proxmox-Module (80/85) laufen nur auf `proxmox-ve`/`pbs`-Profilen.

---

## Sicherheitskonzept

- **Aussperr-Schutz:** SSH-Härtung deaktiviert Passwort-Login **nur**, wenn für den Ziel-User
  gültige Keys vorhanden sind. Die sshd-Config wird vor dem Reload mit `sshd -t` validiert und
  bei Fehler automatisch zurückgerollt.
- **Absichtliche Konfiguration wird nicht überschrieben:** Erkennt das Tool eine sensible Rolle
  (Samba-AD-**DC**, **linuxmuster.net**, DNS-/NTP-/Mailserver) oder eine bereits vorhandene,
  nicht vom Tool stammende NTP-Config, überspringt es das betroffene Modul (`*_MANAGE=auto`).
  Erzwingen mit `*_MANAGE=always`.
- **Backups:** Vor jeder Änderung an einer bestehenden Datei wird `datei.bak.<zeitstempel>` angelegt.
- **Nachvollziehbarkeit:** Alles wird nach `/var/log/admincave-setup.log` protokolliert; am Ende
  gibt es eine Zusammenfassung mit Warn-/Fehlerzahl.
- **Dry-Run:** `--dry-run` zeigt jede Aktion, ohne etwas zu ändern.

---

## Hooks (eigene Erweiterungen)

Eigene Skripte werden automatisch mit ausgeführt:

- `hooks/pre.d/*.sh` — **vor** allen Modulen
- `hooks/post.d/*.sh` — **nach** allen Modulen

Reihenfolge = alphabetisch (Nummern-Prefix, z. B. `10-foo.sh`). Es liegen Beispiele als
`*.sh.example` bereit — zum Aktivieren nach `*.sh` kopieren.

---

## Forken & eigene Config

1. Repo forken.
2. `config.conf` anpassen (SSH-Keys, Pakete, Optionen …).
3. One-Liner mit `FLS_REPO=DeinName/first-linux-setup` aufrufen — oder den Raw-Link deines Forks nutzen.

Alternativ die Config **nicht** ins Repo legen, sondern zentral per `FLS_CONFIG=https://…`
(optional mit Basic-Auth) für viele Hosts bereitstellen.

---

## Projektstruktur

```
bootstrap.sh            One-Liner-Loader (lädt Repo, startet setup.sh)
setup.sh                Orchestrator: detect → config → hooks → module → summary
lib/
  detect.sh             OS-/Profil-/Rollen-Erkennung
  config.sh             Config-Schichten laden (inkl. URL + netrc-Auth)
  ui.sh                 Ausgabe (Farben nur bei TTY) + Rückfragen
  log.sh                Logging + Zusammenfassung
  util.sh               run/dry-run, Backups, Datei-Helfer, Hooks
modules/                je eine Aufgabe (10-… bis 85-…)
profiles/               defaults + ein .conf pro Profil
assets/                 bashrc.template · fastfetch.jsonc
hooks/pre.d | post.d/   eigene *.sh
config.conf             deine Admin-Config
```

---

## Lizenz

Noch festzulegen.
