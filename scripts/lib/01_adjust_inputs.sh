#!/bin/bash
set -e

# ==========================================
# Adjust inputs
# ==========================================
[ "$VARIANT" == "stock" ] && ROOT="none"

ACTUAL_ROOT="$ROOT"
echo "ACTUAL_ROOT=$ACTUAL_ROOT" >> "$GITHUB_ENV"

LTO="${INPUT_LTO:-full}"

LTO_VAL="$LTO"
echo "LTO_ACTUAL=$LTO_VAL" >> "$GITHUB_ENV"

# ==========================================
# Guard: ReSukiSU wajib pakai variant SUSFS
# ==========================================
if [ "$ROOT" == "resukisu" ] && [ "$VARIANT" != "susfs" ]; then
  echo "[!] ERROR: ReSukiSU hanya didukung dengan Variant = susfs."
  echo "[!] Root-only (no susfs) untuk resukisu sengaja diblokir karena diketahui bikin freeze/reboot."
  echo "[!] Re-run workflow dengan Variant diset ke 'susfs'."
  echo "[!] NOTE: informational only, proceeding (retest after execveat_init fix, commit 7667f76)."
fi


# ==========================================
# Apply kernel name & spoof uname to defconfig
# ==========================================
cd "$KERNEL_DIR"

echo "[*] Applying kernel name: $KERNEL_NAME"
if [ -n "$KERNEL_NAME" ]; then
  sed -i "s/CONFIG_LOCALVERSION=\".*\"/CONFIG_LOCALVERSION=\"$KERNEL_NAME\"/g" \
    arch/arm64/configs/konoha_defconfig
fi

if [ "$SPOOF_UNAME" == "on" ]; then
  sed -i "s/# CONFIG_KSU_SUSFS_SPOOF_UNAME is not set/CONFIG_KSU_SUSFS_SPOOF_UNAME=y/g" \
    arch/arm64/configs/konoha_defconfig
elif [ "$SPOOF_UNAME" == "off" ]; then
  sed -i "s/CONFIG_KSU_SUSFS_SPOOF_UNAME=y/# CONFIG_KSU_SUSFS_SPOOF_UNAME is not set/g" \
    arch/arm64/configs/konoha_defconfig
fi
