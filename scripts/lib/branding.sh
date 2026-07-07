#!/bin/bash
set -e

if [ -n "$MODULES_DIR" ] && [ -n "$REPO_NAME" ] && [ -f "$MODULES_DIR/$REPO_NAME/kernel/Makefile" ]; then
  echo "[+] Applying custom kernel branding..."
  python3 "${BUILDER_DIR}/scripts/branding.py" "$MODULES_DIR/$REPO_NAME/kernel/Makefile" "DumpC2J"
fi
