#!/bin/bash
set -e

KERNEL_DIR="${GITHUB_WORKSPACE}/kernel-source"
cd "$KERNEL_DIR"

git fetch origin --tags 2>/dev/null || true

TAG_NAME="dumpc2j-last-notified"

if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
  CHANGELOG=$(git log "${TAG_NAME}..HEAD" --no-merges --pretty=format:"%s" | grep -vi '\[ci\]' || true)
else
  CHANGELOG=$(git log -10 --no-merges --pretty=format:"%s" | grep -vi '\[ci\]' || true)
fi

if [ -z "$CHANGELOG" ]; then
  CHANGELOG_TEXT="No kernel changes since last build."
else
  CHANGELOG_TEXT=$(echo "$CHANGELOG" | sed 's/^/- /')
fi

MESSAGE="🔧 *DumpC2J Kernel Build*
Version: \`${KERNEL_VER}\`
Variant: ${ACTUAL_ROOT:-stock} | HZ: ${HZ_ID} | LTO: ${LTO_ACTUAL}
Clang: ${KBUILD_COMPILER_STRING}

*Changes:*
${CHANGELOG_TEXT}

📦 File: \`${ZIP_NAME}\`"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d parse_mode="Markdown" \
  --data-urlencode text="$MESSAGE" > /dev/null

git tag -f "$TAG_NAME"
git push origin "$TAG_NAME" --force 2>/dev/null || echo "[!] Gagal push tag (cek GH_TOKEN)"
