#!/usr/bin/env bash

set -euo pipefail

# ── Load project helpers ─────────────────────────────────────────────
# ---------------- Get sources Start ----------------
# Resolve project root if DOTS isn't set
DOTS="${DOTS:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"

# Load helper libraries (logging, divider, have_cmd, _sudo, etc.)
# shellcheck disable=SC1091
source "$DOTS/scripts/helpers/common.sh"
# shellcheck disable=SC1091
source "$DOTS/scripts/helpers/pkg.sh"
# shellcheck disable=SC1091
source "$DOTS/scripts/helpers/error_hadling.sh"
export DOTS_LOG="$HOME/.local/share/dotfilez/postdeploy.log"
# ---------------- Get sources End ------------------

echo "[postdeploy] placeholder – post-deploy tasks"

# ── Make Executable ────────────────────────────────────────────────────────────────────

# Customize this function to run any post-clone scripts or actions.
# By default, it looks for a create_user.sh script in the cloned repo and runs it if found.
# Usage: post_clone_actions
# Note: Skips interactive steps if no TTY is available.
make_executable() {
  info "Post-clone actions section (customise as needed)."
  if ! is_tty; then warn "No TTY; skipping interactive post-clone steps."; return 0; fi
  if [[ -x "$DOTS/scripts/make-executable.sh" ]]; then
    divider
    warn "About to run: $DOTS/scripts/make-executable.sh (press Enter to continue or Ctrl+C to skip)"; read -r _ || true
    $DOTS/scripts/make-executable.sh "$DOTS"
    $DOTS/scripts/make-executable.sh "$DOTS/bin/dotfilez"

    
  else
    warn "No create_user.sh found at $DOTS; skipping user creation step."
  fi
}

# ── Ansible Installation ────────────────────────────────────────────────────────────────────
# Installs Ansible + common Galaxy collections (incl. Proxmox).
# Uses _sudo helper from dotfilez/scripts/helpers/privilege.sh
install_ansible_galaxy_collections() {
  set -euo pipefail

  info "Installing Ansible and common Galaxy collections (incl. Proxmox support)…"

  ensure_pipx() {
    info "Ensuring pipx is installed…"
    if ! have_cmd pipx; then
      if have_cmd python3 || [[ -x /usr/bin/python3 ]]; then
        pkg_install python3-pip || true
        _sudo python3 -m pip install --user --upgrade pipx
        export PATH="$HOME/.local/bin:$PATH"
      else
        info "python3 not found; installing python3 + pip…"
        pkg_install python3 python3-pip
        _sudo python3 -m pip install --user --upgrade pipx
        export PATH="$HOME/.local/bin:$PATH"
      fi
    fi
  }

  ensure_ansible() {
    info "Ensuring Ansible is installed…"
    if have_cmd ansible-galaxy && have_cmd ansible; then
      return
    fi
    if have_cmd pipx; then
      info "Installing Ansible via pipx…"
      _sudo pipx install --include-deps ansible-core || true
      _sudo pipx install ansible || true
    else
      info "pipx not found; using OS package manager for Ansible…"
      if have_cmd apt-get; then
        pkg_install software-properties-common || true
        pkg_install ansible
      else
        pkg_install ansible || true
      fi
    fi
  }

  ensure_proxmox_python_deps() {
    info "Ensuring Proxmox Python deps (proxmoxer, requests)…"
    if have_cmd pipx; then
      if pipx list | grep -qE 'package +ansible(\b|-core\b)'; then
        _sudo pipx runpip ansible install --upgrade proxmoxer requests
      elif pipx list | grep -q 'ansible-core'; then
        _sudo pipx runpip ansible-core install --upgrade proxmoxer requests
      else
        _sudo pipx install proxmoxer || true
        _sudo pipx inject proxmoxer requests || true
      fi
    else
      _sudo python3 -m pip install --user --upgrade proxmoxer requests
    fi
  }

  ensure_pipx
  ensure_ansible
  ensure_proxmox_python_deps

  # Create/refresh requirements.yml (idempotent)
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
  - name: community.hashi_vault
  - name: community.mongodb
  - name: community.windows

  if have_cmd ansible-galaxy; then
    _sudo ansible-galaxy collection install -r "$req" --upgrade
  else
    die "ansible-galaxy not found in PATH; ensure \$HOME/.local/bin is in PATH (pipx shims)."
  fi

  ok "Ansible and Galaxy collections installed."
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
PKG_WANTS=(fzf zenity dialog tree python3-venv python3)

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