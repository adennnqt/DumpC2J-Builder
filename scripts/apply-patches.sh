#!/bin/bash
set -e

KERNEL_DIR="$1"
PATCH_SETS="$2"

if [ -z "$KERNEL_DIR" ] || [ -z "$PATCH_SETS" ]; then
  echo "Usage: $0 <kernel_dir> <patch_set1,patch_set2,...>"
  exit 1
fi

cd "$KERNEL_DIR" || exit 1

IFS=',' read -ra SETS <<< "$PATCH_SETS"
for set in "${SETS[@]}"; do
  PATCH_PATH="../patches/$set"
  if [ -d "$PATCH_PATH" ]; then
    for patch in "$PATCH_PATH"/*.patch; do
      [ -f "$patch" ] || continue
      echo ">> Applying patch: $patch"
      git apply --check "$patch" && git apply "$patch"
    done
  else
    echo "!! Patch set not found: $set"
    exit 1
  fi
done

echo "All patches applied successfully."
