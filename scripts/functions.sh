#!/usr/bin/env bash
log()   { echo "[+] $*"; }
warn()  { echo "[!] $*" >&2; }
error() { echo "[-] $*" >&2; exit 1; }
run_quiet() { "$@" > /dev/null 2>&1 || true; }
