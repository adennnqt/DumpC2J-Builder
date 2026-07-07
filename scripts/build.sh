#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_all_libs() {
  for f in "$SCRIPT_DIR"/lib/*.sh; do
    echo "[orchestrator] sourcing $(basename "$f")"
    source "$f" || return 1
  done
}

if run_all_libs; then
  BUILD_OK=true
else
  BUILD_OK=false
fi

if [ -n "${PIN_KEY:-}" ]; then
  if [ "$BUILD_OK" == "true" ]; then
    bash "${SCRIPT_DIR}/engine.sh" success "$PIN_KEY" "$PIN_PREFIX"
    bash "${SCRIPT_DIR}/engine.sh" success "susfs4ksu" "SUSFS4KSU"
  else
    root_candidate_var="CANDIDATE_${PIN_PREFIX}"
    root_is_candidate="${!root_candidate_var:-false}"
    susfs_is_candidate="${CANDIDATE_SUSFS4KSU:-false}"

    if [ "$root_is_candidate" == "true" ] && [ "$susfs_is_candidate" == "true" ]; then
      echo "[!] Ambiguous failure: $PIN_KEY dan susfs4ksu sama-sama candidate baru di run ini — gak bisa nentuin siapa yg salah, skip auto-blacklist. Cek manual."
    else
      [ "$root_is_candidate" == "true" ] && bash "${SCRIPT_DIR}/engine.sh" failure "$PIN_KEY" "$PIN_PREFIX"
      [ "$susfs_is_candidate" == "true" ] && bash "${SCRIPT_DIR}/engine.sh" failure "susfs4ksu" "SUSFS4KSU"
      true
    fi
  fi
fi

[ "$BUILD_OK" == "true" ] || { echo "[-] Build gagal."; exit 1; }
