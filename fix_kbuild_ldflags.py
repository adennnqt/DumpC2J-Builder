#!/usr/bin/env python3
import subprocess, sys
from pathlib import Path

REPO_ROOT = Path.cwd()
TARGET = REPO_ROOT / "scripts" / "lib" / "08_build.sh"

OLD = 'LDFLAGS="$KERNEL_LDFLAGS" \\'
NEW = 'KBUILD_LDFLAGS="$KERNEL_LDFLAGS" \\'

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
    print(f"[+] Patched {TARGET.relative_to(REPO_ROOT)}: LDFLAGS -> KBUILD_LDFLAGS")

    result = subprocess.run(["bash", "-n", str(TARGET)], capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stderr)
        die("bash -n gagal.")
    print("[+] bash -n OK")

    rel = str(TARGET.relative_to(REPO_ROOT))
    subprocess.run(["git", "diff", "--", rel])
    subprocess.run(["git", "add", rel], check=True)
    commit_msg = (
        "fix(lto): use KBUILD_LDFLAGS instead of LDFLAGS in 08_build.sh\n\n"
        "The kernel build system (scripts/Makefile.vmlinux, link-vmlinux.sh)\n"
        "reads KBUILD_LDFLAGS and LDFLAGS_vmlinux for the final vmlinux link,\n"
        "not the generic LDFLAGS variable. Passing LDFLAGS= on the make command\n"
        "line was silently ignored, so --icf=all and -Wl,--thinlto-cache-dir\n"
        "never actually reached the linker."
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
