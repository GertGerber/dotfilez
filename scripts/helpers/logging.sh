#!/usr/bin/env bash

# Logging functions
info() { printf '%s[+] %s%s\n' "$(fg GREEN)" "$*" "$RESET"; }
warn() { printf '%s[!] %s%s\n' "$(fg YELLOW)" "$*" "$RESET" >&2; }
err()  { printf '%s[✗] %s%s\n' "$(fg RED)" "$*" "$RESET" >&2; }
die()  { err "$*"; exit 1; }
is_tty() { [[ -t 0 ]]; }

# Error handling
trap 'err "Aborted at line $LINENO. Review logs; partial state possible."' ERR
