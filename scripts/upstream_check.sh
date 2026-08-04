#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/functions.sh"

MANIFEST="scripts/checkpoint/manifest.json"
[ -f "$MANIFEST" ] || { echo "manifest.json not found"; exit 1; }

EMOJI_POOL=("🚀" "📦" "⚙️" "🧬" "⚡")
PICK_EMOJI="${EMOJI_POOL[$RANDOM % ${#EMOJI_POOL[@]}]}"

UPDATES=()

for key in "${!DUMPC2J_SOURCES[@]}"; do
  label=$(source_label "$key")
  url=$(source_url "$key")
  filter=$(source_filter "$key")
  good=$(jq -r ".${key}.good // \"\"" "$MANIFEST")

  body_file=$(mktemp)
  http_code=$(curl -sL -o "$body_file" -w '%{http_code}' --max-time 20 "$url") || http_code="000"
  if [ "$http_code" != "200" ]; then
    echo "[!] $label: failed to fetch upstream (HTTP $http_code) — skip"
    rm -f "$body_file"; continue
  fi

  latest=$(jq -r "$filter" "$body_file" 2>/dev/null)
  rm -f "$body_file"

  if [ -z "$latest" ] || [ "$latest" = "null" ]; then
    echo "[!] $label: failed to parse sha — skip"; continue
  fi
  if [ -z "$good" ]; then
    echo "[i] $label: no pin yet — skip (first run)"; continue
  fi

  if [ "$latest" != "$good" ]; then
    echo "[+] $label: ${good:0:8} -> ${latest:0:8}"
    UPDATES+=("${label}: ${good:0:8} -> ${latest:0:8}")
  else
    echo "[=] $label: up to date"
  fi
done

if [ "${#UPDATES[@]}" -eq 0 ]; then
  echo "No updates found — skip notify."
  exit 0
fi

BODY_LINES=""
for line in "${UPDATES[@]}"; do
  BODY_LINES="${BODY_LINES}${line}\n"
done

RAW_TEXT="${PICK_EMOJI} ${#UPDATES[@]} update(s) found -- new commit detected\n\n${BODY_LINES}"
TEXT=$(printf '%b' "$RAW_TEXT")

curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -d "chat_id=${TG_CHAT}" \
  --data-urlencode "text=${TEXT}" > /dev/null

echo "Notified: ${#UPDATES[@]} update(s)."
