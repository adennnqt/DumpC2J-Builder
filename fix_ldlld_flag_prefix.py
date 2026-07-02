#!/usr/bin/env python3
import subprocess, sys
from pathlib import Path

REPO_ROOT = Path.cwd()
TARGET = REPO_ROOT / "scripts" / "lib" / "07_thinlto_setup.sh"

OLD = 'KERNEL_LDFLAGS="$KERNEL_LDFLAGS -Wl,--thinlto-cache-dir=${THINLTO_CACHE_DIR}"'
NEW = 'KERNEL_LDFLAGS="$KERNEL_LDFLAGS --thinlto-cache-dir=${THINLTO_CACHE_DIR}"'

def die(msg):
    print(f"[!] {msg}")
    sys.exit(1)

def main():
    if not TARGET.exists():
        die(f"Gak ketemu {TARGET}")

    content = TARGET.read_text()
    if NEW in content:
        print("[=] Udah dipatch sebelumnya, skip.")
        return
    if OLD not in content:
        die("Marker line gak ketemu, struktur file berubah. Cek manual.")

    patched = content.replace(OLD, NEW, 1)
    TARGET.write_text(patched)
    print(f"[+] Patched {TARGET.relative_to(REPO_ROOT)}: hapus prefix -Wl,")

    result = subprocess.run(["bash", "-n", str(TARGET)], capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stderr)
        die("bash -n gagal.")
    print("[+] bash -n OK")

    rel = str(TARGET.relative_to(REPO_ROOT))
    subprocess.run(["git", "diff", "--", rel])
    subprocess.run(["git", "add", rel], check=True)
    commit_msg = (
        "fix(lto): drop -Wl, prefix from --thinlto-cache-dir\n\n"
        "KBUILD_LDFLAGS is passed straight to ld.lld by scripts/link-vmlinux.sh\n"
        "(not routed through the clang driver), so the -Wl, wrapper syntax is\n"
        "invalid here and ld.lld rejected it as an unknown argument, failing\n"
        "the build entirely."
    )
    subprocess.run(["git", "commit", "-m", commit_msg], check=True)
    print("[+] Committed.")

    push = input("[?] Push ke remote sekarang? (y/n): ").strip().lower()
    if push == "y":
        subprocess.run(["git", "push"], check=True)
        print("[+] Pushed.")
    else:
        print("[i] Belum di-push.")

if __name__ == "__main__":
    main()
