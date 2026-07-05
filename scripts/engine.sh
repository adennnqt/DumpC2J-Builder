#!/usr/bin/env bash
# ======================================================
# Engine — promote candidate kalau build sukses, blacklist kalau gagal
# ======================================================
set -eo pipefail

BUILDER_DIR="${GITHUB_WORKSPACE}/builder"
source "${BUILDER_DIR}/scripts/functions.sh"

BUILD_OUTCOME="$1"   # "success" | "failure"
KEY="$2"              # ex: sukisu_root
PREFIX="$3"           # ex: SUKISU_ROOT

MANIFEST_REL="scripts/checkpoint/manifest.json"
MANIFEST="${BUILDER_DIR}/${MANIFEST_REL}"

candidate_var="CANDIDATE_${PREFIX}"
[ "${!candidate_var:-false}" = "true" ] || { log "engine: no candidate used for ${KEY} — nothing to do"; exit 0; }

[ -n "${GH_TOKEN:-}" ] || error "engine: GH_TOKEN not set — cannot push manifest update"

ref_var="${PREFIX}_REF"
ref="${!ref_var}"

cd "$BUILDER_DIR"
git config user.name  "DumpC2J Bot"
git config user.email "bot@dumpc2j"

REMOTE="https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

apply_and_push() {
    local jq_patch="$1" commit_msg="$2"
    local attempt=1 max_attempts=5

    while [ "$attempt" -le "$max_attempts" ]; do
        run_quiet git fetch "$REMOTE" main
        git reset -q --hard FETCH_HEAD

        jq "$jq_patch" "$MANIFEST" > "${MANIFEST}.tmp" && mv "${MANIFEST}.tmp" "$MANIFEST"

        (
            git add "$MANIFEST_REL"
            git commit -q -m "$commit_msg" 2>/dev/null || { echo "nothing to commit"; exit 0; }
            git push "$REMOTE" "HEAD:main"
        ) && return 0

        warn "engine: push conflict (attempt ${attempt}/${max_attempts}) — retrying..."
        attempt=$(( attempt + 1 ))
        sleep $(( RANDOM % 5 + 2 ))
    done

    error "engine: gagal push manifest setelah ${max_attempts} percobaan"
}

if [ "$BUILD_OUTCOME" = "success" ]; then
    log "engine: promoting ${KEY} pin ke ${ref:0:12}"
    # promote ke good, DAN bersihin SHA ini dari bad[] kalau ada (fix
    # cleanup yang belum ada di versi temen — biar manifest gak nyimpen
    # SHA yang sama di good & bad sekaligus)
    apply_and_push \
      ".${KEY}.good = \"${ref}\" | .${KEY}.bad -= [\"${ref}\"]" \
      "chore: bump ${KEY} pin to ${ref:0:12} (verified via run ${GITHUB_RUN_ID})"
else
    warn "engine: blacklisting ${KEY} candidate ${ref:0:12} (build failed)"
    apply_and_push \
      ".${KEY}.bad |= (. + [\"${ref}\"] | unique)" \
      "chore: mark ${KEY} candidate ${ref:0:12} as known-bad (run ${GITHUB_RUN_ID})"
fi
