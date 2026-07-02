#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path.cwd()
TARGET = REPO_ROOT / "scripts" / "setup_clang.sh"

MARKER = 'echo "CLANG_PATH=${CLANG_BIN}" >> "${GITHUB_ENV}"'
INSERT = 'echo "CLANG_VARIANT=${CLANG_VARIANT}" >> "${GITHUB_ENV}"\n'


def die(msg):
    print(f"[!] {msg}")
    sys.exit(1)


def main():
    if not TARGET.exists():
        die(f"Gak ketemu {TARGET}. Pastiin lo run script ini dari root repo DumpC2J-Builder.")

    content = TARGET.read_text()

    if 'echo "CLANG_VARIANT=${CLANG_VARIANT}" >> "${GITHUB_ENV}"' in content:
        print("[=] CLANG_VARIANT udah di-export, gak ada yang perlu dipatch. Skip.")
        return

    if MARKER not in content:
        die(f"Marker line gak ketemu di {TARGET}, struktur file mungkin udah berubah. Cek manual.")

    patched = content.replace(MARKER, INSERT + MARKER, 1)
    TARGET.write_text(patched)
    print(f"[+] Patched {TARGET}: nambahin export CLANG_VARIANT ke GITHUB_ENV")

    result = subprocess.run(["bash", "-n", str(TARGET)], capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stderr)
        die("bash -n gagal, revert manual & cek syntax.")
    print("[+] bash -n OK, syntax valid")

    subprocess.run(["git", "diff", "--", str(TARGET.relative_to(REPO_ROOT))])

    subprocess.run(["git", "add", str(TARGET.relative_to(REPO_ROOT))], check=True)
    commit_msg = (
        "fix(ccache): export CLANG_VARIANT to GITHUB_ENV in setup_clang.sh\n\n"
        "CLANG_VARIANT was only a local var inside setup_clang.sh and never\n"
        "propagated via GITHUB_ENV, so 07_ccache_setup.sh (sourced later in the\n"
        "Build Kernel step) read it as empty. This caused every clang variant to\n"
        "collide onto the same ccache asset name (ccache-<root>-.tar.zst),\n"
        "corrupting/overwriting the cache across different toolchains."
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
