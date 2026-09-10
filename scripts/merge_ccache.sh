#!/bin/bash
set -eo pipefail

CCACHE_ASSET="$1"
PARTS_DIR="${2:-ccache-parts}"
CCACHE_TAG="ccache-store"
CCACHE_REPO="${GITHUB_REPOSITORY}"
RUN_ID="${RUN_ID:-${GITHUB_RUN_ID:-}}"

if [ -z "$CCACHE_ASSET" ]; then
  echo "[!] Usage: merge_ccache.sh <asset-name> [parts-dir]"
  exit 1
fi

# Two callers share this script:
#   - build.yml (single build): parts are already on disk in PARTS_DIR.
#   - build-matrix.yml (4 builds): parts must be pulled from the run's
#     artifacts. Fetch them ONE AT A TIME and delete each as soon as it is
#     merged; pulling all of them up front ( ~11 GB ) blew the runner disk.
if [ -n "$RUN_ID" ] && [ -z "$(find "$PARTS_DIR" -name '*.tar.zst' 2>/dev/null)" ]; then
  echo "[+] No local parts found — downloading ccache-part artifacts from run ${RUN_ID} one at a time"
  if ! command -v gh >/dev/null 2>&1; then
    echo "[!] gh CLI not found — cannot download ccache parts. Skipping publish."
    exit 0
  fi
  DOWNLOAD_MODE=1
fi

MERGE_ROOT="$(mktemp -d)"

FOUND_ANY=0
PART_COUNT=0

merge_tarball() {
  local tarball="$1"
  FOUND_ANY=1
  PART_COUNT=$((PART_COUNT + 1))
  echo "[+] Merging part ${PART_COUNT}: $tarball"
  # Extract directly into MERGE_ROOT. Each part holds a top-level ".ccache/"
  # whose file names are content-addressed (hash), so extracting over is a
  # proper union and equal files simply overwrite. No rsync pass and no
  # per-part extraction dir means far less peak disk usage.
  tar --use-compress-program=unzstd -xf "$tarball" -C "$MERGE_ROOT"
}

if [ "${DOWNLOAD_MODE:-0}" == "1" ]; then
  ART_LIST="$(mktemp)"
  gh api "repos/${CCACHE_REPO}/actions/runs/${RUN_ID}/artifacts" --paginate \
    --jq '.artifacts[].name' | grep '^ccache-part-' || true > "$ART_LIST"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    part_dir="$(mktemp -d)"
    if ! gh run download "$RUN_ID" --name "$name" --dir "$part_dir" >/dev/null 2>&1; then
      echo "[!] Failed to download artifact $name — skipping"
      rm -rf "$part_dir"
      continue
    fi
    while IFS= read -r tb; do
      [ -n "$tb" ] || continue
      merge_tarball "$tb"
    done < <(find "$part_dir" -name '*.tar.zst' 2>/dev/null)
    rm -rf "$part_dir"
  done < "$ART_LIST"
  rm -f "$ART_LIST"
else
  while IFS= read -r tb; do
    [ -n "$tb" ] || continue
    merge_tarball "$tb"
  done < <(find "$PARTS_DIR" -name '*.tar.zst' 2>/dev/null)
fi

if [ "$FOUND_ANY" == "0" ]; then
  echo "[!] No ccache parts found — every build likely failed before it could save. Skipping publish."
  exit 0
fi

TAR_PATH="/tmp/${CCACHE_ASSET}"
tar --use-compress-program=zstdmt -cf "$TAR_PATH" -C "$MERGE_ROOT" .ccache

SIZE_MB=$(du -m "$TAR_PATH" | cut -f1)
echo "[+] Merged ccache archive: ${SIZE_MB} MB (from ${PART_COUNT} parts)"
if [ "$SIZE_MB" -gt 1900 ]; then
  echo "::warning::ccache archive is approaching the 2GB release asset limit (${SIZE_MB} MB)"
fi

if ! timeout 60 gh release view "$CCACHE_TAG" -R "$CCACHE_REPO" >/dev/null 2>&1; then
  echo "[+] Release tag ${CCACHE_TAG} doesn't exist yet, creating..."
  if ! timeout 60 gh release create "$CCACHE_TAG" -R "$CCACHE_REPO" \
    --title "ccache storage (do not delete)" \
    --notes "Persistent ccache storage per clang-variant+LTO mode. Auto-managed by CI." \
    --latest=false; then
    echo "[!] Failed to create release ${CCACHE_TAG} (auth/perms?) — continuing to upload, but likely to fail as well."
  fi
fi

UPLOAD_OK=0
for attempt in 1 2 3; do
  if timeout 600 gh release upload "$CCACHE_TAG" "$TAR_PATH" -R "$CCACHE_REPO" --clobber; then
    UPLOAD_OK=1
    break
  fi
  echo "[!] Upload attempt ${attempt} failed/timed out, retrying in 15s..."
  sleep 15
done

if [ "$UPLOAD_OK" == "0" ]; then
  echo "[!] Failed to upload ccache after 3 attempts, giving up (kernel build itself already succeeded)."
  rm -f "$TAR_PATH"
  exit 0
fi

echo "[+] Merged ccache uploaded as ${CCACHE_ASSET} — the only writer, no race."
rm -f "$TAR_PATH"