#!/usr/bin/env bash

# # The RESET variable ensures we can reset styles after changing them.
RESET="$(tput sgr0 || true)"

# fg sets the foreground color based on the provided color name.
# Supported colors: BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA (or MAUVE), CYAN (or PEACH), WHITE
# Usage: fg RED; echo "This is red text"; echo "$RESET"
# If the terminal does not support colors, no changes are made.
fg() {
  local name="${1^^}"
  case "$name" in
    BLACK)  tput setaf 0 2>/dev/null || true ;;
    RED)    tput setaf 1 2>/dev/null || true ;;
    GREEN)  tput setaf 2 2>/dev/null || true ;;
    YELLOW) tput setaf 3 2>/dev/null || true ;;
    BLUE)   tput setaf 4 2>/dev/null || true ;;
    MAGENTA|MAUVE) tput setaf 5 2>/dev/null || true ;;
    CYAN|PEACH)    tput setaf 6 2>/dev/null || true ;;
    WHITE)  tput setaf 7 2>/dev/null || true ;;
    *)      printf '' ;;
  esac
}