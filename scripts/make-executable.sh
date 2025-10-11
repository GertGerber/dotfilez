#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# make-executable.sh
# - Select a folder/file via popup (fzf → zenity → dialog → readline fallback)
# - If a folder: chmod +x all *.sh files recursively
# - If a file: chmod +x just that file
# - Optional: pass a path as arg to skip the picker

# --------------- Picker logic ---------------
pick_path() {
  # 1) If a non-empty path was passed, use it
  if (( $# > 0 )) && [[ -n "${1:-}" ]]; then
    local p="$1"
    [[ -e "$p" ]] || die "Path not found: $p"
    _sudo command -v realpath >/dev/null 2>&1 \
      && _sudo realpath -m -- "$p" \
      || printf '%s' "$p"
    return 0
  fi

  # 2) fzf (TTY/terminal popup)
  if command -v fzf >/dev/null 2>&1; then
    local preview_cmd
    if command -v tree >/dev/null 2>&1; then
      preview_cmd='tree -C {} | head -200'
    else
      preview_cmd='ls -la --group-directories-first {} 2>/dev/null || file {}'
    fi
    local choice=""
    # show both files and directories from current dir downward
    choice="$(find . -mindepth 1 -maxdepth 1 -printf '%P\n' \
      | fzf --height=80% --border --prompt='Select folder or file ▶ ' \
            --preview="$preview_cmd" --preview-window=right:60%:wrap || true)"
    if [[ -n "${choice:-}" ]]; then
      command -v realpath >/dev/null 2>&1 \
        && realpath -m -- "$choice" \
        || printf '%s' "$choice"
      return 0
    fi
  fi

  # 3) zenity (GUI popup)
  if command -v zenity >/dev/null 2>&1; then
    local choice=""
    choice="$(zenity --file-selection --title='Select a folder or a file' 2>/dev/null || true)"
    if [[ -z "${choice:-}" ]]; then
      choice="$(zenity --file-selection --directory --title='Select a folder' 2>/dev/null || true)"
    fi
    [[ -n "${choice:-}" ]] && { printf '%s' "$choice"; return 0; }
  fi

  # 4) dialog (ncurses popup)
  if command -v dialog >/dev/null 2>&1; then
    local tmp out rc=0
    tmp="$(mktemp)"
    dialog --clear --title "Select a folder or file" --fselect "$PWD/" 16 60 2>"$tmp" || rc=$?
    [[ -f "$tmp" ]] && out="$(<"$tmp")"; rm -f "$tmp" || true
    if (( rc == 0 )) && [[ -n "${out:-}" ]]; then
      printf '%s' "$out"
      return 0
    fi
  fi

  # 5) Readline fallback
  local choice=""
  read -r -e -p "Path to folder or file: " choice
  [[ -n "${choice:-}" ]] || die "No selection made."
  printf '%s' "$choice"
}

# --------------- Core logic ---------------
make_exec() {
  local target="$1"
  if [[ -d "$target" ]]; then
    info "Directory selected: $target"
    mapfile -d '' files < <(find "$target" -type f -name '*.sh' -print0)
    if (( ${#files[@]} == 0 )); then
      warn "No *.sh files found under: $target"
      return 0
    fi
    printf '%s\0' "${files[@]}" | xargs -0 chmod +x
    ok "Marked ${#files[@]} shell script(s) executable."
  elif [[ -f "$target" ]]; then
    info "File selected: $target"
    _sudo chmod +x -- "$target"
    [[ "$target" == *.sh ]] || warn "File does not end with .sh; made it executable anyway."
    ok "Marked 1 file executable."
  else
    die "Selection is neither a regular file nor a directory: $target"
  fi
}

# --------------- Entry point ---------------
main() {
  local selection=""
  if ! selection="$(pick_path "$@")"; then
    # pick_path already printed a helpful error to stderr
    exit 1
  fi
  [[ -n "$selection" ]] || die "No selection received."
  make_exec "$selection"
}

main "$@"
