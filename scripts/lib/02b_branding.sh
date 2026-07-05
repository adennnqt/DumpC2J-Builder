#!/bin/bash
set -e

# Nyuntik nama custom ke KSU_VERSION_FULL, aman di-skip kalau Makefile-nya
# gak ada/gak match pattern (misal VARIANT=stock atau ROOT=none).
if [ -n "$MODULES_DIR" ] && [ -n "$REPO_NAME" ] && [ -f "$MODULES_DIR/$REPO_NAME/kernel/Makefile" ]; then
  echo "[+] Applying custom kernel branding..."
  python3 "${GITHUB_WORKSPACE}/scripts/branding.py" "$MODULES_DIR/$REPO_NAME/kernel/Makefile" "DumpC2J"
fi
