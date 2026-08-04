#!/bin/bash
set -e

BBG_DIR="$KERNEL_DIR/Baseband-guard"
if [ ! -d "$BBG_DIR" ]; then
  timeout 60 git clone --depth=1 https://github.com/vc-teahouse/Baseband-guard.git "$BBG_DIR" || { echo "[!] Baseband-guard clone failed/timed out"; exit 1; }
else
  (cd "$BBG_DIR" && timeout 60 git fetch origin && git reset --hard origin/main || echo "[!] Baseband-guard update failed, using stale checkout")
fi
echo "[+] Running Baseband-guard setup..."
(cd "$KERNEL_DIR" && sh "$BBG_DIR/setup.sh")
