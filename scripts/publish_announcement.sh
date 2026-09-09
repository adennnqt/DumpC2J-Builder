#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/functions.sh"

: "${KERNEL_DIR:?KERNEL_DIR not set}"
: "${LINKS_DIR:?LINKS_DIR not set}"
ANDROID_VERSION="${ANDROID_VERSION:-15}"

esc() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

KVER=$(grep '^VERSION = ' "$KERNEL_DIR/Makefile" | awk '{print $3}')
KPL=$(grep '^PATCHLEVEL = ' "$KERNEL_DIR/Makefile" | awk '{print $3}')
KSL=$(grep '^SUBLEVEL = ' "$KERNEL_DIR/Makefile" | awk '{print $3}')
KERNEL_VER="${KVER}.${KPL}.${KSL}"
log "Kernel version: ${KERNEL_VER}"

# gather per-variant metadata written by notify_channel.sh
declare -A LINKS LABELS
ORDER=(Vanilla SUKISU-SUSFS RESUKI-SUSFS KSUN-SUSFS)
for f in "${LINKS_DIR}"/*/variant_meta.json; do
  [ -f "$f" ] || continue
  label=$(jq -r '.label' "$f")
  link=$(jq -r '.link' "$f")
  LINKS[$label]="$link"
  LABELS[$label]=1
done
[ ${#LINKS[@]} -gt 0 ] || error "No variant metadata found in ${LINKS_DIR}"

VAR_LINES=""
for label in "${ORDER[@]}"; do
  [ -n "${LINKS[$label]:-}" ] && VAR_LINES="${VAR_LINES}• <a href=\"${LINKS[$label]}\">${label}</a>\n"
done
for label in "${!LINKS[@]}"; do
  case " ${ORDER[*]} " in
    *" $label "*) ;;
    *) VAR_LINES="${VAR_LINES}• <a href=\"${LINKS[$label]}\">${label}</a>\n" ;;
  esac
done

# changelog: feat -> Added; upstream Linux version -> Changed; rest dropped (keep it simple)
DROP_PREFIX='chore|ci|docs|style|refactor|test|perf'
ADDED="" CHANGED=""
while IFS= read -r subject; do
  [ -z "$subject" ] && continue
  echo "$subject" | grep -qi '\[ci\]' && continue
  type=$(echo "$subject" | grep -oP '^[a-zA-Z]+(?=(\([^)]*\))?:)' || true)
  type=$(echo "$type" | tr '[:upper:]' '[:lower:]')
  echo "$type" | grep -qE "^($DROP_PREFIX)$" && continue
  rest=$(echo "$subject" | sed -E 's/^[a-zA-Z]+(\([^)]*\))?:\s*//')
  desc=$(echo "$rest" | sed -E 's/\s*$//')
  desc="$(tr '[:lower:]' '[:upper:]' <<< "${desc:0:1}")${desc:1}"
  desc=$(esc "$desc")
  if [ "$type" == "feat" ]; then
    ADDED="${ADDED}• ${desc}\n"
  elif echo "$subject" | grep -qE '^Linux +[0-9]+\.[0-9]+\.[0-9]+'; then
    CHANGED="${CHANGED}• ${desc}\n"
  fi
done < <(cd "$KERNEL_DIR" && git log -15 --no-merges --pretty=format:"%s")

CHANGELOG=""
[ -n "$ADDED" ]  && CHANGELOG="${CHANGELOG}✨ Added:\n${ADDED}\n"
[ -n "$CHANGED" ] && CHANGELOG="${CHANGELOG}🔧 Changed:\n${CHANGED}\n"
[ -z "$CHANGELOG" ] && CHANGELOG="No notable changes.\n"

POST="<b>DumpC2J | ${KERNEL_VER}</b>
GKI Kernel | Android ${ANDROID_VERSION}

$(printf '%b' "$VAR_LINES")
—
📜 Changelog:
$(printf '%b' "$CHANGELOG")
If you encounter any issues or unexpected behavior, please report them to the DumpC2J discussion group.

#Kernel #GKI #DumpC2J"

if [ "${DEBUG_POST:-0}" == "1" ]; then
  printf '%s\n' "$POST"
  exit 0
fi

SEND=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHANNEL_ID}" \
  -d parse_mode="HTML" \
  --data-urlencode "text=$POST")

if echo "$SEND" | grep -q '"ok":true'; then
  log "Announcement posted to channel."
else
  warn "HTML posting failed, falling back to plain text..."
  echo "$SEND"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHANNEL_ID}" \
    --data-urlencode "text=$POST" > /dev/null
fi