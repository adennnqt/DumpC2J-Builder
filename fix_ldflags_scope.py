#!/usr/bin/env python3
import subprocess, sys
from pathlib import Path

REPO_ROOT = Path.cwd()
TARGET = REPO_ROOT / "scripts" / "lib" / "08_build.sh"

OLD = 'KCFLAGS="$KERNEL_KCFLAGS" KBUILD_LDFLAGS="$KERNEL_LDFLAGS" \\'
NEW = 'KCFLAGS="$KERNEL_KCFLAGS" LDFLAGS_vmlinux="$KERNEL_LDFLAGS" \\'

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
    print(f"[+] Patched {TARGET.relative_to(REPO_ROOT)}: KBUILD_LDFLAGS -> LDFLAGS_vmlinux")

    result = subprocess.run(["bash", "-n", str(TARGET)], capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stderr)
        die("bash -n gagal.")
    print("[+] bash -n OK")

    rel = str(TARGET.relative_to(REPO_ROOT))
    subprocess.run(["git", "diff", "--", rel])
    subprocess.run(["git", "add", rel], check=True)
    commit_msg = (
        "fix(lto): scope extra ldflags to LDFLAGS_vmlinux, not KBUILD_LDFLAGS\n\n"
        "KBUILD_LDFLAGS is global and applies to every linker invocation during\n"
        "the build, including intermediate partial/relocatable links (ld -r) used\n"
        "for per-directory built-in.o merging. --icf=all is only valid on the\n"
        "final link and collides with -r, breaking builds like kvm_nvhe.tmp.o,\n"
        "zsmalloc.o, kheaders.o. LDFLAGS_vmlinux is scoped to the final vmlinux\n"
        "link only (see scripts/link-vmlinux.sh), which is the correct target for\n"
        "both --icf=all and --thinlto-cache-dir."
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
