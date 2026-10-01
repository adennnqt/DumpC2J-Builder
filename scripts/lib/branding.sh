#!/bin/bash
set -e

if [ -n "$MODULES_DIR" ] && [ -n "$REPO_NAME" ] && [ -d "$MODULES_DIR/$REPO_NAME/kernel" ]; then
  if [ "$ROOT" = "sukisu" ]; then
    echo "[+] Skipping branding for SukiSU (Makefile handles versioning via GitHub API)"
  else
    echo "[+] Applying custom kernel branding..."
    python3 "${BUILDER_DIR}/scripts/branding.py" "$MODULES_DIR/$REPO_NAME/kernel" "DumpC2J"
  fi
fi