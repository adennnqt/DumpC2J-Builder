#!/usr/bin/env python3
import sys
import os

def main():
    if len(sys.argv) != 3:
        print("Usage: branding.py <path_to_makefile> <custom_name>")
        sys.exit(0)

    makefile_path, custom_name = sys.argv[1], sys.argv[2]

    if not os.path.isfile(makefile_path):
        print(f"[branding] Makefile not found at {makefile_path}, skipping.")
        sys.exit(0)

    with open(makefile_path) as f:
        content = f.read()

    marker = f"KSU_VERSION_FULL := $(KSU_VERSION_FULL) {custom_name}"

    if marker in content:
        print(f"[branding] '{custom_name}' already injected, skipping.")
        sys.exit(0)

    lines = content.split("\n")
    out_lines = []
    injected = False
    for line in lines:
        out_lines.append(line)
        if not injected and line.strip().startswith("KSU_VERSION_FULL :=") and "$(KSU_VERSION_FULL)" not in line:
            out_lines.append(marker)
            injected = True

    if not injected:
        print("[branding] Original KSU_VERSION_FULL line not found, skipping.")
        sys.exit(0)

    with open(makefile_path, "w") as f:
        f.write("\n".join(out_lines))

    print(f"[branding] Injected '{custom_name}' into {makefile_path}")

if __name__ == "__main__":
    main()
