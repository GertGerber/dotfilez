# Scaffolding the repository

Create the expected directory layout and starter files.

## Quick commands

- Preview (no writes):
  ```bash
  make scaffold-dry-run
  ```

- Create missing files at the repo root:
  ```bash
  make scaffold
  ```

- Overwrite conflicting files:
  ```bash
  make scaffold-force
  ```

- Scaffold into a different folder (supports ~):
  ```bash
  make scaffold ROOT_DIR=~/Github/project1
  make scaffold-dry-run ROOT_DIR=~/Github/project1
  make scaffold-force ROOT_DIR=~/Github/project1

  ```

The scaffolder is scripts/init_project_structure.sh. It accepts --root <path>, plus --dry-run and --force.


---

### How to add to your existing project

1) Copy the three files above into your repo:
- `scripts/init_project_structure.sh` (make it executable)
- `mk/scaffold.mk`
- `docs/scaffolding.md`

2) In your existing `Makefile`, add:
  - include mk/scaffold.mk

    You’re set. Now you can run:
    - `make scaffold`
    - `make scaffold ROOT_DIR=~/Github/project1`
    - `make scaffold-dry-run` / `make scaffold-force`


