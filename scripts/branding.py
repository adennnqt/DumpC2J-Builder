#!/usr/bin/env python3
import sys
import os
import re

CANDIDATES = ("Kbuild", "Makefile")
ASSIGN_RE = re.compile(r"^\s*KSU_VERSION_FULL\s*[:?]?=")
# Match both direct assignment (KSU_VERSION_TAG := ...) and eval form ($(eval KSU_VERSION_TAG=...))
KSUNEXT_TAG_RE = re.compile(r"^\s*(?:KSU_VERSION_TAG\s*[:?]?=|\$\(eval\s+KSU_VERSION_TAG\s*=)")
# Match fallback assignment in else branch
KSUNEXT_FALLBACK_RE = re.compile(r"^\s*KSU_VERSION_TAG_FALLBACK\s*[:?]?=")


def inject(path, name):
    with open(path) as f:
        lines = f.read().split("\n")

    # Check if already injected (idempotency)
    ksu_marker = f"KSU_VERSION_FULL := $(KSU_VERSION_FULL)-{name}"
    ksunext_marker = f"KSU_VERSION_TAG := $(KSU_VERSION_TAG)-{name}"
    ksunext_fallback_marker = f"KSU_VERSION_TAG_FALLBACK := $(KSU_VERSION_TAG_FALLBACK)-{name}"
    if any(l.strip() == ksu_marker or l.strip() == ksunext_marker or l.strip() == ksunext_fallback_marker for l in lines):
        print(f"[branding] {path}: '{name}' already injected, skipping.")
        return True

    is_kbuild = os.path.basename(path) == "Kbuild"
    count = 0
    i = 0
    out = []

    while i < len(lines):
        line = lines[i]
        out.append(line)

        if ASSIGN_RE.match(line) and "$(KSU_VERSION_FULL)" not in line:
            while out[-1].rstrip().endswith("\\") and i + 1 < len(lines):
                i += 1
                out.append(lines[i])
            indent = re.match(r"^\s*", line).group(0)
            marker = f"KSU_VERSION_FULL := $(KSU_VERSION_FULL)-{name}"
            out.append(indent + marker)
            count += 1

        elif is_kbuild and KSUNEXT_TAG_RE.match(line) and "$(KSU_VERSION_TAG)" not in line:
            while out[-1].rstrip().endswith("\\") and i + 1 < len(lines):
                i += 1
                out.append(lines[i])
            indent = re.match(r"^\s*", line).group(0)
            marker = f"KSU_VERSION_TAG := $(KSU_VERSION_TAG)-{name}"
            out.append(indent + marker)
            count += 1

        elif is_kbuild and KSUNEXT_FALLBACK_RE.match(line) and "$(KSU_VERSION_TAG_FALLBACK)" not in line:
            while out[-1].rstrip().endswith("\\") and i + 1 < len(lines):
                i += 1
                out.append(lines[i])
            indent = re.match(r"^\s*", line).group(0)
            marker = f"KSU_VERSION_TAG_FALLBACK := $(KSU_VERSION_TAG_FALLBACK)-{name}"
            out.append(indent + marker)
            count += 1

        i += 1

    if not count:
        return False

    with open(path, "w") as f:
        f.write("\n".join(out))
    print(f"[branding] {path}: injected '{name}' after {count} assignment(s)")
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
                if re.search(r"VERSION|@\$\(|-dirty|describe|KSU_VERSION_TAG", l):
                    print(f"  {p}:{n}: {l.rstrip()}")
    sys.exit(0)


if __name__ == "__main__":
    main()