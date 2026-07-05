#!/usr/bin/env bash
set -eo pipefail

MANIFEST="scripts/checkpoint/manifest.json"
[ -f "$MANIFEST" ] || { echo "manifest.json not found"; exit 1; }

EMOJI_POOL=("🚀" "📦" "⚙️" "🧬" "⚡")
PICK_EMOJI="${EMOJI_POOL[$RANDOM % ${#EMOJI_POOL[@]}]}"

SOURCES=(
  "sukisu_root|SukiSU-Ultra (root)|https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/commits/main|.sha"
  "sukisu_susfs|SukiSU-Ultra (susfs)|https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/commits/builtin|.sha"
  "resukisu_root|ReSukiSU (root)|https://api.github.com/repos/ReSukiSU/ReSukiSU/commits/main|.sha"
  "resukisu_susfs|ReSukiSU (susfs)|https://api.github.com/repos/ReSukiSU/ReSukiSU/commits/main|.sha"
  "ksunext_root|KernelSU-Next (root)|https://api.github.com/repos/KernelSU-Next/KernelSU-Next/commits/dev|.sha"
  "ksunext_susfs|KernelSU-Next (susfs)|https://api.github.com/repos/KernelSU-Next/KernelSU-Next/commits/dev|.sha"
  "kowsu_root|KOWSU (root)|https://api.github.com/repos/KOWX712/KernelSU/commits/master|.sha"
  "kowsu_susfs|KOWSU (susfs)|https://api.github.com/repos/KOWX712/KernelSU/commits/master|.sha"
  "susfs4ksu|SUSFS4KSU (simon)|https://gitlab.com/api/v4/projects/simonpunk%2Fsusfs4ksu/repository/commits/gki-android15-6.6-dev|.id"
)

UPDATES=()

for entry in "${SOURCES[@]}"; do
  IFS='|' read -r key label url filter <<< "$entry"
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

TEXT="${PICK_EMOJI} ${#UPDATES[@]} update(s) found — new commit detected\n\n$(printf '%b' "$BODY_LINES")"

curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -d "chat_id=${TG_CHAT}" \
  --data-urlencode "text=${TEXT}" > /dev/null

echo "Notified: ${#UPDATES[@]} update(s)."
