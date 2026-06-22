#!/usr/bin/env bash
set -e

KERNEL_VERSION_SPOOF="${1:-}"
KERNEL_DIR="${GITHUB_WORKSPACE}/kernel-source"
OUT_DIR="${KERNEL_DIR}/out"
CLANG_BIN="${CLANG_PATH}"

# Konfigurasi
ARCH=arm64
DEFCONFIG=gki_defconfig
CROSS_COMPILE=aarch64-linux-gnu-
CROSS_COMPILE_COMPAT=arm-linux-gnueabi-

# Hostname spoof
export KBUILD_BUILD_USER="adennnqt"
export KBUILD_BUILD_HOST="DumpC2J"

MAKE_FLAGS=(
  -C "${KERNEL_DIR}"
  O="${OUT_DIR}"
  ARCH=${ARCH}
  CC="${CLANG_BIN}/clang"
  CROSS_COMPILE=${CROSS_COMPILE}
  CROSS_COMPILE_COMPAT=${CROSS_COMPILE_COMPAT}
  LD="${CLANG_BIN}/ld.lld"
  AR="${CLANG_BIN}/llvm-ar"
  NM="${CLANG_BIN}/llvm-nm"
  OBJCOPY="${CLANG_BIN}/llvm-objcopy"
  OBJDUMP="${CLANG_BIN}/llvm-objdump"
  READELF="${CLANG_BIN}/llvm-readelf"
  STRIP="${CLANG_BIN}/llvm-strip"
  -j$(nproc --all)
)

echo "[*] Building with: ${CLANG_BIN}/clang"
echo "[*] Jobs: $(nproc --all)"

# defconfig
make "${MAKE_FLAGS[@]}" ${DEFCONFIG}

# Disable VDSO32 & COMPAT_VDSO (wajib untuk Cirrus)
scripts/config --file "${OUT_DIR}/.config" \
  -d CONFIG_VDSO32 \
  -d CONFIG_COMPAT_VDSO

# Kernel version spoof
if [[ -n "${KERNEL_VERSION_SPOOF}" ]]; then
  echo "[*] Spoofing kernel version: ${KERNEL_VERSION_SPOOF}"
  sed -i "s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-${KERNEL_VERSION_SPOOF}\"/" \
    "${OUT_DIR}/.config"
  echo "CONFIG_LOCALVERSION_AUTO=n" >> "${OUT_DIR}/.config"
fi

make "${MAKE_FLAGS[@]}" olddefconfig

# Build
echo "[*] Starting kernel build..."
make "${MAKE_FLAGS[@]}" Image 2>&1 | tee build.log

echo "[+] Build complete!"
ls -lh "${OUT_DIR}/arch/arm64/boot/Image"
