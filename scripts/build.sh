#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_all_libs() {
  for f in "$SCRIPT_DIR"/lib/*.sh; do
    echo "[orchestrator] sourcing $(basename "$f")"
    source "$f"
  done
}

export FORCE_LATEST="${INPUT_FORCE_LATEST:-false}"

if run_all_libs; then
  BUILD_OK=true
else
  BUILD_OK=false
fi

if [ -n "${PIN_KEY:-}" ]; then
  if [ "$BUILD_OK" == "true" ]; then
    bash "${SCRIPT_DIR}/engine.sh" success "$PIN_KEY" "$PIN_PREFIX"
  else
    bash "${SCRIPT_DIR}/engine.sh" failure "$PIN_KEY" "$PIN_PREFIX" || true
  fi
fi

[ "$BUILD_OK" == "true" ] || { echo "[-] Build gagal."; exit 1; }
