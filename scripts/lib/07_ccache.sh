#!/bin/bash
set -e

# ==========================================
# ccache setup
# ==========================================
export CCACHE_DIR="${GITHUB_WORKSPACE}/.ccache"
export CCACHE_MAXSIZE="3G"
export CCACHE_COMPRESS=1
export CCACHE_COMPRESSLEVEL=6
export CCACHE_SLOPPINESS="file_macro,locale,time_macros"

# Deterministic timestamp so ccache doesn't miss on every single build
export KBUILD_BUILD_TIMESTAMP=""

mkdir -p "$CCACHE_DIR"
ccache -M "$CCACHE_MAXSIZE" >/dev/null
ccache -z >/dev/null

export CC_LAUNCHER="ccache"

echo "[+] ccache enabled — dir: $CCACHE_DIR, max size: $CCACHE_MAXSIZE"
ccache -s
