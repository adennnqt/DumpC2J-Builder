#!/bin/bash
set -e

if [ "${KASUMI:-off}" != "on" ]; then
  exit 0
fi

KASUMI_SRC_DIR="${GITHUB_WORKSPACE}/kasumi"
KASUMI_REPO="https://github.com/Anatdx/Kasumi.git"

if [ ! -d "$KASUMI_SRC_DIR/.git" ]; then
  rm -rf "$KASUMI_SRC_DIR"
  git clone --depth=1 "$KASUMI_REPO" "$KASUMI_SRC_DIR"
fi

if [ ! -d "$KASUMI_SRC_DIR/src" ]; then
  echo "[-] Kasumi: src/ not found after clone — upstream layout may have changed."
  return 1
fi

echo "[+] Building Kasumi LKM (kasumi_lkm.ko)..."
make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 \
  M="$KASUMI_SRC_DIR/src" modules || { echo "[-] Kasumi module build failed!"; return 1; }

KASUMI_KO=$(find "$KASUMI_SRC_DIR/src" -name "*.ko" | head -1)
if [ -z "$KASUMI_KO" ]; then
  echo "[-] Kasumi: build succeeded but no .ko file found under $KASUMI_SRC_DIR/src"
  return 1
fi

cp "$KASUMI_KO" "${GITHUB_WORKSPACE}/kasumi_lkm.ko"
export KASUMI_KO_PATH="${GITHUB_WORKSPACE}/kasumi_lkm.ko"
echo "KASUMI_KO_PATH=${KASUMI_KO_PATH}" >> "$GITHUB_ENV"
echo "[+] Kasumi LKM built: $(basename "$KASUMI_KO")"
