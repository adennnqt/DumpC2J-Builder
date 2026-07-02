#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path.cwd()
SETUP = REPO_ROOT / "scripts" / "lib" / "07_thinlto_setup.sh"
SAVE = REPO_ROOT / "scripts" / "lib" / "09_thinlto_save.sh"

SETUP_CONTENT = '''#!/bin/bash
set -e

# Thin LTO cache cuma relevan kalau LTO_VAL bukan full/none
if [ "$LTO_VAL" == "full" ] || [ "$LTO_VAL" == "none" ]; then
  echo "[i] LTO_VAL=$LTO_VAL, skip thinlto cache setup"
  return 0 2>/dev/null || exit 0
fi

THINLTO_CACHE_DIR="${GITHUB_WORKSPACE}/.thinlto-cache"
THINLTO_ASSET="thinlto-${ACTUAL_ROOT}-${CLANG_VARIANT}.tar.zst"
THINLTO_TAG="ccache-store"
THINLTO_REPO="adennnqt/DumpC2J-Builder"

mkdir -p "$THINLTO_CACHE_DIR"

echo "[+] thinlto asset target: ${THINLTO_ASSET}"

if gh release download "$THINLTO_TAG" \\
    -p "$THINLTO_ASSET" \\
    -D /tmp \\
    -R "$THINLTO_REPO" \\
    --clobber 2>/dev/null; then
  echo "[+] ThinLTO cache ditemukan, extracting..."
  tar --use-compress-program=unzstd -xf "/tmp/${THINLTO_ASSET}" -C "${GITHUB_WORKSPACE}"
  rm -f "/tmp/${THINLTO_ASSET}"
else
  echo "[!] Belum ada ThinLTO cache untuk ${THINLTO_ASSET}, mulai fresh"
fi

# Nempel ke LDFLAGS yang udah di-set 06_clang_flags.sh
# (aman: semua lib/*.sh disource dalam 1 proses shell yang sama)
KERNEL_LDFLAGS="$KERNEL_LDFLAGS -Wl,--thinlto-cache-dir=${THINLTO_CACHE_DIR}"

echo "THINLTO_ASSET=${THINLTO_ASSET}" >> "$GITHUB_ENV"
echo "THINLTO_TAG=${THINLTO_TAG}" >> "$GITHUB_ENV"
echo "THINLTO_REPO=${THINLTO_REPO}" >> "$GITHUB_ENV"
echo "THINLTO_CACHE_DIR=${THINLTO_CACHE_DIR}" >> "$GITHUB_ENV"

echo "[+] ThinLTO cache ready — dir: ${THINLTO_CACHE_DIR}"
'''

SAVE_CONTENT = '''#!/bin/bash
set -e

if [ "$LTO_VAL" == "full" ] || [ "$LTO_VAL" == "none" ]; then
  echo "[i] LTO_VAL=$LTO_VAL, skip thinlto cache save"
  return 0 2>/dev/null || exit 0
fi

if [ -z "$THINLTO_CACHE_DIR" ] || [ ! -d "$THINLTO_CACHE_DIR" ]; then
  echo "[!] THINLTO_CACHE_DIR gak ketemu/kosong, skip save"
  return 0 2>/dev/null || exit 0
fi

echo "[+] ThinLTO cache size:"
du -sh "$THINLTO_CACHE_DIR" || true

cd "$GITHUB_WORKSPACE"
tar --use-compress-program=zstd -cf "/tmp/${THINLTO_ASSET}" "$(basename "$THINLTO_CACHE_DIR")"

ARCHIVE_SIZE_MB=$(du -m "/tmp/${THINLTO_ASSET}" | cut -f1)
echo "[+] ThinLTO archive size: ${ARCHIVE_SIZE_MB} MB"

if [ "$ARCHIVE_SIZE_MB" -gt 2000 ]; then
  echo "[!] ThinLTO archive > 2000MB, skip upload (kemungkinan kena limit release asset)"
  return 0 2>/dev/null || exit 0
fi

if ! gh release view "$THINLTO_TAG" -R "$THINLTO_REPO" >/dev/null 2>&1; then
  echo "[+] Release ${THINLTO_TAG} belum ada, membuat..."
  gh release create "$THINLTO_TAG" -R "$THINLTO_REPO" --prerelease --title "$THINLTO_TAG" --notes "cache store"
fi

gh release upload "$THINLTO_TAG" "/tmp/${THINLTO_ASSET}" -R "$THINLTO_REPO" --clobber

echo "[+] ThinLTO uploaded as ${THINLTO_ASSET}"
'''


def die(msg):
    print(f"[!] {msg}")
    sys.exit(1)


def main():
    if not (REPO_ROOT / "scripts" / "lib" / "07_kconfig.sh").exists():
        die("Gak ketemu scripts/lib/07_kconfig.sh. Run dari root repo DumpC2J-Builder.")

    if SETUP.exists() or SAVE.exists():
        die(f"{SETUP.name} atau {SAVE.name} udah ada. Cek manual, jangan ketimpa.")

    SETUP.write_text(SETUP_CONTENT)
    SETUP.chmod(0o755)
    print(f"[+] Created {SETUP.relative_to(REPO_ROOT)}")

    SAVE.write_text(SAVE_CONTENT)
    SAVE.chmod(0o755)
    print(f"[+] Created {SAVE.relative_to(REPO_ROOT)}")

    for f in (SETUP, SAVE):
        result = subprocess.run(["bash", "-n", str(f)], capture_output=True, text=True)
        if result.returncode != 0:
            print(result.stderr)
            die(f"bash -n gagal di {f.name}, cek syntax.")
    print("[+] bash -n OK untuk kedua file")

    rel_paths = [str(f.relative_to(REPO_ROOT)) for f in (SETUP, SAVE)]
    subprocess.run(["git", "add"] + rel_paths, check=True)
    commit_msg = (
        "feat(lto): add ThinLTO backend cache via release asset\n\n"
        "Adds scripts/lib/07_thinlto_setup.sh and 09_thinlto_save.sh, mirroring\n"
        "the existing ccache-ECS pattern. Enables ld.lld --thinlto-cache-dir so\n"
        "ThinLTO backend object files persist across runs instead of being\n"
        "regenerated from scratch every build. Skipped entirely for full/none LTO."
    )
    subprocess.run(["git", "commit", "-m", commit_msg], check=True)
    print("[+] Committed.")

    push = input("[?] Push ke remote sekarang? (y/n): ").strip().lower()
    if push == "y":
        subprocess.run(["git", "push"], check=True)
        print("[+] Pushed.")
    else:
        print("[i] Belum di-push, run `git push` manual kalau udah siap.")


if __name__ == "__main__":
    main()
