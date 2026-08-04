#!/bin/bash
set -e

[ "$VARIANT" == "stock" ] && ROOT="none"
echo "ACTUAL_ROOT=$ROOT" >> "$GITHUB_ENV"

LTO_VAL="${INPUT_LTO:-full}"
echo "LTO_ACTUAL=$LTO_VAL" >> "$GITHUB_ENV"


cd "$KERNEL_DIR"

echo "[*] Applying kernel name: $KERNEL_NAME"
if [ -n "$KERNEL_NAME" ]; then
  KERNEL_NAME_ESCAPED=$(printf '%s' "$KERNEL_NAME" | sed -e 's/[\/&]/\\&/g')
  sed -i "s/CONFIG_LOCALVERSION=\".*\"/CONFIG_LOCALVERSION=\"$KERNEL_NAME_ESCAPED\"/g" \
    arch/arm64/configs/konoha_defconfig
  grep -qF "CONFIG_LOCALVERSION=\"$KERNEL_NAME\"" arch/arm64/configs/konoha_defconfig \
    || { echo "[-] sed gagal set CONFIG_LOCALVERSION — pattern gak ketemu di konoha_defconfig, cek struktur defconfig"; exit 1; }
fi

if [ "$SPOOF_UNAME" == "on" ]; then
  sed -i "s/# CONFIG_KSU_SUSFS_SPOOF_UNAME is not set/CONFIG_KSU_SUSFS_SPOOF_UNAME=y/g" \
    arch/arm64/configs/konoha_defconfig
  grep -qF "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" arch/arm64/configs/konoha_defconfig \
    || { echo "[-] sed gagal enable CONFIG_KSU_SUSFS_SPOOF_UNAME — pattern gak ketemu, cek struktur defconfig"; exit 1; }
elif [ "$SPOOF_UNAME" == "off" ]; then
  sed -i "s/CONFIG_KSU_SUSFS_SPOOF_UNAME=y/# CONFIG_KSU_SUSFS_SPOOF_UNAME is not set/g" \
    arch/arm64/configs/konoha_defconfig
  grep -qF "# CONFIG_KSU_SUSFS_SPOOF_UNAME is not set" arch/arm64/configs/konoha_defconfig \
    || { echo "[-] sed gagal disable CONFIG_KSU_SUSFS_SPOOF_UNAME — pattern gak ketemu, cek struktur defconfig"; exit 1; }
fi
