# dotfilez
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/GertGerber/dotfilez/main/bin/dotfilez)"
```

```bash
# As root in a fresh Debian/Ubuntu LXC
bash proxmox-infra-installer.sh
```

```bash
# Or non-interactive, preseeded
export USERNAME=gert GIT_NAME="Gert Gerber" GIT_EMAIL="gert@example.com" GITHUB_TOKEN=ghp_...
bash proxmox-infra-installer.sh --non-interactive
```



## init_project_structure.sh
No worries — that error means your Makefile doesn’t have the scaffold-force target (likely the mk/scaffold.mk include wasn’t added or the file path is wrong). Here’s how to fix it fast.

Quick fix (pick one)
A) Add targets directly to your Makefile

Paste this at the bottom of your existing Makefile (make sure the command lines start with a tab):

```bash
# ---- Scaffolding -------------------------------------------------------------
SCAFFOLDER := scripts/init_project_structure.sh
ROOT_DIR   ?= .

.PHONY: scaffold scaffold-dry-run scaffold-force
scaffold: ## Create missing folders/files for the repo layout (idempotent)
	@[ -x "$(SCAFFOLDER)" ] || { echo "Missing or non-executable: $(SCAFFOLDER)"; exit 1; }
	@$(SCAFFOLDER) --root "$(ROOT_DIR)"

scaffold-dry-run: ## Show what would be created/changed (no writes)
	@[ -x "$(SCAFFOLDER)" ] || { echo "Missing or non-executable: $(SCAFFOLDER)"; exit 1; }
	@$(SCAFFOLDER) --root "$(ROOT_DIR)" --dry-run

scaffold-force: ## Create folders/files and overwrite any conflicting files
	@[ -x "$(SCAFFOLDER)" ] || { echo "Missing or non-executable: $(SCAFFOLDER)"; exit 1; }
	@$(SCAFFOLDER) --root "$(ROOT_DIR)" --force
```

B) Or, include the separate file

1. Ensure mk/scaffold.mk exists with the same content as above.
2. Add this line to your existing Makefile (top or bottom is fine):
```bash
-include mk/scaffold.mk
```
Sanity checks
1. Script exists & is executable:
```bash
test -x scripts/init_project_structure.sh || chmod +x scripts/init_project_structure.sh
```

2. You’re in the repo root (where the Makefile is):
```bash
ls Makefile scripts/init_project_structure.sh
```

3. Try the target:
```bash
make scaffold-force ROOT_DIR=~/Github/project1
```

Fallback (bypass make)

You can always run the script directly:
```bash
scripts/init_project_structure.sh --root ~/Github/project1 --force
```

If it still fails, paste your Makefile (or run make -pn | grep -A1 '^scaffold') and I’ll spot what’s missing.