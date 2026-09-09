#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/functions.sh"

ZIP_PATH="${KERNEL_DIR}/DumpC2J-Release/${ZIP_NAME}"
VAR_LABEL="${VARIANT_LABEL:-${ZIP_NAME%.zip}}"

SEND_DOC=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendDocument" \
  -F chat_id="${TELEGRAM_CHANNEL_ID}" \
  -F parse_mode="HTML" \
  -F caption="${VAR_LABEL}" \
  -F disable_notification=true \
  -F document=@"${ZIP_PATH}")

if ! echo "$SEND_DOC" | grep -q '"ok":true'; then
  error "Failed to upload ${ZIP_NAME} to channel. Response:"
  echo "$SEND_DOC"
fi

MSG_ID=$(echo "$SEND_DOC" | jq -r '.result.message_id')
USERNAME=$(curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getChat?chat_id=${TELEGRAM_CHANNEL_ID}" \
  | jq -r '.result.username // empty')

LINK="https://t.me/${USERNAME}/${MSG_ID}"
log "Channel post: ${LINK}"

META="{\"variant\":\"${VARIANT}\",\"root\":\"${ROOT}\",\"label\":\"${VAR_LABEL}\",\"zip\":\"${ZIP_NAME}\",\"link\":\"${LINK}\"}"
echo "$META" > "${GITHUB_WORKSPACE}/variant_meta.json"
log "Meta written: variant_meta.json"