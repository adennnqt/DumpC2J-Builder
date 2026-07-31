#!/bin/bash
set -e

if [ -z "${CCACHE_ASSET:-}" ] || [ ! -d "${GITHUB_WORKSPACE}/.ccache" ]; then
  echo "[!] ccache was never set up this run (an earlier step likely failed first) — nothing to save, skipping."
  exit 0
fi

echo "[+] ccache stats after build:"
ccache -s -v

CCACHE_OUT_DIR="${GITHUB_WORKSPACE}/ccache-out"
mkdir -p "$CCACHE_OUT_DIR"
TAR_PATH="${CCACHE_OUT_DIR}/${CCACHE_ASSET}"
tar --use-compress-program=zstdmt -cf "$TAR_PATH" -C "${GITHUB_WORKSPACE}" .ccache

SIZE_MB=$(du -m "$TAR_PATH" | cut -f1)
echo "[+] Local ccache part size: ${SIZE_MB} MB"

echo "CCACHE_TAR_PATH=${TAR_PATH}" >> "$GITHUB_ENV"
echo "CCACHE_OUT_DIR=${CCACHE_OUT_DIR}" >> "$GITHUB_ENV"
echo "[+] ccache part siap di ${TAR_PATH} — publish langsung (single build) atau lewat job merge_ccache (matrix build)."
