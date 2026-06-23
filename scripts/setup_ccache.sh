#!/usr/bin/env bash
# setup_ccache.sh - Download & setup ccache-ECS for kernel compilation
set -euo pipefail

CCACHE_ECS_VERSION="ccache-ECS-v1.0"
CCACHE_ECS_REPO="cctv18/ccache-ECS"
CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-5G}"

echo "[ccache-ECS] Setting up ccache-ECS ${CCACHE_ECS_VERSION}..."

# Download binary dari GitHub release
# Asset name di release v1.0 kemungkinan: ccache (linux x86_64)
DOWNLOAD_URL="https://github.com/${CCACHE_ECS_REPO}/releases/download/${CCACHE_ECS_VERSION}/linux-x86_64-musl-static-binary.zip"

mkdir -p "$HOME/.local/bin"

echo "[ccache-ECS] Downloading binary..."
wget -q --show-progress "${DOWNLOAD_URL}" -O /tmp/ccache-ecs.zip
unzip -q /tmp/ccache-ecs.zip -d /tmp/ccache-ecs-extract

# Cari binary ccache di dalam zip
CCACHE_BIN=$(find /tmp/ccache-ecs-extract -name "ccache" -type f | head -1)
cp "$CCACHE_BIN" "$HOME/.local/bin/ccache-ecs"
chmod +x "$HOME/.local/bin/ccache-ecs"

# Symlink sebagai ccache utama
ln -sf "$HOME/.local/bin/ccache-ecs" "$HOME/.local/bin/ccache"

# Cleanup
rm -rf /tmp/ccache-ecs.zip /tmp/ccache-ecs-extract

# Verifikasi
echo "[ccache-ECS] Version: $("$HOME/.local/bin/ccache" --version | head -1)"

# Setup ccache config
export CCACHE_IS_KERNEL_COMPILING=true
mkdir -p "$CCACHE_DIR"
"$HOME/.local/bin/ccache" --set-config="cache_dir=${CCACHE_DIR}"
"$HOME/.local/bin/ccache" --set-config="max_size=${CCACHE_MAXSIZE}"
"$HOME/.local/bin/ccache" --set-config="compiler_check=content"
"$HOME/.local/bin/ccache" --set-config="compression=true"

echo "[ccache-ECS] Config:"
"$HOME/.local/bin/ccache" --show-config

# Export PATH supaya bisa dipake di step berikutnya
echo "$HOME/.local/bin" >> "${GITHUB_PATH:-/dev/null}"
echo "[ccache-ECS] Setup done!"
