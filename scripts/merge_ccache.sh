#!/bin/bash
set -e

CCACHE_ASSET="$1"
PARTS_DIR="${2:-ccache-parts}"
CCACHE_TAG="ccache-store"
CCACHE_REPO="${GITHUB_REPOSITORY}"

if [ -z "$CCACHE_ASSET" ]; then
  echo "[!] Usage: merge_ccache.sh <asset-name> [parts-dir]"
  exit 1
fi

MERGE_ROOT="$(mktemp -d)"
MERGE_DIR="${MERGE_ROOT}/.ccache"
mkdir -p "$MERGE_DIR"

FOUND_ANY=0
while IFS= read -r tarball; do
  FOUND_ANY=1
  echo "[+] Merging part: $tarball"
  EXTRACT_DIR="$(mktemp -d)"
  tar --use-compress-program=unzstd -xf "$tarball" -C "$EXTRACT_DIR"
  rsync -a --ignore-existing "$EXTRACT_DIR/.ccache/" "$MERGE_DIR/"
  rm -rf "$EXTRACT_DIR"
done < <(find "$PARTS_DIR" -name '*.tar.zst' 2>/dev/null)

if [ "$FOUND_ANY" == "0" ]; then
  echo "[!] No ccache parts found in ${PARTS_DIR} — every build likely failed before it could save. Skipping publish."
  exit 0
fi

TAR_PATH="/tmp/${CCACHE_ASSET}"
tar --use-compress-program=zstdmt -cf "$TAR_PATH" -C "$MERGE_ROOT" .ccache

SIZE_MB=$(du -m "$TAR_PATH" | cut -f1)
PART_COUNT=$(find "$PARTS_DIR" -name '*.tar.zst' | wc -l)
echo "[+] Merged ccache archive: ${SIZE_MB} MB (from ${PART_COUNT} parts)"
if [ "$SIZE_MB" -gt 1900 ]; then
  echo "::warning::ccache archive is approaching the 2GB release asset limit (${SIZE_MB} MB)"
fi

if ! timeout 60 gh release view "$CCACHE_TAG" -R "$CCACHE_REPO" >/dev/null 2>&1; then
  echo "[+] Release tag ${CCACHE_TAG} doesn't exist yet, creating..."
  timeout 60 gh release create "$CCACHE_TAG" -R "$CCACHE_REPO" \
    --title "ccache storage (do not delete)" \
    --notes "Persistent ccache storage per clang-variant+LTO mode. Auto-managed by CI." \
    --latest=false
fi

UPLOAD_OK=0
for attempt in 1 2 3; do
  if timeout 600 gh release upload "$CCACHE_TAG" "$TAR_PATH" -R "$CCACHE_REPO" --clobber; then
    UPLOAD_OK=1
    break
  fi
  echo "[!] Upload attempt ${attempt} failed/timed out, retrying in 15s..."
  sleep 15
done

if [ "$UPLOAD_OK" == "0" ]; then
  echo "[!] Failed to upload ccache after 3 attempts, giving up (kernel build itself already succeeded)."
  rm -f "$TAR_PATH"
  exit 0
fi

echo "[+] Merged ccache uploaded as ${CCACHE_ASSET} — the only writer, no race."
rm -f "$TAR_PATH"
