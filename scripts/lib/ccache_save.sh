#!/bin/bash
set -e

if [ -z "${CCACHE_ASSET:-}" ] || [ ! -d "${GITHUB_WORKSPACE}/.ccache" ]; then
  echo "[!] ccache was never set up this run (an earlier step likely failed first) — nothing to save, skipping."
  exit 0
fi

echo "[+] ccache stats after build:"
ccache -s -v

TAR_PATH="/tmp/${CCACHE_ASSET}"
tar --use-compress-program=zstdmt -cf "$TAR_PATH" -C "${GITHUB_WORKSPACE}" .ccache

SIZE_MB=$(du -m "$TAR_PATH" | cut -f1)
echo "[+] ccache archive size: ${SIZE_MB} MB"
if [ "$SIZE_MB" -gt 1900 ]; then
  echo "::warning::ccache archive mendekati limit 2GB release asset (${SIZE_MB} MB)"
fi

if ! gh release view "$CCACHE_TAG" -R "$CCACHE_REPO" >/dev/null 2>&1; then
  echo "[+] Release tag ${CCACHE_TAG} belum ada, membuat..."
  gh release create "$CCACHE_TAG" -R "$CCACHE_REPO" \
    --title "ccache storage (do not delete)" \
    --notes "Persistent ccache storage per clang-variant+LTO mode. Auto-managed by CI." \
    --latest=false
fi

gh release upload "$CCACHE_TAG" "$TAR_PATH" -R "$CCACHE_REPO" --clobber
echo "[+] ccache uploaded as ${CCACHE_ASSET}"
rm -f "$TAR_PATH"
