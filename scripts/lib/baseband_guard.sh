#!/bin/bash
set -e

BBG_DIR="$KERNEL_DIR/Baseband-guard"
if [ ! -d "$BBG_DIR" ]; then
  git clone --depth=1 https://github.com/vc-teahouse/Baseband-guard.git "$BBG_DIR"
else
  (cd "$BBG_DIR" && git fetch origin && git reset --hard origin/main || true)
fi
echo "[+] Running Baseband-guard setup..."
(cd "$KERNEL_DIR" && sh "$BBG_DIR/setup.sh")
