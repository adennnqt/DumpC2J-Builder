#!/bin/bash
set -e

[ "$VARIANT" == "stock" ] && ROOT="none"
echo "ACTUAL_ROOT=$ROOT" >> "$GITHUB_ENV"

# Named LTO_VAL (not LTO) because kconfig.sh consumes this exact variable name.
LTO_VAL="${INPUT_LTO:-full}"
echo "LTO_ACTUAL=$LTO_VAL" >> "$GITHUB_ENV"

if [ "$ROOT" == "resukisu" ] && [ "$VARIANT" != "susfs" ]; then
  echo "[*] ReSukiSU root-only (no susfs): status: known crash on manager app open, execveat_init fix (7667f76) did NOT fully resolve it."
fi

cd "$KERNEL_DIR"

echo "[*] Applying kernel name: $KERNEL_NAME"
if [ -n "$KERNEL_NAME" ]; then
  KERNEL_NAME_ESCAPED=$(printf '%s' "$KERNEL_NAME" | sed -e 's/[\/&]/\\&/g')
  sed -i "s/CONFIG_LOCALVERSION=\".*\"/CONFIG_LOCALVERSION=\"$KERNEL_NAME_ESCAPED\"/g" \
    arch/arm64/configs/konoha_defconfig
fi

if [ "$SPOOF_UNAME" == "on" ]; then
  sed -i "s/# CONFIG_KSU_SUSFS_SPOOF_UNAME is not set/CONFIG_KSU_SUSFS_SPOOF_UNAME=y/g" \
    arch/arm64/configs/konoha_defconfig
elif [ "$SPOOF_UNAME" == "off" ]; then
  sed -i "s/CONFIG_KSU_SUSFS_SPOOF_UNAME=y/# CONFIG_KSU_SUSFS_SPOOF_UNAME is not set/g" \
    arch/arm64/configs/konoha_defconfig
fi
