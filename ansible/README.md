# Ansible Roles: SSH Bootstrap, Proxmox API Bootstrap, System Upgrade

Generated: 2025-10-11T22:58:09.612117Z

## Inventory

Edit `inventories/production/hosts.ini`:

```
[proxmox]
proxmox ansible_host=192.168.88.250

[network]
# add network devices here, e.g. router ansible_host=192.168.88.1

[developer]
# add developer machines here, e.g. dev-laptop ansible_host=192.168.88.101

[targets:children]
network
developer

# ALL is implicit in Ansible. Use 'all' to match every host.
```

## Secrets

Local secrets are stored in `secrets/` (git-ignored). The Proxmox API token will be written to `secrets/proxmox_api.yml` by the Proxmox role on first run if missing.

## Playbooks

1. **SSH Bootstrap** (controller SSH + target authorized keys):

```
ansible-playbook -i inventories/production/hosts.ini playbooks/01_ssh_bootstrap.yml
```

2. **Proxmox API Bootstrap** (creates role/user/token; persists token locally):

```
ansible-playbook -i inventories/production/hosts.ini playbooks/02_proxmox_api_bootstrap.yml
```

3. **Upgrade Non-Proxmox** (all hosts except `proxmox` group):

```
ansible-playbook -i inventories/production/hosts.ini playbooks/03_upgrade_non_proxmox.yml -e reboot_after_upgrade=true
```

## Notes

- SSH keypair uses **ed25519** by default and will be generated at `~/.ssh/id_ed25519` on the controller.
- The Proxmox role relies on `pveum` and cluster ACLs; token secret is only visible at creation time and will be stored locally.
- Ensure Python and privilege escalation are correctly configured on your targets.
- Add future target machines to `network` or `developer` groups to include them automatically in upgrades.