#!/usr/bin/env bash


# # ---------------- Get sources Start ----------------
# # DOTS="${DOTS:-$HOME/dotfilez}"
# if [ -n "$SUDO_USER" ]; then
#   # Safest: query the account database
#   user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
#   # or quick-and-handy:
#   # user_home="$(eval echo "~$SUDO_USER")"
# else
#   user_home="$HOME"
# fi
# echo "$user_home"


# DOTS="$user_home/dotfilez"
# echo "[postdeploy] Using DOTS=$DOTS"
# ---------------- Get sources Start ----------------
# Resolve project root if DOTS isn't set
DOTS="${DOTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Load helper libraries (logging, divider, have_cmd, _sudo, etc.)
# shellcheck disable=SC1091
source "$DOTS/scripts/helpers/common.sh"
# shellcheck disable=SC1091
source "$DOTS/scripts/helpers/pkg.sh"
# ---------------- Get sources End ------------------

set -euo pipefail

echo "[postdeploy] placeholder – post-deploy tasks"

# ── Make Executable ────────────────────────────────────────────────────────────────────

# Customize this function to run any post-clone scripts or actions.
# By default, it looks for a create_user.sh script in the cloned repo and runs it if found.
# Usage: post_clone_actions
# Note: Skips interactive steps if no TTY is available.
make_executable() {
  info "Post-clone actions section (customise as needed)."
  if ! is_tty; then warn "No TTY; skipping interactive post-clone steps."; return 0; fi
  if [[ -x "$DOTFILEZ_ROOT/scripts/make-executable.sh" ]]; then
    divider
    warn "About to run: $DOTFILEZ_ROOT/scripts/make-executable.sh (press Enter to continue or Ctrl+C to skip)"; read -r _ || true
    _sudo $DOTS/scripts/make-executable.sh "$DOTS"
    _sudo $DOTS/scripts//make-executable.sh "$DOTS/bin/dotfilez"

    
  else
    warn "No create_user.sh found at $DOTS; skipping user creation step."
  fi
}

# ── Ansible Installation ────────────────────────────────────────────────────────────────────
# Installs Ansible + common Galaxy collections (incl. Proxmox).
# Uses _sudo helper from dotfilez/scripts/helpers/privilege.sh
install_ansible_galaxy_collections() {
  set -euo pipefail

  # ---- helpers ---------------------------------------------------------------
    ensure_pipx() {
    if ! have_cmd pipx; then
      if have_cmd python3 -o -x /usr/bin/python3; then
        pkg_install python3-pip || true
        _sudo python3 -m pip install --user --upgrade pipx
        # Ensure ~/.local/bin on PATH for current session
        export PATH="$HOME/.local/bin:$PATH"
      else
        pkg_install python3 python3-pip
        _sudo python3 -m pip install --user --upgrade pipx
        export PATH="$HOME/.local/bin:$PATH"
      fi
    fi
  }

  ensure_ansible() {
    if have_cmd ansible-galaxy && have_cmd ansible; then
      return
    fi
    if have_cmd pipx; then
      _sudo pipx install --include-deps ansible-core || true
      # On some distros ansible CLI meta-package is handy:
      _sudo pipx install ansible || true
    else
      # OS package fallback
      if have_cmd apt-get; then
        pkg_install software-properties-common || true
        pkg_install ansible
      else
        pkg_install ansible || true
      fi
    fi
  }

  ensure_proxmox_python_deps() {
    # Proxmox modules commonly need proxmoxer + requests
    if have_cmd pipx; then
      # Install into the ansible venv if present, else into a dedicated one
      if pipx list | grep -qE 'package +ansible(\b|-core\b)'; then
        _sudo pipx runpip ansible install --upgrade proxmoxer requests
      elif pipx list | grep -q 'ansible-core'; then
        _sudo pipx runpip ansible-core install --upgrade proxmoxer requests
      else
        _sudo pipx install proxmoxer || true
        p_sudo ipx inject proxmoxer requests || true
      fi
    else
      _sudo python3 -m pip install --user --upgrade proxmoxer requests
    fi
  }

  # ---- main -----------------------------------------------------------------
  ensure_pipx
  ensure_ansible
  ensure_proxmox_python_deps

  # Generate a requirements.yml next to where you run this (idempotent).
  local req="requirements.yml"
  cat > "$req" <<'YAML'
---
collections:
  # Core & utils
  - name: ansible.posix
  - name: ansible.utils
  - name: community.general
  - name: community.crypto

  # OS/ecosystem
  - name: community.docker
  - name: community.mysql
  - name: community.postgresql
  - name: community.grafana
  - name: community.kubernetes
  - name: community.libvirt
  - name: community.have_cmdhi_vault
  - name: community.mongodb
  - name: community.windows        # safe to include; only used on Windows hosts

  # Proxmox support:
  # Most Proxmox modules live in community.general (e.g., proxmox_kvm).
  # We install proxmoxer Python deps separately above.
YAML

  # Install/update collections (idempotent)
  if have_cmd ansible-galaxy; then
    _sudo ansible-galaxy collection install -r "$req" --upgrade
  else
    echo "ansible-galaxy not found in PATH; ensure your shell PATH includes pipx shims (e.g., \$HOME/.local/bin)." >&2
    return 1
  fi

  echo "✔ Ansible and common Galaxy collections installed (incl. Proxmox support)."
}



# ── Main (user-mode) ────────────────────────────────────────────────────────────────────
PKG_WANTS=(fzf zenity dialog tree)

main_user_mode() {
  divider
  # Install any user-mode packages first
  make_executable

  divider
  # Install packages
  info "Installing packages: ${PKG_WANTS[*]}..."
  pkg_install "${PKG_WANTS[@]}"

  divider
  # install Ansible + common Galaxy collections (incl. Proxmox)
  install_ansible_galaxy_collections
  
}

 

# ── CLI Args & Entrypoint ────────────────────────────────────────────────────────────────────
# Parse --as-user and --non-interactive flags
AS_USER_FLAG=""; for a in "$@"; do case "$a" in --as-user) AS_USER_FLAG="--as-user";; --non-interactive) NON_INTERACTIVE=true;; esac; done

# Now running as non-root user; proceed with main user-mode logic
main_user_mode

# End of script