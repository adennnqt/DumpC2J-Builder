#!/bin/bash
set -e

KERNEL_DIR="${GITHUB_WORKSPACE}/kernel-source"
ZIP_PATH="${KERNEL_DIR}/DumpC2J-Release/${ZIP_NAME}"
cd "$KERNEL_DIR"

git fetch origin --tags 2>/dev/null || true
TAG_NAME="dumpc2j-last-notified"

if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
  RAW_LOG=$(git log "${TAG_NAME}..HEAD" --no-merges --pretty=format:"%s" | grep -vi '\[ci\]' || true)
else
  RAW_LOG=$(git log -10 --no-merges --pretty=format:"%s" | grep -vi '\[ci\]' || true)
fi

# --- HTML escape helper (aman buat commit message aneh-aneh) ---
esc() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

# --- Changelog grouping (feat/fix/other) ---
declare -A CL_GROUPS
CL_ORDER=(added fixed changed)
declare -A CL_LABELS=( [added]="✨ Added" [fixed]="🐛 Fixed" [changed]="🔧 Changed" )

while IFS= read -r line; do
  [ -z "$line" ] && continue
  type=$(echo "$line" | grep -oP '^[a-zA-Z]+(?=(\([^)]*\))?:)' || true)
  type=$(echo "$type" | tr '[:upper:]' '[:lower:]')
  desc="$line"
  while echo "$desc" | grep -qP '^[a-zA-Z]+(\([^)]*\))?:\s*'; do
    desc=$(echo "$desc" | sed -E 's/^[a-zA-Z]+(\([^)]*\))?:\s*//')
  done
  desc="$(tr '[:lower:]' '[:upper:]' <<< "${desc:0:1}")${desc:1}"
  desc=$(esc "$desc")

  case "$type" in
    feat) key="added" ;;
    fix)  key="fixed" ;;
    *)    key="changed" ;;
  esac
  CL_GROUPS[$key]="${CL_GROUPS[$key]}• ${desc}\n"
done <<< "$RAW_LOG"

CHANGELOG_TEXT=""
for key in "${CL_ORDER[@]}"; do
  if [ -n "${CL_GROUPS[$key]:-}" ]; then
    CHANGELOG_TEXT="${CHANGELOG_TEXT}<b>${CL_LABELS[$key]}:</b>\n$(printf '%b' "${CL_GROUPS[$key]}")\n"
  fi
done
[ -z "$CHANGELOG_TEXT" ] && CHANGELOG_TEXT="Tidak ada perubahan sejak build terakhir.\n"

# --- Variant label ---
case "$INPUT_VARIANT" in
  stock) VARIANT_LABEL="📦 Stock (No Root)" ;;
  root)  VARIANT_LABEL="🔓 Root Only » ${ACTUAL_ROOT:-?}" ;;
  susfs) VARIANT_LABEL="🛡️ SUSFS » ${ACTUAL_ROOT:-?}" ;;
  *)     VARIANT_LABEL="${INPUT_VARIANT:-unknown}" ;;
esac

# --- Addons / Features ---
FEAT="✅ HTSR 240Hz Touch\n✅ WiFi Performance Exploits\n✅ KGSL GPU Bypass\n✅ Mobile Data Exploits\n"
[ "${INPUT_BYPASS:-off}" == "on" ]      && FEAT="${FEAT}✅ Bypass Charging\n"
[ "${INPUT_NOMOUNT:-off}" == "on" ]     && FEAT="${FEAT}✅ NoMount (VFS)\n"
[ "${INPUT_DROIDSPACES:-off}" == "on" ] && FEAT="${FEAT}✅ Droidspaces\n"
[ "${INPUT_DEBUG:-off}" == "on" ]       && FEAT="${FEAT}🐛 Debug Mode\n"

# --- Build metadata ---
FILE_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
SHA256_FULL=$(sha256sum "$ZIP_PATH" | cut -d' ' -f1)
SHA256_SHORT="${SHA256_FULL:0:12}"
COMMIT_SHORT="${GITHUB_SHA:0:7}"
COMMIT_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}"
RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
BUILD_DATE=$(date -u "+%Y-%m-%d %H:%M UTC")

DUR="${BUILD_DURATION_SEC:-0}"
DUR_TEXT="$((DUR / 60))m $((DUR % 60))s"

# --- Pesan 1: caption ringkas (dikirim bareng file) ---
CAPTION="🔧 <b>DumpC2J Kernel Build</b>

📦 <code>${KERNEL_VER}</code> · ${VARIANT_LABEL}
🔗 LTO: ${LTO_ACTUAL} · ⚙️ ${KBUILD_COMPILER_STRING}
🔢 ${HZ_ID} Hz · ⏱️ ${DUR_TEXT}
🔐 <code>${SHA256_SHORT}</code>"

SEND_DOC=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendDocument" \
  -F chat_id="${TELEGRAM_CHAT_ID}" \
  -F parse_mode="HTML" \
  -F caption="${CAPTION}" \
  -F document=@"${ZIP_PATH}")

if ! echo "$SEND_DOC" | grep -q '"ok":true'; then
  echo "[✗] Gagal upload file ke Telegram. Response:"
  echo "$SEND_DOC"
  exit 1
fi

MSG_ID=$(echo "$SEND_DOC" | jq -r '.result.message_id')

# --- Pesan 2: detail lengkap (reply ke file) ---
DETAIL="📋 <b>Detail Build</b>

<b>Spesifikasi:</b>
📦 Versi: <code>${KERNEL_VER}</code>
🌿 Variant: ${VARIANT_LABEL}
🔢 HZ: ${HZ_ID} Hz
🔗 LTO: ${LTO_ACTUAL}
⚙️ Clang: ${KBUILD_COMPILER_STRING}

<b>Addons / Fitur:</b>
$(printf '%b' "$FEAT")
$(printf '%b' "$CHANGELOG_TEXT")
<b>Build Info:</b>
📁 Nama: <code>${ZIP_NAME}</code>
💾 Ukuran: ${FILE_SIZE}
🔐 SHA256: <code>${SHA256_FULL}</code>
⏱️ Durasi: ${DUR_TEXT}
📅 Tanggal: ${BUILD_DATE}
🔀 Commit: <a href=\"${COMMIT_URL}\">${COMMIT_SHORT}</a>
🏃 Run: <a href=\"${RUN_URL}\">#${GITHUB_RUN_NUMBER}</a>"

SEND_DETAIL=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d parse_mode="HTML" \
  -d reply_to_message_id="${MSG_ID}" \
  --data-urlencode text="$DETAIL")

if echo "$SEND_DETAIL" | grep -q '"ok":true'; then
  echo "[✓] Notifikasi Telegram (file + detail) terkirim."
  git tag -f "$TAG_NAME"
  git push origin "$TAG_NAME" --force 2>/dev/null || echo "[!] Gagal push tag (cek GH_TOKEN)"
else
  echo "[!] File terkirim, tapi detail gagal. Coba fallback plain text..."
  echo "$SEND_DETAIL"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d reply_to_message_id="${MSG_ID}" \
    --data-urlencode text="$DETAIL" > /dev/null
  git tag -f "$TAG_NAME"
  git push origin "$TAG_NAME" --force 2>/dev/null || true
fi
