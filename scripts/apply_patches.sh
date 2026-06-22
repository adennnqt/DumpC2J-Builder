#!/usr/bin/env bash
set -e

PATCHES_INPUT="${1:-}"
KERNEL_DIR="${2:-${GITHUB_WORKSPACE}/kernel-source}"
PATCHES_DIR="${GITHUB_WORKSPACE}/patches"

if [[ -z "${PATCHES_INPUT}" ]]; then
  echo "[*] No patches to apply, skipping."
  exit 0
fi

echo "[*] Applying patches to: ${KERNEL_DIR}"

IFS=',' read -ra PATCH_LIST <<< "${PATCHES_INPUT}"

for patch in "${PATCH_LIST[@]}"; do
  patch="${patch// /}"  # trim spasi
  PATCH_FILE="${PATCHES_DIR}/${patch}"

  if [[ ! -f "${PATCH_FILE}" ]]; then
    echo "[!] Patch not found: ${PATCH_FILE}"
    exit 1
  fi

  echo "[+] Applying: ${patch}"
  git -C "${KERNEL_DIR}" apply "${PATCH_FILE}"
done

echo "[+] All patches applied successfully."
