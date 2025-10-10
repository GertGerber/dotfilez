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
