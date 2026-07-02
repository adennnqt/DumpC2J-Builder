#!/bin/bash
set -e

if [ "$LTO_VAL" == "full" ] || [ "$LTO_VAL" == "none" ]; then
  echo "[i] LTO_VAL=$LTO_VAL, skip thinlto cache save"
  return 0 2>/dev/null || exit 0
fi

if [ -z "$THINLTO_CACHE_DIR" ] || [ ! -d "$THINLTO_CACHE_DIR" ]; then
  echo "[!] THINLTO_CACHE_DIR gak ketemu/kosong, skip save"
  return 0 2>/dev/null || exit 0
fi

echo "[+] ThinLTO cache size:"
du -sh "$THINLTO_CACHE_DIR" || true

cd "$GITHUB_WORKSPACE"
tar --use-compress-program=zstd -cf "/tmp/${THINLTO_ASSET}" "$(basename "$THINLTO_CACHE_DIR")"

ARCHIVE_SIZE_MB=$(du -m "/tmp/${THINLTO_ASSET}" | cut -f1)
echo "[+] ThinLTO archive size: ${ARCHIVE_SIZE_MB} MB"

if [ "$ARCHIVE_SIZE_MB" -gt 2000 ]; then
  echo "[!] ThinLTO archive > 2000MB, skip upload (kemungkinan kena limit release asset)"
  return 0 2>/dev/null || exit 0
fi

if ! gh release view "$THINLTO_TAG" -R "$THINLTO_REPO" >/dev/null 2>&1; then
  echo "[+] Release ${THINLTO_TAG} belum ada, membuat..."
  gh release create "$THINLTO_TAG" -R "$THINLTO_REPO" --prerelease --title "$THINLTO_TAG" --notes "cache store"
fi

gh release upload "$THINLTO_TAG" "/tmp/${THINLTO_ASSET}" -R "$THINLTO_REPO" --clobber

echo "[+] ThinLTO uploaded as ${THINLTO_ASSET}"
