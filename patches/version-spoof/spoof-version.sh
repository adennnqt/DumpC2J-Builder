#!/bin/bash
# Usage: ./spoof-version.sh <kernel_dir> <spoof_version>
# Contoh: ./spoof-version.sh ../DumpC2J-Kernel 6.6.66
#         ./spoof-version.sh ../DumpC2J-Kernel custom

KERNEL_DIR="$1"
SPOOF_VER="$2"

if [ -z "$KERNEL_DIR" ] || [ -z "$SPOOF_VER" ]; then
  echo "Usage: $0 <kernel_dir> <version e.g. 6.6.66>"
  exit 1
fi

if [ "$SPOOF_VER" == "none" ]; then
  echo ">> No version spoof applied."
  exit 0
fi

IFS='.' read -r V P S <<< "$SPOOF_VER"

MAKEFILE="$KERNEL_DIR/Makefile"

sed -i "s/^VERSION = .*/VERSION = $V/" "$MAKEFILE"
sed -i "s/^PATCHLEVEL = .*/PATCHLEVEL = $P/" "$MAKEFILE"
sed -i "s/^SUBLEVEL = .*/SUBLEVEL = $S/" "$MAKEFILE"

echo ">> Kernel version spoofed to: $SPOOF_VER"
