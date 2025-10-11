#!/usr/bin/env bash


# ---------------- Variables Start ----------------
# shellcheck source=../scripts/helpers/env.sh
. "${DOTFILEZ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/scripts/helpers/env.sh"
# ---------------- Variables Start ------------------

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
    _sudo $DOTFILEZ_ROOT/scripts/make-executable.sh "$DOTFILEZ_ROOT"
    _sudo $DOTFILEZ_ROOT/scripts//make-executable.sh "$DOTFILEZ_ROOT/bin/dotfilez"

    
  else
    warn "No create_user.sh found at $DOTFILEZ_ROOT; skipping user creation step."
  fi
}

# ── Ansible Installation ────────────────────────────────────────────────────────────────────
# Installs Ansible + common Galaxy collections (incl. Proxmox).
# Uses _sudo helper from dotfilez/scripts/helpers/privilege.sh
install_ansible_galaxy_collections() {
  set -euo pipefail

  # ---- helpers ---------------------------------------------------------------
  has() { command -v "$1" >/dev/null 2>&1; }

  pkg_install() {
    if has apt-get; then
      _sudo apt-get update -y
      _sudo apt-get install -y --no-install-recommends "$@"
    elif has dnf; then
      _sudo dnf install -y "$@"
    elif has yum; then
      _sudo yum install -y "$@"
    elif has pacman; then
      _sudo pacman -Sy --noconfirm "$@"
    elif has apk; then
      _sudo apk add --no-cache "$@"
    else
      echo "Unsupported package manager. Install these manually: python3, pipx (or pip), git, ansible" >&2
    fi
  }

  ensure_pipx() {
    if ! has pipx; then
      if has python3 -o -x /usr/bin/python3; then
        pkg_install python3-pip || true
        python3 -m pip install --user --upgrade pipx
        # Ensure ~/.local/bin on PATH for current session
        export PATH="$HOME/.local/bin:$PATH"
      else
        pkg_install python3 python3-pip
        python3 -m pip install --user --upgrade pipx
        export PATH="$HOME/.local/bin:$PATH"
      fi
    fi
  }

  ensure_ansible() {
    if has ansible-galaxy && has ansible; then
      return
    fi
    if has pipx; then
      pipx install --include-deps ansible-core || true
      # On some distros ansible CLI meta-package is handy:
      pipx install ansible || true
    else
      # OS package fallback
      if has apt-get; then
        pkg_install software-properties-common || true
        pkg_install ansible
      else
        pkg_install ansible || true
      fi
    fi
  }

  ensure_proxmox_python_deps() {
    # Proxmox modules commonly need proxmoxer + requests
    if has pipx; then
      # Install into the ansible venv if present, else into a dedicated one
      if pipx list | grep -qE 'package +ansible(\b|-core\b)'; then
        pipx runpip ansible install --upgrade proxmoxer requests
      elif pipx list | grep -q 'ansible-core'; then
        pipx runpip ansible-core install --upgrade proxmoxer requests
      else
        pipx install proxmoxer || true
        pipx inject proxmoxer requests || true
      fi
    else
      python3 -m pip install --user --upgrade proxmoxer requests
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
  - name: community.hashi_vault
  - name: community.mongodb
  - name: community.windows        # safe to include; only used on Windows hosts

  # Proxmox support:
  # Most Proxmox modules live in community.general (e.g., proxmox_kvm).
  # We install proxmoxer Python deps separately above.
YAML

  # Install/update collections (idempotent)
  if has ansible-galaxy; then
    ansible-galaxy collection install -r "$req" --upgrade
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