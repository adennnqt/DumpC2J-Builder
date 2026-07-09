#!/bin/bash
set -e

export ARCH=arm64
export SUBARCH=arm64

EXTREME_CLANG_FLAGS=(
  -O2 -mcpu=cortex-x4 -mtune=cortex-x4
  -mno-fmv -mno-outline-atomics -Wno-all
  -fomit-frame-pointer -fslp-vectorize
  -fdelete-null-pointer-checks -moutline
  -mharden-sls=none -mbranch-protection=none
  -fno-semantic-interposition -fno-stack-protector
  -fno-math-errno -fno-trapping-math
  -fno-signed-zeros -fassociative-math -freciprocal-math
)
KERNEL_KCFLAGS="-w ${EXTREME_CLANG_FLAGS[*]}"

[ "$BYPASSCHARGING" == "on" ] && KERNEL_KCFLAGS="$KERNEL_KCFLAGS -DCONFIG_MCA_BYPASS=1"
[ "$HTSR" == "on" ] && KERNEL_KCFLAGS="$KERNEL_KCFLAGS -DCONFIG_HTSR_240=1"
[ "$WIFI_EXPLOIT" == "on" ] && KERNEL_KCFLAGS="$KERNEL_KCFLAGS -DCONFIG_WIFI_EXPLOIT=1"
[ "$KGSL_EXPLOIT" == "on" ] && KERNEL_KCFLAGS="$KERNEL_KCFLAGS -DCONFIG_KGSL_EXPLOIT=1"
[ "$DATA_EXPLOIT" == "on" ] && KERNEL_KCFLAGS="$KERNEL_KCFLAGS -DCONFIG_DATA_EXPLOIT=1"

if [ "$DEBUG_MODE" == "off" ]; then
  KERNEL_KCFLAGS="$KERNEL_KCFLAGS -fmerge-all-constants"
  KERNEL_LDFLAGS="--icf=all"
else
  KERNEL_LDFLAGS=""
fi

export PATH="${GITHUB_WORKSPACE}/.ccache-shim:${CLANG_PATH}:$PATH"
CLANG_BIN="${CLANG_PATH}/clang"
if [ -z "$KBUILD_COMPILER_STRING" ]; then
  echo "[-] KBUILD_COMPILER_STRING is empty — clang setup may have failed!"
  return 1
fi
echo "[+] Using Clang: $KBUILD_COMPILER_STRING"
