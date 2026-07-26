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
    source "$f"
  done
}

# NOTE: run_all_libs is intentionally called as a bare statement, NEVER as the
# tested operand of if/&&/||. In bash, when a function call (or `source`) is
# the direct operand of a conditional, `set -e`/`trap ... ERR` are suppressed
# for EVERYTHING executed inside it -- including anything further sourced from
# within. That previously let failing commands inside lib/*.sh (e.g. a failed
# git clone, or `make defconfig`/`make olddefconfig` with no explicit `return`
# guard) pass through completely silently and get reported as BUILD_OK=true.
# Verified empirically: `if run_all_libs; then` swallows failures; a bare
# `run_all_libs` call lets set -eE + `trap ... ERR` work correctly again.
# On failure here, the ERR trap (report_failure_once) fires and the script
# exits immediately -- everything below this point only runs on full success.
run_all_libs
# Only reached if every lib script in LIB_ORDER succeeded -- any failure above
# is caught by `trap report_failure_once ERR` and exits the script directly.

if [ -n "${PIN_KEY:-}" ]; then
  bash "${SCRIPT_DIR}/engine.sh" success "$PIN_KEY" "$PIN_PREFIX"
  bash "${SCRIPT_DIR}/engine.sh" success "susfs4ksu" "SUSFS4KSU"
fi

echo "[+] Build sukses."
