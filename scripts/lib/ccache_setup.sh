#!/bin/bash

export CCACHE_DIR="${GITHUB_WORKSPACE}/.ccache"
export CCACHE_BASEDIR="${GITHUB_WORKSPACE}"
export CCACHE_MAXSIZE="1500M"
export CCACHE_COMPRESS="true"
export USE_CCACHE=1

echo "CCACHE_DIR=${CCACHE_DIR}" >> "$GITHUB_ENV"
echo "CCACHE_BASEDIR=${CCACHE_BASEDIR}" >> "$GITHUB_ENV"
echo "CCACHE_MAXSIZE=${CCACHE_MAXSIZE}" >> "$GITHUB_ENV"
echo "CCACHE_COMPRESS=${CCACHE_COMPRESS}" >> "$GITHUB_ENV"
echo "USE_CCACHE=${USE_CCACHE}" >> "$GITHUB_ENV"

mkdir -p "$CCACHE_DIR"

CCACHE_ASSET="ccache-${ACTUAL_ROOT}-${CLANG_VARIANT}.tar.zst"
CCACHE_TAG="ccache-store"
CCACHE_REPO="adennnqt/DumpC2J-Builder"

echo "[+] ccache asset target: ${CCACHE_ASSET}"

if gh release download "$CCACHE_TAG" \
    -p "$CCACHE_ASSET" \
    -D /tmp \
    -R "$CCACHE_REPO" \
    --clobber 2>/dev/null; then
  echo "[+] Cache ditemukan, extracting..."
  tar --use-compress-program=unzstd -xf "/tmp/${CCACHE_ASSET}" -C "${GITHUB_WORKSPACE}"
  rm -f "/tmp/${CCACHE_ASSET}"
else
  echo "[!] Belum ada cache untuk ${CCACHE_ASSET}, mulai fresh"
fi

ccache --set-config=max_size="$CCACHE_MAXSIZE"
ccache --set-config=compiler_check=content
ccache -z

CCACHE_SHIM_DIR="${GITHUB_WORKSPACE}/.ccache-shim"
mkdir -p "$CCACHE_SHIM_DIR"
CCACHE_BIN="$(command -v ccache)"

for name in clang clang++; do
  ln -sf "$CCACHE_BIN" "${CCACHE_SHIM_DIR}/${name}"
done

export PATH="${CCACHE_SHIM_DIR}:$PATH"
echo "[+] ccache shim active: $(command -v clang) -> $(readlink -f "$(command -v clang)")"

echo "CCACHE_ASSET=${CCACHE_ASSET}" >> "$GITHUB_ENV"
echo "CCACHE_TAG=${CCACHE_TAG}" >> "$GITHUB_ENV"
echo "CCACHE_REPO=${CCACHE_REPO}" >> "$GITHUB_ENV"
echo "PATH=${CCACHE_SHIM_DIR}:${PATH}" >> "$GITHUB_ENV"

echo "[+] ccache ready — dir: ${CCACHE_DIR}, compiler_check: content (static key, no run_id)"
