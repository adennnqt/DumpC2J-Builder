#!/bin/bash
set -e

# ==========================================
# DumpC2J Kernel Build Script (orchestrator)
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for f in "$SCRIPT_DIR"/lib/*.sh; do
    echo "[orchestrator] sourcing $(basename "$f")"
    source "$f"
done
