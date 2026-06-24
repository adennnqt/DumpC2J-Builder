#!/usr/bin/env bash
set -euo pipefail

CCACHE_ECS_VERSION="ccache-ECS-v1.0"
CCACHE_ECS_REPO="cctv18/ccache-ECS"
CCACHE_BIN_CACHE="${HOME}/ccache-bin"
CCACHE_DIR="${CCACHE_DIR:-/home/runner/.ccache}"
CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-5G}"

echo "[ccache-ECS] Setting up..."

if [ -f "${CCACHE_BIN_CACHE}/ccache" ]; then
    echo "[ccache-ECS] Binary already cached, skipping download"
else
    echo "[ccache-ECS] Downloading binary..."
    DOWNLOAD_URL="https://github.com/${CCACHE_ECS_REPO}/releases/download/${CCACHE_ECS_VERSION}/linux-x86_64-musl-static-binary.zip"
    wget -q "${DOWNLOAD_URL}" -O /tmp/ccache-ecs.zip
    unzip -q /tmp/ccache-ecs.zip -d /tmp/ccache-ecs-extract
    CCACHE_BIN=$(find /tmp/ccache-ecs-extract -name "ccache" -type f | head -1)
    mkdir -p "${CCACHE_BIN_CACHE}"
    cp "$CCACHE_BIN" "${CCACHE_BIN_CACHE}/ccache"
    chmod +x "${CCACHE_BIN_CACHE}/ccache"
    rm -rf /tmp/ccache-ecs.zip /tmp/ccache-ecs-extract
fi

# Override system ccache
sudo ln -sf "${CCACHE_BIN_CACHE}/ccache" /usr/local/bin/ccache
echo "[ccache-ECS] Version: $(${CCACHE_BIN_CACHE}/ccache --version | head -1)"

# Config
mkdir -p "$CCACHE_DIR"
${CCACHE_BIN_CACHE}/ccache --set-config="cache_dir=${CCACHE_DIR}"
${CCACHE_BIN_CACHE}/ccache --set-config="max_size=${CCACHE_MAXSIZE}"
${CCACHE_BIN_CACHE}/ccache --set-config="compiler_check=content"
${CCACHE_BIN_CACHE}/ccache --set-config="compression=true"
${CCACHE_BIN_CACHE}/ccache --set-config="compression_level=1"

# Export env buat build step
echo "CCACHE_DIR=${CCACHE_DIR}" >> $GITHUB_ENV
echo "CCACHE_IS_KERNEL_COMPILING=true" >> $GITHUB_ENV
echo "CCACHE_COMPRESS=1" >> $GITHUB_ENV
echo "CCACHE_COMPRESSLEVEL=1" >> $GITHUB_ENV
echo "TOOL_CCACHE_BIN=${CCACHE_BIN_CACHE}/ccache" >> $GITHUB_ENV

echo "[ccache-ECS] Setup done! dir: ${CCACHE_DIR} | max: ${CCACHE_MAXSIZE}"
