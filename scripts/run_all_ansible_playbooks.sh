# ###############################################################################
# File: run_all_ansible_playbooks.sh
# Location: dotfilez/scripts/
# Purpose: Execute all enabled Ansible playbooks in order, with explicit environment selection.
# Usage:
#   ./scripts/run_all_ansible_playbooks.sh [--environment dev|prod] [--ansible-config ansible/ansible.cfg]
#
# Notes:
# - By default, uses environment 'prod' unless overridden with --environment or ENVIRONMENT.
# - Sets ANSIBLE_CONFIG if --ansible-config is provided (recommended).
# - Looks for playbooks under ansible/playbooks/enable/*.yml and runs them in sort order.
# - A sibling directory 'ansible/playbooks/disable' is ignored.
#
# Examples:
#   ../scripts/run_all_ansible_playbooks.sh --environment dev --ansible-config ansible/ansible.cfg
#   ENVIRONMENT=dev ./scripts/lib/run-all-playbooks.sh
#
# This script aligns comments and behaviour; what you see here is what it does.
# ###############################################################################


#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT_DEFAULT="${ENVIRONMENT:-prod}"
ENVIRONMENT_VALUE="$ENVIRONMENT_DEFAULT"
ANSIBLE_CONFIG_PATH="${ANSIBLE_CONFIG:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment|-e)
      shift
      ENVIRONMENT_VALUE="${1:-}"
      if [[ -z "${ENVIRONMENT_VALUE}" ]]; then
        echo "ERROR: --environment requires a value (dev|prod)" >&2
        exit 2
      fi
      ;;
    --ansible-config|-c)
      shift
      ANSIBLE_CONFIG_PATH="${1:-}"
      if [[ -z "${ANSIBLE_CONFIG_PATH}" ]]; then
        echo "ERROR: --ansible-config requires a path" >&2
        exit 2
      fi
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

# Export environment for ansible.cfg templating or inventory lookups
export ENVIRONMENT="${ENVIRONMENT_VALUE}"

# If an ansible config is passed, export it
if [[ -n "${ANSIBLE_CONFIG_PATH}" ]]; then
  export ANSIBLE_CONFIG="${ANSIBLE_CONFIG_PATH}"
fi

# Resolve repo root as script directory up two levels
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PLAYBOOK_DIR="${REPO_ROOT}/ansible/playbooks/enable"
INVENTORY_PATH="${REPO_ROOT}/ansible/inventories/hosts/${ENVIRONMENT}/hosts.yml"

if [[ ! -f "${INVENTORY_PATH}" ]]; then
  echo "ERROR: Inventory not found for environment '${ENVIRONMENT}': ${INVENTORY_PATH}" >&2
  exit 3
fi

if [[ ! -d "${PLAYBOOK_DIR}" ]]; then
  echo "ERROR: Playbook directory not found: ${PLAYBOOK_DIR}" >&2
  exit 3
fi

echo "INFO: Using environment: ${ENVIRONMENT}"
echo "INFO: Inventory: ${INVENTORY_PATH}"
if [[ -n "${ANSIBLE_CONFIG:-}" ]]; then
  echo "INFO: ANSIBLE_CONFIG: ${ANSIBLE_CONFIG}"
fi

# Execute playbooks in lexical order
shopt -s nullglob
PLAYBOOKS=( "${PLAYBOOK_DIR}"/*.yml "${PLAYBOOK_DIR}"/*.yaml )
if [[ ${#PLAYBOOKS[@]} -eq 0 ]]; then
  echo "WARN: No playbooks found in ${PLAYBOOK_DIR}" >&2
  exit 0
fi

for pb in "${PLAYBOOKS[@]}"; do
  echo "---- Running ${pb} ----"
  ansible-playbook -i "${INVENTORY_PATH}" "${pb}"
done

echo "All playbooks executed successfully."