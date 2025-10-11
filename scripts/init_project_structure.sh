#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Infrastructure Platform: Repository Scaffolder
# - Creates the directory tree and basic starter files (non-destructive by default)
# - Safe to rerun: only writes missing files unless --force is given
# - Usage: ./scripts/init_project_structure.sh --root . [--dry-run] [--force]
# ==============================================================================

ROOT="."
DRY_RUN=0
FORCE=0

log()  { printf "%s\n" "$*" >&2; }
ok()   { printf "✓ %s\n" "$*"; }
info() { printf "• %s\n" "$*"; }
warn() { printf "! %s\n" "$*" >&2; }
die()  { printf "✗ %s\n" "$*" >&2; exit 1; }

# Expand ~, ~user, and make absolute where possible
expand_path() {
  local p="$1"
  if [[ "$p" == "~" || "$p" == ~/* ]]; then
    p="${p/#\~/$HOME}"
  elif [[ "$p" =~ ^~[^/]+(/.*)?$ ]]; then
    local user="${p%%/*}"; user="${user#~}"
    local rest="${p#~${user}}"
    local home_dir
    home_dir="$(getent passwd "$user" | cut -d: -f6 2>/dev/null || true)"
    [[ -n "$home_dir" ]] && p="${home_dir}${rest}"
  fi
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$p"
  else
    (cd "$(dirname "$p")" 2>/dev/null && printf "%s/%s\n" "$(pwd -P)" "$(basename "$p")") 2>/dev/null || printf "%s\n" "$p"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help)
      cat <<EOF
Scaffold infra repo layout.

Usage:
  $0 --root <path> [--dry-run] [--force]

Options:
  --root      Target directory (default: .)
  --dry-run   Print actions without writing
  --force     Overwrite existing files
EOF
      exit 0
      ;;
    *) die "Unknown arg: $1" ;;
  esac
done

ROOT="$(expand_path "$ROOT")"
[[ -n "$ROOT" ]] || die "--root is required"
[[ $DRY_RUN -eq 1 ]] && info "(dry run) no changes will be written"
info "Scaffolding into: $ROOT"
mkdir -p "$ROOT"

# --- helpers ---------------------------------------------------------------

mkd() {
  local d="$ROOT/$1"
  if [[ $DRY_RUN -eq 1 ]]; then info "mkdir -p $d"; return; fi
  mkdir -p "$d"
  ok "dir  $1"
}

mkkeep() {
  local p="$ROOT/$1/.gitkeep"
  if [[ -e "$p" && $FORCE -eq 0 ]]; then return; fi
  if [[ $DRY_RUN -eq 1 ]]; then info "touch $p"; return; fi
  mkdir -p "$(dirname "$p")"
  : > "$p"
  ok "keep $1/.gitkeep"
}

write_file() {
  local rel="$1"
  local path="$ROOT/$rel"
  local mode="${2:-644}"
  shift 2
  local content="$*"

  if [[ -e "$path" && $FORCE -eq 0 ]]; then
    info "skip $rel (exists)"
    return
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    info "write $path (mode $mode)"
    return
  fi
  mkdir -p "$(dirname "$path")"
  printf "%s" "$content" > "$path"
  chmod "$mode" "$path"
  ok "file $rel"
}

sh_shebang='#!/usr/bin/env bash
set -euo pipefail
'

# --- tree ------------------------------------------------------------------

# Top-level
mkd "."
write_file "README.md" 644 "# Infrastructure Platform

This repository contains infrastructure code and tooling.

## Getting Started
- \`make help\` to see available tasks
- Edit \`.env.example\` and export variables via your secrets manager
"
write_file ".gitignore" 644 "/secrets/*
!/secrets/.gitkeep

# build & tool outputs
**/.terraform/*
**/.terragrunt-cache/*
**/.pytest_cache/*
**/__pycache__/
**/.molecule/
packer/output/
*.zip
*.log
.env
.venv/

# OS junk
.DS_Store
Thumbs.db
"
write_file ".env.example" 644 "# Non-secret examples (real secrets go in your vault)
ENV=dev
PROJECT_NAME=infra-platform
TF_VAR_region=us-east-1
ANSIBLE_STDOUT_CALLBACK=yaml
"

# (optional) Makefile is not overwritten; use mk/scaffold.mk for targets

# docs
mkd "docs/diagrams"

# ci
mkd "ci/github/workflows"
write_file "ci/github/workflows/ci.yml" 644 'name: CI
on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install -r python/requirements.txt || true
      - run: make validate
'

# bin
mkd "bin"
write_file "bin/bootstrap.sh" 755 "${sh_shebang}
echo \"[bootstrap] placeholder – wire your initial setup here\"
"
write_file "bin/validate.sh" 755 "${sh_shebang}
echo \"[validate] placeholder – call formatters, linters, and IaC checks\"
"
write_file "bin/deploy.sh" 755 "${sh_shebang}
echo \"[deploy] placeholder – orchestrate packer/terraform/ansible as needed\"
"

# scripts
mkd "scripts/helpers"
write_file "scripts/helpers/colors.sh" 644 "${sh_shebang}
RESET=\"\$(tput sgr0 2>/dev/null || true)\"
fg() { local n=\"\${1^^}\"; case \"\$n\" in
  BLACK) tput setaf 0 2>/dev/null || true;;
  RED) tput setaf 1 2>/dev/null || true;;
  GREEN) tput setaf 2 2>/dev/null || true;;
  YELLOW) tput setaf 3 2>/dev/null || true;;
  BLUE) tput setaf 4 2>/dev/null || true;;
  MAGENTA|MAUVE) tput setaf 5 2>/dev/null || true;;
  CYAN|PEACH) tput setaf 6 2>/dev/null || true;;
  WHITE) tput setaf 7 2>/dev/null || true;;
esac; }
"
write_file "scripts/preflight.sh" 755 "${sh_shebang}
echo \"[preflight] placeholder – pre-deploy checks\"
"
write_file "scripts/postdeploy.sh" 755 "${sh_shebang}
echo \"[postdeploy] placeholder – post-deploy tasks\"
"

# ansible
mkd "ansible/inventories/dev/group_vars"
mkd "ansible/inventories/dev/host_vars"
mkd "ansible/inventories/staging"
mkd "ansible/inventories/prod"
mkkeep "ansible/inventories/dev/group_vars"
mkkeep "ansible/inventories/dev/host_vars"
write_file "ansible/inventories/dev/hosts.ini" 644 "[all]
localhost ansible_connection=local
"
write_file "ansible/playbooks/site.yml" 644 "---
- hosts: all
  gather_facts: true
  roles:
    - role: common
"
write_file "ansible/playbooks/app.yml" 644 "---
- hosts: all
  gather_facts: true
  roles:
    - role: app
"
mkd "ansible/roles/common/tasks"
mkd "ansible/roles/app/tasks"
write_file "ansible/roles/common/tasks/main.yml" 644 "---
- name: Common role placeholder
  debug: msg=\"common role\"
"
write_file "ansible/roles/app/tasks/main.yml" 644 "---
- name: App role placeholder
  debug: msg=\"app role\"
"
write_file "ansible/ansible.cfg" 644 "[defaults]
stdout_callback = yaml
retry_files_enabled = False
inventory = inventories/dev/hosts.ini
"
write_file "ansible/requirements.yml" 644 "# galaxy/collection deps placeholder
collections: []
"

# terraform
mkd "terraform/modules/network"
mkd "terraform/modules/compute"
mkd "terraform/modules/storage"
write_file "terraform/modules/network/README.md" 644 "# network module\n"
write_file "terraform/modules/compute/README.md" 644 "# compute module\n"
write_file "terraform/modules/storage/README.md" 644 "# storage module\n"

mkd "terraform/envs/dev"
mkd "terraform/envs/staging"
mkd "terraform/envs/prod"

write_file "terraform/envs/dev/main.tf" 644 'terraform {
  required_version = ">= 1.5.0"
  required_providers { random = { source = "hashicorp/random" } }
}
provider "random" {}
resource "random_pet" "example" { length = 2 }
output "example" { value = random_pet.example.id }
'
write_file "terraform/envs/dev/variables.tf" 644 'variable "region" { type = string default = "us-east-1" }
'
write_file "terraform/envs/dev/outputs.tf" 644 'output "region" { value = var.region }
'
write_file "terraform/envs/dev/dev.tfvars" 644 'region = "us-east-1"
'

mkd "terraform/providers"
write_file "terraform/providers/providers.tf" 644 'terraform {
  required_providers { random = { source = "hashicorp/random" } }
}
'

mkd "terraform/policies"
mkd "terraform/backend"
write_file "terraform/backend/state-bootstrap.tf" 644 '# configure remote state backend here (no secrets)
'

# packer
mkd "packer/templates"
mkd "packer/variables"
mkd "packer/provisioners/linux"
mkd "packer/provisioners/windows"
mkd "packer/output"
write_file "packer/templates/base-image.pkr.hcl" 644 'packer {
  required_plugins { null = { version = ">= 1.0.0", source = "github.com/hashicorp/null" } }
}
source "null" "example" {}
build {
  name    = "base-image"
  sources = ["source.null.example"]
}
'
write_file "packer/templates/app-image.pkr.hcl" 644 'source "null" "example" {}
build { name = "app-image" sources = ["source.null.example"] }
'
write_file "packer/variables/dev.pkrvars.hcl" 644 'region = "us-east-1"
'
write_file "packer/provisioners/linux/install-deps.sh" 755 "${sh_shebang}
echo \"[packer] install-deps placeholder\"
"
write_file "packer/provisioners/linux/harden.sh" 755 "${sh_shebang}
echo \"[packer] harden placeholder\"
"
mkkeep "packer/output"

# python
mkd "python/src/projectname"
mkd "python/tests"
write_file "python/src/projectname/__init__.py" 644 "__all__ = []\n"
write_file "python/src/projectname/cli.py" 755 '#!/usr/bin/env python3
import sys

def main():
    print("project CLI placeholder")
    return 0

if __name__ == "__main__":
    sys.exit(main())
'
write_file "python/src/projectname/inventory_gen.py" 755 '#!/usr/bin/env python3
print("inventory generator placeholder")
'
write_file "python/requirements.txt" 644 "click\n"
write_file "python/pyproject.toml" 644 '[tool.black]
line-length = 100
'

# templates
mkd "templates"
write_file "templates/cloud-init.yaml.j2" 644 "#cloud-config
users:
  - name: {{ username | default(\"devops\") }}
    groups: [ sudo ]
    shell: /bin/bash
"

# config
mkd "config/env"
write_file "config/global.yaml" 644 "app: infra-platform
"
write_file "config/env/dev.yaml" 644 "env: dev
"
write_file "config/env/staging.yaml" 644 "env: staging
"
write_file "config/env/prod.yaml" 644 "env: prod
"

# secrets
mkd "secrets"
mkkeep "secrets"

# tests-infra
mkd "tests-infra/molecule"
mkd "tests-infra/terraform-sandboxes"

# summary
echo
ok "Scaffold complete."
[[ $DRY_RUN -eq 1 ]] && warn "Dry run mode; no files written."
