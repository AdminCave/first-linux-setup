#!/usr/bin/env bash
# lib/ui.sh — Console output (colors only on TTY) + prompts
# shellcheck shell=bash

if [[ -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
  C_RESET=$'\e[0m'; C_RED=$'\e[1;31m'; C_GRN=$'\e[1;32m'
  C_YEL=$'\e[1;33m'; C_BLU=$'\e[1;34m'
else
  C_RESET=''; C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''
fi

ui_say()  { printf '%s\n' "$*"; }
ui_step() { printf '%s==>%s %s\n' "$C_BLU" "$C_RESET" "$*"; }
ui_ok()   { printf '%s[ok]%s %s\n' "$C_GRN" "$C_RESET" "$*"; }
ui_warn() { printf '%s[!]%s %s\n'  "$C_YEL" "$C_RESET" "$*" >&2; }
ui_err()  { printf '%s[x]%s %s\n'  "$C_RED" "$C_RESET" "$*" >&2; }

# ask_yes_no <question> [default:y|n]  -> 0=yes, 1=no
# Unattended (ASSUME_YES=true) returns the default without asking.
ask_yes_no() {
  local q="$1" def="${2:-n}" ans
  if [[ "${ASSUME_YES:-false}" == true ]]; then
    [[ "$def" == y ]]
    return
  fi
  local hint="[y/N]"; [[ "$def" == y ]] && hint="[Y/n]"
  read -r -p "$q $hint " ans || ans=""
  ans="${ans:-$def}"
  [[ "$ans" =~ ^[JjYy]$ ]]
}

# prompt_value <question> <default> -> echo value
prompt_value() {
  local q="$1" def="${2:-}" ans
  if [[ "${ASSUME_YES:-false}" == true ]]; then printf '%s' "$def"; return; fi
  read -r -p "$q [${def}] " ans || ans=""
  printf '%s' "${ans:-$def}"
}
