#!/usr/bin/env bash
# scripts/helpers/env.sh
# Idempotently load project environment for any script.
# - Detects DOTFILEZ_ROOT robustly
# - Loads .env (repo), .env.local (user overrides), .env.runtime (persisted at runtime)
# - Exports everything loaded while this file runs, then restores shell export mode

set -Eeuo pipefail

# ── Guard: only run once per shell ───────────────────────────────────────────────
if [[ "${__DOTFILEZ_ENV_LOADED:-0}" -eq 1 ]]; then
  return 0 2>/dev/null || exit 0
fi
__DOTFILEZ_ENV_LOADED=1

# ── Discover repo root (DOTFILEZ_ROOT) ──────────────────────────────────────────
if [[ -n "${DOTFILEZ_ROOT:-}" && -d "$DOTFILEZ_ROOT" ]]; then
  : # honor pre-set root
else
  # Try git, then fall back to filesystem math from this file’s location
  if command -v git >/dev/null 2>&1; then
    DOTFILEZ_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")/../.." rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  if [[ -z "${DOTFILEZ_ROOT:-}" ]]; then
    # resolve ../../ from helpers/ to project root
    DOTFILEZ_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  fi
  export DOTFILEZ_ROOT
fi

# ── Auto path helpers ───────────────────────────────────────────────────────────
export DOTFILEZ_SCRIPTS_DIR="$DOTFILEZ_ROOT/scripts"
export DOTFILEZ_BIN_DIR="$DOTFILEZ_ROOT/bin"

# ── Load dotenv files in precedence order ───────────────────────────────────────
#   1) .env (checked-in, safe defaults)
#   2) .env.local (user overrides; gitignored)
#   3) .env.runtime (generated at runtime by bin/dotfilez; gitignored)
# Only simple KEY=VAL lines are honored; comments (#) and blanks ignored.
dotenv_load_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  # Temporarily turn on auto-export so sourced vars propagate
  set -a
  # shellcheck disable=SC1090
  . "$f"
  set +a
}

dotenv_load_file "$DOTFILEZ_ROOT/.env"
dotenv_load_file "$DOTFILEZ_ROOT/.env.local"
dotenv_load_file "$DOTFILEZ_ROOT/.env.runtime"

# ── Sensible defaults (only if unset) ───────────────────────────────────────────
# : "${NONINTERACTIVE:=0}"
# : "${GIT_NAME:=}"
# : "${GIT_EMAIL:=}"
# : "${GITHUB_TOKEN:=}"

# export NONINTERACTIVE GIT_NAME GIT_EMAIL GITHUB_TOKEN

# ── (Optional) terminal styling vars used across scripts ────────────────────────
RESET="$(tput sgr0 2>/dev/null || true)"
export RESET

fg() { # minimal, avoid tput errors in non-tty contexts
  local name="${1^^}"
  case "$name" in
    BLACK)  tput setaf 0 2>/dev/null || true ;;
    RED)    tput setaf 1 2>/dev/null || true ;;
    GREEN)  tput setaf 2 2>/dev/null || true ;;
    YELLOW) tput setaf 3 2>/dev/null || true ;;
    BLUE)   tput setaf 4 2>/dev/null || true ;;
    MAGENTA|MAUVE) tput setaf 5 2>/dev/null || true ;;
    CYAN|PEACH)    tput setaf 6 2>/dev/null || true ;;
    WHITE)  tput setaf 7 2>/dev/null || true ;;
  esac
}
export -f fg

# ── (Optional) Logging ────────────────────────
# Logging functions
info() { printf '%s[+] %s%s\n' "$(fg GREEN)" "$*" "$RESET"; }
warn() { printf '%s[!] %s%s\n' "$(fg YELLOW)" "$*" "$RESET" >&2; }
err()  { printf '%s[✗] %s%s\n' "$(fg RED)" "$*" "$RESET" >&2; }
die()  { err "$*"; exit 1; }
is_tty() { [[ -t 0 ]]; }

export -f info
export -f warn
export -f err
export -f die
export -f is_tty

# ── (Optional) Visual divider ────────────────────────
divider() { printf '%s\n' "───────────────────────────────────────────────"; }
export -f divider

# ── Check for command ────────────────────────
# Check if a command exists
# Usage: if have_cmd git; then echo "Git is installed"; fi  
have_cmd()   { command -v "$1" >/dev/null 2>&1; }
export -f have_cmd

# ── Source privilege helpers ────────────────────────────────────────────────
# Idempotent privilege helpers. Source in every script.
# shellcheck shell=bash
set -o errexit -o pipefail -o nounset

# Runs a command with sudo if not root; otherwise runs directly.
# Usage: _sudo apt-get update
_sudo() { if [[ ${EUID:-$(id -u)} -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

# Require the script to be run as root (useful for certain installers).
need_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "This script must run as root. Try: sudo $0 $*" >&2
    exit 1
  fi
}

# Require the script to be run as a non-root user (useful for dev workflows).
need_non_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    echo "Do not run this as root. Re-run as a regular user." >&2
    exit 1
  fi
}

# Optional: forbid direct sudo in scripts that source this file.
# Opt in by setting FORBID_DIRECT_SUDO=1 before sourcing (or in the environment).
if [[ "${FORBID_DIRECT_SUDO:-0}" == "1" ]]; then
  # Allow aliases in non-interactive shells
  shopt -s expand_aliases || true
  _no_direct_sudo() {
    echo "Use _sudo … instead of calling sudo directly." >&2
    exit 2
  }
  alias sudo='_no_direct_sudo'
fi

export -f _sudo need_root need_non_root _sudo