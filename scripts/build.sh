#!/bin/bash
set -eE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENGINE_REPORTED=""
report_failure_once() {
  [ -n "${PIN_KEY:-}" ] || return 0
  [ -z "$ENGINE_REPORTED" ] || return 0
  ENGINE_REPORTED=1
  local root_candidate_var="CANDIDATE_${PIN_PREFIX}"
  local root_is_candidate="${!root_candidate_var:-false}"
  local susfs_is_candidate="${CANDIDATE_SUSFS4KSU:-false}"
  if [ "$root_is_candidate" == "true" ] && [ "$susfs_is_candidate" == "true" ]; then
    echo "[!] Ambiguous failure (unguarded error): $PIN_KEY dan susfs4ksu sama-sama candidate baru — skip auto-blacklist. Cek manual."
  else
    [ "$root_is_candidate" == "true" ] && bash "${SCRIPT_DIR}/engine.sh" failure "$PIN_KEY" "$PIN_PREFIX"
    [ "$susfs_is_candidate" == "true" ] && bash "${SCRIPT_DIR}/engine.sh" failure "susfs4ksu" "SUSFS4KSU"
    true
  fi
}
trap report_failure_once ERR

LIB_ORDER=(
  defaults.sh
  adjust_inputs.sh
  root_setup.sh
  branding.sh
  baseband_guard.sh
  rekernel.sh
  resukisu_fixes.sh
  clang_flags.sh
  kconfig.sh
  compile.sh
  package.sh
)

run_all_libs() {
  for name in "${LIB_ORDER[@]}"; do
    f="$SCRIPT_DIR/lib/$name"
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
    report_failure_once
  fi
fi

[ "$BUILD_OK" == "true" ] || { echo "[-] Build gagal."; exit 1; }
