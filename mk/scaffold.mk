# ---- Scaffolding (include from your Makefile via: -include mk/scaffold.mk) --
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
