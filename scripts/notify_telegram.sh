#!/bin/bash
set -e

KERNEL_DIR="${GITHUB_WORKSPACE}/kernel-source"
BUILDER_DIR="${GITHUB_WORKSPACE}/builder"
ZIP_PATH="${KERNEL_DIR}/DumpC2J-Release/${ZIP_NAME}"

esc() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

get_raw_log() {
  local repo_dir="$1" tag_name="$2"
  (cd "$repo_dir" && git fetch origin --tags 2>/dev/null || true)
  if (cd "$repo_dir" && git rev-parse "$tag_name" >/dev/null 2>&1); then
    (cd "$repo_dir" && git log "${tag_name}..HEAD" --no-merges --pretty=format:"%B%x1e" || true)
  else
    (cd "$repo_dir" && git log -10 --no-merges --pretty=format:"%B%x1e" || true)
  fi
}

format_changelog() {
  local raw_log="$1"
  local -A groups
  local order=(added fixed changed)
  local -A labels=( [added]="✨ Added" [fixed]="🐛 Fixed" [changed]="🔧 Changed" )
  local commit_body subject type desc key trailer_val

  while IFS= read -r -d $'\x1e' commit_body; do
    [ -z "$commit_body" ] && continue
    subject=$(head -n1 <<< "$commit_body")
    echo "$subject" | grep -qi '\[ci\]' && continue

    # "Changelog:" trailer override — "Changelog: skip" excludes the commit
    # entirely from the notification (buat commit internal/debug yg gak
    # relevan buat end-user). Isi lain menggantikan deskripsi auto-generated.
    trailer_val=$(grep -iP '^Changelog:\s*' <<< "$commit_body" | tail -1 | sed -E 's/^Changelog:\s*//I')
    if [ -n "$trailer_val" ]; then
      shopt -s nocasematch
      if [[ "$trailer_val" == "skip" ]]; then
        shopt -u nocasematch
        continue
      fi
      shopt -u nocasematch
    fi

    type=$(echo "$subject" | grep -oP '^[a-zA-Z]+(?=(\([^)]*\))?:)' || true)
    type=$(echo "$type" | tr '[:upper:]' '[:lower:]')

    if [ -n "$trailer_val" ]; then
      desc="$trailer_val"
    else
      desc="$subject"
      while echo "$desc" | grep -qP '^[a-zA-Z]+(\([^)]*\))?:\s*'; do
        desc=$(echo "$desc" | sed -E 's/^[a-zA-Z]+(\([^)]*\))?:\s*//')
      done
    fi
    desc="$(tr '[:lower:]' '[:upper:]' <<< "${desc:0:1}")${desc:1}"
    desc=$(esc "$desc")

    case "$type" in
      feat) key="added" ;;
      fix)  key="fixed" ;;
      *)    key="changed" ;;
    esac
    groups[$key]="${groups[$key]}• ${desc}\n"
  done <<< "$raw_log"

  local out=""
  for key in "${order[@]}"; do
    if [ -n "${groups[$key]:-}" ]; then
      out="${out}<b>${labels[$key]}:</b>\n$(printf '%b' "${groups[$key]}")\n"
    fi
  done
  printf '%s' "$out"
}

KERNEL_RAW=$(get_raw_log "$KERNEL_DIR" "dumpc2j-last-notified")
BUILDER_RAW=$(get_raw_log "$BUILDER_DIR" "dumpc2j-builder-last-notified")
KERNEL_CL=$(format_changelog "$KERNEL_RAW")
BUILDER_CL=$(format_changelog "$BUILDER_RAW")

CHANGELOG_TEXT=""
[ -n "$KERNEL_CL" ]  && CHANGELOG_TEXT="${CHANGELOG_TEXT}<b>🧬 Kernel Changes:</b>\n${KERNEL_CL}\n"
[ -n "$BUILDER_CL" ] && CHANGELOG_TEXT="${CHANGELOG_TEXT}<b>🛠️ Builder Changes:</b>\n${BUILDER_CL}\n"
[ -z "$CHANGELOG_TEXT" ] && CHANGELOG_TEXT="No changes since last build.\n"

case "$INPUT_VARIANT" in
  stock) VARIANT_LABEL="📦 Stock (No Root)" ;;
  root)  VARIANT_LABEL="🔓 Root Only » ${ACTUAL_ROOT:-?}" ;;
  susfs) VARIANT_LABEL="🛡️ SUSFS » ${ACTUAL_ROOT:-?}" ;;
  *)     VARIANT_LABEL="${INPUT_VARIANT:-unknown}" ;;
esac

FEAT="✅ HTSR 240Hz Touch\n✅ WiFi Performance Exploits\n✅ KGSL GPU Bypass\n✅ Mobile Data Exploits\n"
[ "${INPUT_BYPASS:-off}" == "on" ]      && FEAT="${FEAT}✅ Bypass Charging\n"
[ "${INPUT_NOMOUNT:-off}" == "on" ]     && FEAT="${FEAT}✅ NoMount (VFS)\n"
[ "${INPUT_DROIDSPACES:-off}" == "on" ] && FEAT="${FEAT}✅ Droidspaces\n"
[ "${INPUT_DEBUG:-off}" == "on" ]       && FEAT="${FEAT}🐛 Debug Mode\n"

FILE_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
SHA256_FULL=$(sha256sum "$ZIP_PATH" | cut -d' ' -f1)
SHA256_SHORT="${SHA256_FULL:0:12}"

KERNEL_COMMIT_SHA=$(cd "$KERNEL_DIR" && git rev-parse HEAD)
KERNEL_COMMIT_SHORT="${KERNEL_COMMIT_SHA:0:7}"
KERNEL_COMMIT_URL="https://github.com/adennnqt/DumpC2J-Kernel/commit/${KERNEL_COMMIT_SHA}"

BUILDER_COMMIT_SHORT="${GITHUB_SHA:0:7}"
BUILDER_COMMIT_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}"

RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
BUILD_DATE=$(date -u "+%Y-%m-%d %H:%M UTC")

DUR="${BUILD_DURATION_SEC:-0}"
DUR_TEXT="$((DUR / 60))m $((DUR % 60))s"

[ "${ROOT_FALLBACK_USED:-false}" == "true" ] && FALLBACK_NOTE="⚠️ <b>Fallback used</b> — latest root method commit failed to build, automatically used last known-good commit.\n\n" || FALLBACK_NOTE=""

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
  echo "[✗] Failed to upload file to Telegram. Response:"
  echo "$SEND_DOC"
  exit 1
fi

MSG_ID=$(echo "$SEND_DOC" | jq -r '.result.message_id')

DETAIL="📋 <b>Build Detail</b>

$(printf '%b' "$FALLBACK_NOTE")<b>Specs:</b>
📦 Version: <code>${KERNEL_VER}</code>
🌿 Variant: ${VARIANT_LABEL}
🔢 HZ: ${HZ_ID} Hz
🔗 LTO: ${LTO_ACTUAL}
⚙️ Clang: ${KBUILD_COMPILER_STRING}

<b>Addons / Features:</b>
$(printf '%b' "$FEAT")
$(printf '%b' "$CHANGELOG_TEXT")
<b>Build Info:</b>
📁 Name: <code>${ZIP_NAME}</code>
💾 Size: ${FILE_SIZE}
🔐 SHA256: <code>${SHA256_FULL}</code>
⏱️ Duration: ${DUR_TEXT}
📅 Date: ${BUILD_DATE}
🧬 Kernel Commit: <a href=\"${KERNEL_COMMIT_URL}\">${KERNEL_COMMIT_SHORT}</a>
🛠️ Builder Commit: <a href=\"${BUILDER_COMMIT_URL}\">${BUILDER_COMMIT_SHORT}</a>
🏃 Run: <a href=\"${RUN_URL}\">#${GITHUB_RUN_NUMBER}</a>"

SEND_DETAIL=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d parse_mode="HTML" \
  -d reply_to_message_id="${MSG_ID}" \
  --data-urlencode text="$DETAIL")

update_tag() {
  local repo_dir="$1" tag_name="$2"
  (cd "$repo_dir" && git tag -f "$tag_name" && git push origin "$tag_name" --force 2>/dev/null) || echo "[!] Failed to push tag $tag_name in $repo_dir"
}

if echo "$SEND_DETAIL" | grep -q '"ok":true'; then
  echo "[✓] Telegram notification (file + detail) sent."
  update_tag "$KERNEL_DIR" "dumpc2j-last-notified"
  update_tag "$BUILDER_DIR" "dumpc2j-builder-last-notified"
else
  echo "[!] File sent, but detail message failed. Trying plain text fallback..."
  echo "$SEND_DETAIL"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d reply_to_message_id="${MSG_ID}" \
    --data-urlencode text="$DETAIL" > /dev/null
  update_tag "$KERNEL_DIR" "dumpc2j-last-notified"
  update_tag "$BUILDER_DIR" "dumpc2j-builder-last-notified"
fi
