#!/usr/bin/env bash
# Module 20-locale-keyboard — Locale, keyboard layout, timezone
# shellcheck shell=bash
module_run() {
  local manage="${LOCALE_MANAGE:-auto}"

  # --- Timezone (usually harmless, own switch via TIMEZONE) ---
  if [[ -n "${TIMEZONE:-}" ]]; then
    local cur; cur="$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo '')"
    if [[ "$cur" != "$TIMEZONE" ]]; then
      log_info "20-locale-keyboard: Timezone $cur -> $TIMEZONE"
      fls_run timedatectl set-timezone "$TIMEZONE"
    else
      log_info "20-locale-keyboard: Timezone already $TIMEZONE."
    fi
  fi

  [[ "$manage" == never ]] && { log_info "20-locale-keyboard: Locale/Keymap MANAGE=never."; return 0; }

  # --- Locale ---
  if [[ -n "${LOCALE:-}" ]]; then
    if ! locale -a 2>/dev/null | grep -qiE "^${LOCALE//./\\.}$|^${LOCALE%%.*}"; then
      log_info "20-locale-keyboard: locale-gen $LOCALE"
      fls_run sed -i "s/^# *\(${LOCALE} \)/\1/" /etc/locale.gen
      fls_run locale-gen "$LOCALE"
    fi
    fls_run update-locale "LANG=$LOCALE"
    log_info "20-locale-keyboard: LANG=$LOCALE set."
  fi

  # --- Keymap (console) ---
  if [[ -n "${KEYMAP:-}" ]]; then
    if have localectl; then
      fls_run localectl set-keymap "$KEYMAP"
    else
      printf 'XKBLAYOUT="%s"\n' "$KEYMAP" | write_file /etc/default/keyboard 0644 root
    fi
    log_info "20-locale-keyboard: KEYMAP=$KEYMAP set."
  fi
}
