#!/usr/bin/env bash
# Guard: fail build kalau patch susfs4ksu gagal di file kritis
check_susfs_patch() {
  local PATCH_LOG="$1"
  local CRITICAL_FILES="kernel/core/init.c kernel/feature/kernel_umount.c kernel/supercall/supercall.c"
  local FAILED=0

  for f in $CRITICAL_FILES; do
    if awk -v file="$f" '
      $0 ~ "patching file " file {inblock=1}
      inblock && /^patching file / && $0 !~ file {inblock=0}
      inblock && /FAILED/ {print; found=1}
      END {exit !found}
    ' "$PATCH_LOG"; then
      echo "::error::SUSFS patch FAILED on critical file: $f — kernel bakal broken di runtime"
      FAILED=1
    fi
  done

  if [ "$FAILED" -eq 1 ]; then
    echo "::error::Aborting build — SUSFS patch tidak clean di file kritis, kemungkinan besar bikin bootloop"
    exit 1
  fi
}
