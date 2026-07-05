#!/usr/bin/env bash
# ======================================================
# Scout — checkpoint recon buat DumpC2J (root + susfs per method)
# ======================================================
# RUN_MODE=Release: selalu pake pin manifest, gak pernah cek upstream.
# RUN_MODE=Test/Warming: cek commit terbaru upstream, kalau beda dari
#   pin dan belum di-blacklist, jadi candidate buat run ini.
set -eo pipefail

BUILDER_DIR="${GITHUB_WORKSPACE}/builder"
source "${BUILDER_DIR}/scripts/functions.sh"

MANIFEST="${BUILDER_DIR}/scripts/checkpoint/manifest.json"
[ -f "$MANIFEST" ] || error "scout: manifest.json not found at ${MANIFEST}"

RUN_MODE="${RUN_MODE:-Test}"

latest_sha_or_empty() {
    local label="$1" url="$2" jq_filter="$3"
    local body_file http_code curl_exit sha

    body_file="$(mktemp)"
    if http_code=$(curl -sL -o "$body_file" -w '%{http_code}' --max-time 20 "$url"); then
        curl_exit=0
    else
        curl_exit=$?
    fi

    if [ "$curl_exit" -ne 0 ] || [ "$http_code" != "200" ]; then
        warn "scout: couldn't reach upstream for ${label} (curl exit ${curl_exit}, HTTP ${http_code:-000}) — using pinned ref"
        rm -f "$body_file"; echo ""; return 0
    fi

    sha=$(jq -r "$jq_filter" "$body_file" 2>/dev/null)
    rm -f "$body_file"
    if [ -z "$sha" ] || [ "$sha" = "null" ]; then
        warn "scout: couldn't parse latest ${label} commit — using pinned ref"
        echo ""; return 0
    fi
    echo "$sha"
}

resolve_component() {
    local key="$1" prefix="$2" latest="$3"
    local good bad_list is_bad ref candidate

    good=$(jq -r ".${key}.good" "$MANIFEST")
    bad_list=$(jq -c ".${key}.bad" "$MANIFEST")

    if [ "${RUN_MODE^^}" = "RELEASE" ]; then
        [ -n "$good" ] || error "scout: RUN_MODE=Release tapi belum ada pin ${key} — run Test dulu."
        ref="$good"; candidate="false"
        log "${prefix}: Release mode — pinned ${ref:0:12}"
    elif [ -z "$latest" ]; then
        ref="$good"; candidate="false"
        log "${prefix}: no candidate — pakai pinned ${good:-none}"
    elif [ "$latest" = "$good" ]; then
        ref="$good"; candidate="false"
        log "${prefix}: up to date at ${good:0:12}"
    else
        is_bad=$(echo "$bad_list" | jq --arg sha "$latest" 'any(. == $sha)')
        if [ "$is_bad" = "true" ]; then
            if [ -n "$good" ]; then
                ref="$good"; candidate="false"
                warn "${prefix}: latest ${latest:0:12} known-bad — fallback ke pinned ${good:0:12}"
            else
                # deadlock-breaker: belum ada good pin & satu-satunya ref upstream
                # udah di-blacklist -> retry sbg last-resort candidate biar bisa
                # promote/re-blacklist berdasar hasil build nyata.
                ref="$latest"; candidate="true"
                warn "${prefix}: latest ${latest:0:12} known-bad & belum ada pin — retry sbg last-resort candidate"
            fi
        else
            ref="$latest"; candidate="true"
            log "${prefix}: candidate baru ${latest:0:12} (pinned: ${good:-none})"
        fi
    fi

    echo "${prefix}_REF=${ref}" >> "$GITHUB_ENV"
    echo "CANDIDATE_${prefix}=${candidate}" >> "$GITHUB_ENV"
}

# ROOT dan VARIANT diambil dari env yang udah di-set 00_defaults.sh/01_adjust_inputs.sh
case "$ROOT" in
  sukisu)
    if [ "$VARIANT" == "susfs" ]; then
      latest=$(latest_sha_or_empty "SukiSU-Ultra (builtin)" \
        "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/commits/builtin" '.sha')
      resolve_component "sukisu_susfs" "SUKISU_SUSFS" "$latest"
    else
      latest=$(latest_sha_or_empty "SukiSU-Ultra (main)" \
        "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/commits/main" '.sha')
      resolve_component "sukisu_root" "SUKISU_ROOT" "$latest"
    fi
    ;;
  resukisu)
    latest=$(latest_sha_or_empty "ReSukiSU (main)" \
      "https://api.github.com/repos/ReSukiSU/ReSukiSU/commits/main" '.sha')
    if [ "$VARIANT" == "susfs" ]; then
      resolve_component "resukisu_susfs" "RESUKISU_SUSFS" "$latest"
    else
      resolve_component "resukisu_root" "RESUKISU_ROOT" "$latest"
    fi
    ;;
  ksu-next)
    if [ "$VARIANT" == "susfs" ]; then
      latest=$(latest_sha_or_empty "KernelSU-Next (dev)" \
        "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/commits/dev" '.sha')
      resolve_component "ksunext_susfs" "KSUNEXT_SUSFS" "$latest"
    else
      latest=$(latest_sha_or_empty "KernelSU-Next (dev)" \
        "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/commits/dev" '.sha')
      resolve_component "ksunext_root" "KSUNEXT_ROOT" "$latest"
    fi
    ;;
  kowsu)
    if [ "$VARIANT" == "susfs" ]; then
      latest=$(latest_sha_or_empty "KOWX712-KernelSU (master)" \
        "https://api.github.com/repos/KOWX712/KernelSU/commits/master" '.sha')
      resolve_component "kowsu_susfs" "KOWSU_SUSFS" "$latest"
    else
      latest=$(latest_sha_or_empty "KOWX712-KernelSU (master)" \
        "https://api.github.com/repos/KOWX712/KernelSU/commits/master" '.sha')
      resolve_component "kowsu_root" "KOWSU_ROOT" "$latest"
    fi
    ;;
  *)
    log "scout: ROOT=none — nothing to track"
    ;;
esac

# SUSFS patch source (GitLab simonpunk/susfs4ksu) — shared dependency
# dipake semua root method pas VARIANT=susfs, di-track independen lewat
# key manifest sendiri biar dapet proteksi pin/candidate/blacklist yang
# sama kayak repo KernelSU fork di atas.
if [ "$VARIANT" == "susfs" ]; then
  latest=$(latest_sha_or_empty "SuSFS (susfs4ksu, GitLab)" \
    "https://gitlab.com/api/v4/projects/simonpunk%2Fsusfs4ksu/repository/commits/gki-android15-6.6-dev" '.id')
  resolve_component "susfs4ksu" "SUSFS4KSU" "$latest"
fi
