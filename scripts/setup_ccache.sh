#!/usr/bin/env bash
# setup_ccache.sh - ccache-ECS setup (LuminaireProtocol pattern)
set -euo pipefail

CCACHE_ECS_VERSION="ccache-ECS-v1.0"
CCACHE_ECS_REPO="cctv18/ccache-ECS"
CCACHE_BIN_DIR="${HOME}/ccache-bin"
CCACHE_BIN="${CCACHE_BIN_DIR}/ccache"
CCACHE_DIR="${CCACHE_DIR:-/home/runner/.ccache}"
CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-5G}"

# Download binary jika belum ada (dari cache atau fresh)
if [ -f "$CCACHE_BIN" ]; then
    echo "[ccache-ECS] Binary already cached, skipping download"
else
    echo "[ccache-ECS] Downloading binary..."
    DOWNLOAD_URL="https://github.com/${CCACHE_ECS_REPO}/releases/download/${CCACHE_ECS_VERSION}/linux-x86_64-musl-static-binary.zip"
    wget -q "${DOWNLOAD_URL}" -O /tmp/ccache-ecs.zip
    unzip -q /tmp/ccache-ecs.zip -d /tmp/ccache-ecs-extract
    mkdir -p "$CCACHE_BIN_DIR"
    cp "$(find /tmp/ccache-ecs-extract -name 'ccache' -type f | head -1)" "$CCACHE_BIN"
    chmod +x "$CCACHE_BIN"
    rm -rf /tmp/ccache-ecs.zip /tmp/ccache-ecs-extract
fi

echo "[ccache-ECS] Version: $($CCACHE_BIN --version | head -1)"

# Config
mkdir -p "$CCACHE_DIR"
$CCACHE_BIN --set-config="cache_dir=${CCACHE_DIR}"
$CCACHE_BIN --set-config="max_size=${CCACHE_MAXSIZE}"
$CCACHE_BIN --set-config="compiler_check=content"
$CCACHE_BIN --set-config="compression=true"
$CCACHE_BIN --set-config="compression_level=1"
$CCACHE_BIN --zero-stats > /dev/null 2>&1 || true

echo "[ccache-ECS] Setup done! dir: ${CCACHE_DIR} | max: ${CCACHE_MAXSIZE}"
