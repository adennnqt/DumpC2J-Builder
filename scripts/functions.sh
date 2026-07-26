#!/bin/bash
log()   { echo "[+] $*"; }
warn()  { echo "[!] $*" >&2; }
error() { echo "[-] $*" >&2; exit 1; }
# Runs a command with output suppressed, ALWAYS returning success (0).
# Only use this for commands whose failure is genuinely fine to ignore.
# Do NOT use for commands whose failure must stop the caller (e.g. `git
# fetch` before a `git reset --hard` -- a swallowed fetch failure there
# means resetting onto stale/old data instead of failing loudly).
run_quiet() { "$@" > /dev/null 2>&1 || true; }
