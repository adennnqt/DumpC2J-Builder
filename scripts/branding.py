#!/usr/bin/env python3
import sys
import os
import re

CANDIDATES = ("Kbuild", "Makefile")
ASSIGN_RE = re.compile(r"^\s*KSU_VERSION_FULL\s*[:?]?=")


def inject(path, name):
    marker = f"KSU_VERSION_FULL := $(KSU_VERSION_FULL)-{name}"
    with open(path) as f:
        lines = f.read().split("\n")

    if any(l.strip() == marker for l in lines):
        print(f"[branding] {path}: '{name}' already injected, skipping.")
        return True

    out, count, i = [], 0, 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        if ASSIGN_RE.match(line) and "$(KSU_VERSION_FULL)" not in line:
            while out[-1].rstrip().endswith("\\") and i + 1 < len(lines):
                i += 1
                out.append(lines[i])
            indent = re.match(r"^\s*", line).group(0)
            out.append(indent + marker)
            count += 1
        i += 1

    if not count:
        return False

    with open(path, "w") as f:
        f.write("\n".join(out))
    print(f"[branding] {path}: injected '{name}' after {count} KSU_VERSION_FULL assignment(s)")
    return True


def main():
    if len(sys.argv) != 3:
        print("Usage: branding.py <ksu_kernel_dir | file> <name>")
        sys.exit(0)

    target, name = sys.argv[1], sys.argv[2]
    if os.path.isdir(target):
        files = [os.path.join(target, c) for c in CANDIDATES]
    else:
        files = [target]
    files = [p for p in files if os.path.isfile(p)]

    if not files:
        print(f"[branding] no Kbuild/Makefile found in {target}, skipping.")
        sys.exit(0)

    if any(inject(p, name) for p in files):
        sys.exit(0)

    print("[branding] KSU_VERSION_FULL not assigned in any candidate file, skipping. Version-related lines:")
    for p in files:
        with open(p) as f:
            for n, l in enumerate(f, 1):
                if re.search(r"VERSION|@\$\(|-dirty|describe", l):
                    print(f"  {p}:{n}: {l.rstrip()}")
    sys.exit(0)


if __name__ == "__main__":
    main()