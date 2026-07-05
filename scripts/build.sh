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

if [ "$BUILD_OK" == "true" ]; then
  if [ "$MANAGER_USING_LATEST" == "true" ] && [ -n "$MANAGER_USED_SHA" ]; then
    echo "[+] Build sukses pake commit latest ${MANAGER_ROOT_NAME}@${MANAGER_USED_SHA:0:8} — update known-good."
    echo "$MANAGER_USED_SHA" > "${SCRIPT_DIR}/known-good/${MANAGER_ROOT_NAME}.sha"
    cd "$GITHUB_WORKSPACE"
    git config user.name "DumpC2J Bot"
    git config user.email "bot@dumpc2j"
    git add "scripts/known-good/${MANAGER_ROOT_NAME}.sha"
    git commit -m "chore(known-good): update ${MANAGER_ROOT_NAME} to ${MANAGER_USED_SHA:0:7}" || true
    git push origin HEAD:main || true
    echo "FALLBACK_HAPPENED=false" >> "$GITHUB_ENV"
  fi
else
  echo "[!] Build gagal pake commit latest (${MANAGER_ROOT_NAME}@${MANAGER_USED_SHA:0:8})"

  if [ -z "$MANAGER_KNOWN_GOOD_SHA" ] || [ "$MANAGER_ROOT_NAME" == "" ]; then
    echo "[-] Belum ada known-good tersimpan (atau root=none), gak bisa fallback. Build tetap gagal."
    echo "FALLBACK_HAPPENED=error_no_known_good" >> "$GITHUB_ENV"
    exit 1
  fi

  echo "[+] Fallback: retry build pake known-good ${MANAGER_ROOT_NAME}@${MANAGER_KNOWN_GOOD_SHA:0:8}"
  export FORCE_LATEST=false  # already unused; retry below is now redundant but harmless since default is already pinned

  if run_all_libs; then
    echo "[+] Fallback build sukses."
    echo "FALLBACK_HAPPENED=true" >> "$GITHUB_ENV"
  else
    echo "[-] Fallback build JUGA gagal — perlu dicek manual."
    echo "FALLBACK_HAPPENED=error_fallback_failed" >> "$GITHUB_ENV"
    exit 1
  fi
fi
