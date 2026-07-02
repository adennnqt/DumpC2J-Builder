#!/bin/bash
set -e

# Thin LTO cache cuma relevan kalau LTO_VAL bukan full/none
if [ "$LTO_VAL" == "full" ] || [ "$LTO_VAL" == "none" ]; then
  echo "[i] LTO_VAL=$LTO_VAL, skip thinlto cache setup"
  return 0 2>/dev/null || exit 0
fi

THINLTO_CACHE_DIR="${GITHUB_WORKSPACE}/.thinlto-cache"
THINLTO_ASSET="thinlto-${ACTUAL_ROOT}-${CLANG_VARIANT}.tar.zst"
THINLTO_TAG="ccache-store"
THINLTO_REPO="adennnqt/DumpC2J-Builder"

mkdir -p "$THINLTO_CACHE_DIR"

echo "[+] thinlto asset target: ${THINLTO_ASSET}"

if gh release download "$THINLTO_TAG" \
    -p "$THINLTO_ASSET" \
    -D /tmp \
    -R "$THINLTO_REPO" \
    --clobber 2>/dev/null; then
  echo "[+] ThinLTO cache ditemukan, extracting..."
  tar --use-compress-program=unzstd -xf "/tmp/${THINLTO_ASSET}" -C "${GITHUB_WORKSPACE}"
  rm -f "/tmp/${THINLTO_ASSET}"
else
  echo "[!] Belum ada ThinLTO cache untuk ${THINLTO_ASSET}, mulai fresh"
fi

# Nempel ke LDFLAGS yang udah di-set 06_clang_flags.sh
# (aman: semua lib/*.sh disource dalam 1 proses shell yang sama)
KERNEL_LDFLAGS="$KERNEL_LDFLAGS -Wl,--thinlto-cache-dir=${THINLTO_CACHE_DIR}"

echo "THINLTO_ASSET=${THINLTO_ASSET}" >> "$GITHUB_ENV"
echo "THINLTO_TAG=${THINLTO_TAG}" >> "$GITHUB_ENV"
echo "THINLTO_REPO=${THINLTO_REPO}" >> "$GITHUB_ENV"
echo "THINLTO_CACHE_DIR=${THINLTO_CACHE_DIR}" >> "$GITHUB_ENV"

echo "[+] ThinLTO cache ready — dir: ${THINLTO_CACHE_DIR}"
