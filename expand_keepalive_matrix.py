#!/usr/bin/env python3
import subprocess, sys
from pathlib import Path

REPO_ROOT = Path.cwd()
TARGET = REPO_ROOT / ".github" / "workflows" / "keep-alive.yml"

OLD = "        clang_variant: [neutron]"
NEW = "        clang_variant: [neutron, cirrus, weebx, zyc]"

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
        die("Marker line gak ketemu (mungkin formatnya beda). Cek manual, isinya harus persis 'clang_variant: [neutron]' dengan indentasi 8 spasi.")

    patched = content.replace(OLD, NEW, 1)
    TARGET.write_text(patched)
    print(f"[+] Patched {TARGET.relative_to(REPO_ROOT)}: matrix expanded ke 4 variant")

    # Validate YAML
    try:
        import yaml
        yaml.safe_load(patched)
        print("[+] YAML valid")
    except ImportError:
        print("[i] pyyaml gak keinstall, skip validasi YAML (visual check aja)")
    except Exception as e:
        print(result if False else "")
        die(f"YAML invalid: {e}")

    rel = str(TARGET.relative_to(REPO_ROOT))
    subprocess.run(["git", "diff", "--", rel])
    subprocess.run(["git", "add", rel], check=True)
    commit_msg = (
        "feat(ci): expand keep-alive matrix to all clang variants\n\n"
        "Previously only neutron was kept alive via actions/cache, so cirrus,\n"
        "weebx, and zyc toolchains always re-downloaded from scratch on every\n"
        "build since their cache entries expired after 7 days of no access."
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
