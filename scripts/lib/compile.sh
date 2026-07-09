#!/bin/bash
set -e

CPUS=$(nproc --all)
echo "[+] Building with ${CPUS} threads..."

echo "[DEBUG] which clang: $(which clang)"
echo "[DEBUG] resolved clang: $(readlink -f "$(which clang)")"
echo "[DEBUG] PATH: $PATH"

make -C "$KERNEL_DIR" \
  "-j${CPUS}" O="$OUT_DIR" \
  CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm \
  OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
  LLVM=1 LLVM_IAS=1 \
  KCFLAGS="$KERNEL_KCFLAGS" LDFLAGS="$KERNEL_LDFLAGS" \
  || { echo "[-] Build failed!"; return 1; }
