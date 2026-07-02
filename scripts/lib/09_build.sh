#!/bin/bash
set -e

# ==========================================
# Build
# ==========================================
CPUS=$(nproc --all)
echo "[+] Building with ${CPUS} threads..."

make -C "$KERNEL_DIR" \
  "-j${CPUS}" O="$OUT_DIR" \
  CC="${CC_LAUNCHER:+$CC_LAUNCHER }clang" \
  HOSTCC="${CC_LAUNCHER:+$CC_LAUNCHER }gcc" \
  HOSTCXX="${CC_LAUNCHER:+$CC_LAUNCHER }g++" \
  LD=ld.lld AR=llvm-ar NM=llvm-nm \
  OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
  LLVM=1 LLVM_IAS=1 \
  KCFLAGS="$KERNEL_KCFLAGS" LDFLAGS="$KERNEL_LDFLAGS" \
  || { echo "[-] Build failed!"; exit 1; }

echo "[+] ccache stats after build:"
ccache -s
