#!/usr/bin/env python3
import sys
import os
import re

CANDIDATES = ("Kbuild", "Makefile")
ASSIGN_RE = re.compile(r"^\s*KSU_VERSION_FULL\s*[:?]?=")
KSUNEXT_TAG_RE = re.compile(r"^\s*(?:KSU_VERSION_TAG\s*[:?]?=|\$\(eval\s+KSU_VERSION_TAG\s*=)")
KSUNEXT_FALLBACK_RE = re.compile(r"^\s*KSU_VERSION_TAG_FALLBACK\s*[:?]?=")

# Old markers to recognize and replace (idempotency + migration)
# These match loosely to handle variations in escaping
OLD_MARKER_RES = (
    re.compile(r"^KSU_VERSION_FULL\s*:=\s*\$\(KSU_VERSION_FULL\)-"),
    re.compile(r"^KSU_VERSION_FULL\s*:=\s*\$\(shell echo.*sed -E.*//'\)\s+\S+$"),
    re.compile(r"^KSU_VERSION_FULL\s*:=\s*\$\(shell echo.*sed -E.*//'\)-[^@]+@"),
)

SED_PATTERN = r"s/-[0-9a-f]{7,40}(-dirty)?@.*\$\$//"


def is_old_marker(line, new_marker):
    """Check if a line matches any old marker pattern (excluding the new_marker)."""
    stripped = line.strip()
    if stripped == new_marker:
        return False
    for old_re in OLD_MARKER_RES:
        if old_re.match(stripped):
            return True
    return False


def inject(path, name, owner="who"):
    with open(path) as f:
        lines = f.read().split("\n")

    new_marker = f"KSU_VERSION_FULL := $(shell echo '$(KSU_VERSION_FULL)' | sed -E '{SED_PATTERN}')-{owner}@{name}"

    # Check if new marker already exists
    has_new_marker = any(l.strip() == new_marker for l in lines)

    # Find all old marker line indices (excluding the new marker itself)
    old_marker_indices = [i for i, l in enumerate(lines) if is_old_marker(l, new_marker)]

    # If new marker exists and no old markers, skip
    if has_new_marker and not old_marker_indices:
        print(f"[branding] {path}: '{owner}@{name}' already injected, skipping.")
        return True

    is_kbuild = os.path.basename(path) == "Kbuild"
    count = 0
    i = 0
    out = []

    # Track if we've injected the new marker
    injected_new = False

    while i < len(lines):
        line = lines[i]

        # Skip old marker lines
        if i in old_marker_indices:
            i += 1
            continue

        out.append(line)

        # Inject new marker after the original KSU_VERSION_FULL assignment
        if not injected_new:
            if ASSIGN_RE.match(line) and "$(KSU_VERSION_FULL)" not in line:
                while out[-1].rstrip().endswith("\\") and i + 1 < len(lines):
                    i += 1
                    out.append(lines[i])
                indent = re.match(r"^\s*", line).group(0)
                out.append(indent + new_marker)
                count += 1
                injected_new = True

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

    # If we were replacing old markers but didn't inject (e.g., no assignment found),
    # append the new marker at the end
    if old_marker_indices and not injected_new and count == 0:
        out.append(new_marker)
        count = 1

    if not count:
        return False

    with open(path, "w") as f:
        f.write("\n".join(out))
    action = "replaced" if old_marker_indices else "injected"
    print(f"[branding] {path}: {action} '{owner}@{name}' after {count} assignment(s)")
    return True


def main():
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        print("Usage: branding.py <ksu_kernel_dir | file> <name> [owner]")
        sys.exit(0)

    target = sys.argv[1]
    name = sys.argv[2]
    owner = sys.argv[3] if len(sys.argv) == 4 else "who"

    if os.path.isdir(target):
        files = [os.path.join(target, c) for c in CANDIDATES]
    else:
        files = [target]
    files = [p for p in files if os.path.isfile(p)]

    if not files:
        print(f"[branding] no Kbuild/Makefile found in {target}, skipping.")
        sys.exit(0)

    if any(inject(p, name, owner) for p in files):
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