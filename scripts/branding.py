#!/usr/bin/env python3
import sys
import os
import re
import subprocess

CANDIDATES = ("Kbuild", "Makefile")
ASSIGN_RE = re.compile(r"^\s*KSU_VERSION_FULL\s*[:?]?=")
KSUNEXT_TAG_RE = re.compile(r"^\s*(?:KSU_VERSION_TAG\s*[:?]?=|\$\(eval\s+KSU_VERSION_TAG\s*=)")
KSUNEXT_FALLBACK_RE = re.compile(r"^\s*KSU_VERSION_TAG_FALLBACK\s*[:?]?=")

# Old markers to recognize and replace (idempotency + migration)
OLD_MARKER_RES = (
    re.compile(r"^KSU_VERSION_FULL\s*:=\s*\$\(KSU_VERSION_FULL\)-"),
    re.compile(r"^KSU_VERSION_FULL\s*:=\s*\$\(shell echo.*sed -E.*//'\)\s+\S+$"),
    re.compile(r"^KSU_VERSION_FULL\s*:=\s*\$\(shell echo.*sed -E.*//'\)-[^@]+@"),
    re.compile(r"^KSU_VERSION_TAG\s*:=\s*\$\(KSU_VERSION_TAG\)-"),
    re.compile(r"^KSU_VERSION_TAG_FALLBACK\s*:=\s*\$\(KSU_VERSION_TAG_FALLBACK\)-"),
    # Shell-command format (v1 branding.py output)
    re.compile(r"^KSU_VERSION_FULL\s*:=\s*\$\(shell v='\$\(KSU_VERSION_FULL\)';"),
    re.compile(r"^KSU_VERSION_TAG\s*:=\s*\$\(shell v='\$\(KSU_VERSION_TAG\)';"),
    re.compile(r"^KSU_VERSION_TAG_FALLBACK\s*:=\s*\$\(shell v='\$\(KSU_VERSION_TAG_FALLBACK\)';"),
    # New static format markers
    re.compile(r"^KSU_VERSION_FULL\s*:=\s*v?\d+\.\d+\.\d+(?:-rc\d+)?-[^@]+@"),
    re.compile(r"^KSU_VERSION_TAG\s*:=\s*v?\d+\.\d+\.\d+(?:-rc\d+)?-[^@]+@"),
    re.compile(r"^KSU_VERSION_TAG_FALLBACK\s*:=\s*v?\d+\.\d+\.\d+(?:-rc\d+)?-[^@]+@"),
)

SED_PATTERN = r"s/-[0-9a-f]{7,40}(-dirty)?@.*\$\$//"
VERSION_RE = re.compile(r"^(v?\d+\.\d+\.\d+(?:-rc\d+)?)")


def is_old_marker(line, new_marker_full, new_marker_tag, new_marker_fallback):
    """Check if a line matches any old marker pattern (excluding the new markers)."""
    stripped = line.strip()
    if stripped in (new_marker_full, new_marker_tag, new_marker_fallback):
        return False
    for old_re in OLD_MARKER_RES:
        if old_re.match(stripped):
            return True
    return False


def get_git_version(repo_dir):
    """Extract semantic version from git tags at injection time (CI)."""
    try:
        out = subprocess.check_output(
            ["git", "describe", "--tags", "--always", "--dirty"],
            cwd=repo_dir, stderr=subprocess.DEVNULL, text=True
        ).strip()
        m = VERSION_RE.search(out)
        if m:
            return m.group(1)
    except Exception:
        pass
    return "v0.0.1"


def inject(path, name, owner="who", git_version="v0.0.1"):
    with open(path) as f:
        lines = f.read().split("\n")

    is_kbuild = os.path.basename(path) == "Kbuild"

    if is_kbuild:
        # KernelSU-Next: inject STATIC version (avoid shell command quoting issues)
        # Format: vX.Y.Z-who@DumpC2J (matches Makefile style, parseable by KSU build scripts)
        new_marker_full = f"KSU_VERSION_FULL := {git_version}-{owner}@{name}"
        new_marker_tag = f"KSU_VERSION_TAG := {git_version}-{owner}@{name}"
        new_marker_fallback = f"KSU_VERSION_TAG_FALLBACK := {git_version}-{owner}@{name}"
    else:
        # SukiSU/ReSukiSU (Makefile): static assignment
        new_marker_full = f"KSU_VERSION_FULL := {git_version}-{owner}@{name}"
        new_marker_tag = f"KSU_VERSION_TAG := {git_version}-{owner}@{name}"
        new_marker_fallback = f"KSU_VERSION_TAG_FALLBACK := {git_version}-{owner}@{name}"

    # Check if new markers already exist
    has_new_full = any(l.strip() == new_marker_full for l in lines)
    has_new_tag = any(l.strip() == new_marker_tag for l in lines)
    has_new_fallback = any(l.strip() == new_marker_fallback for l in lines)

    # Find all old marker line indices (excluding the new markers themselves)
    old_marker_indices = [i for i, l in enumerate(lines) if is_old_marker(l, new_marker_full, new_marker_tag, new_marker_fallback)]

    # If all applicable new markers exist and no old markers, skip
    is_kbuild = os.path.basename(path) == "Kbuild"
    full_applicable = not is_kbuild or any(ASSIGN_RE.match(l) for l in lines)
    tag_applicable = is_kbuild and any(KSUNEXT_TAG_RE.match(l) for l in lines)
    fallback_applicable = is_kbuild and any(KSUNEXT_FALLBACK_RE.match(l) for l in lines)

    skip_full = not full_applicable or (has_new_full and not any(i in old_marker_indices for i, l in enumerate(lines) if ASSIGN_RE.match(l) and "$(KSU_VERSION_FULL)" not in l))
    skip_tag = not tag_applicable or (has_new_tag and not any(i in old_marker_indices for i, l in enumerate(lines) if KSUNEXT_TAG_RE.match(l) and "$(KSU_VERSION_TAG)" not in l))
    skip_fallback = not fallback_applicable or (has_new_fallback and not any(i in old_marker_indices for i, l in enumerate(lines) if KSUNEXT_FALLBACK_RE.match(l) and "$(KSU_VERSION_TAG_FALLBACK)" not in l))

    if (not full_applicable or skip_full) and (not tag_applicable or skip_tag) and (not fallback_applicable or skip_fallback) and not old_marker_indices:
        print(f"[branding] {path}: '{owner}@{name}' already injected, skipping.")
        return True

    count = 0
    i = 0
    out = []

    # Track if we've injected each marker
    injected_full = False
    injected_tag = False
    injected_fallback = False

    while i < len(lines):
        line = lines[i]

        # Skip old marker lines
        if i in old_marker_indices:
            i += 1
            continue

        out.append(line)

        # Inject KSU_VERSION_FULL marker
        if not injected_full:
            if ASSIGN_RE.match(line) and "$(KSU_VERSION_FULL)" not in line:
                while out[-1].rstrip().endswith("\\") and i + 1 < len(lines):
                    i += 1
                    out.append(lines[i])
                indent = re.match(r"^\s*", line).group(0)
                out.append(indent + new_marker_full)
                count += 1
                injected_full = True

        # Inject KSU_VERSION_TAG marker (Kbuild only)
        if is_kbuild and not injected_tag:
            if KSUNEXT_TAG_RE.match(line) and "$(KSU_VERSION_TAG)" not in line:
                while out[-1].rstrip().endswith("\\") and i + 1 < len(lines):
                    i += 1
                    out.append(lines[i])
                indent = re.match(r"^\s*", line).group(0)
                out.append(indent + new_marker_tag)
                count += 1
                injected_tag = True

        # Inject KSU_VERSION_TAG_FALLBACK marker (Kbuild only)
        if is_kbuild and not injected_fallback:
            if KSUNEXT_FALLBACK_RE.match(line) and "$(KSU_VERSION_TAG_FALLBACK)" not in line:
                while out[-1].rstrip().endswith("\\") and i + 1 < len(lines):
                    i += 1
                    out.append(lines[i])
                indent = re.match(r"^\s*", line).group(0)
                out.append(indent + new_marker_fallback)
                count += 1
                injected_fallback = True

        i += 1

    # If we were replacing old markers but didn't inject (e.g., no assignment found),
    # append the missing markers at the end
    if old_marker_indices and count == 0:
        if full_applicable and not injected_full:
            out.append(new_marker_full)
            count += 1
        if tag_applicable and not injected_tag:
            out.append(new_marker_tag)
            count += 1
        if fallback_applicable and not injected_fallback:
            out.append(new_marker_fallback)
            count += 1

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
        repo_dir = target
        files = [os.path.join(target, c) for c in CANDIDATES]
    else:
        repo_dir = os.path.dirname(target)
        files = [target]
    files = [p for p in files if os.path.isfile(p)]

    if not files:
        print(f"[branding] no Kbuild/Makefile found in {target}, skipping.")
        sys.exit(0)

    git_version = get_git_version(repo_dir)

    results = [inject(p, name, owner, git_version) for p in files]
    if any(results):
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