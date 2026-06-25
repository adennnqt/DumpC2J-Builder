#!/usr/bin/env bash
# setup_nomount.sh — Apply NoMount / ZeroMount patch to kernel source
set -e

KERNEL_DIR="${1:-${GITHUB_WORKSPACE}/kernel-source}"
METHOD="${2:-nomount}"
NAMESPACE_C="$KERNEL_DIR/fs/namespace.c"
FS_KCONFIG="$KERNEL_DIR/fs/Kconfig"

if [ ! -f "$NAMESPACE_C" ]; then
  echo "[!] fs/namespace.c not found"
  exit 1
fi

echo "[*] Applying $METHOD patch..."

# Skip if already patched
if grep -q "KSU_NOMOUNT\|KSU_ZEROMOUNT" "$NAMESPACE_C" 2>/dev/null; then
  echo "[+] Already patched, skipping"
  exit 0
fi

# 1. Inject Kconfig entry ke fs/Kconfig
if [ -f "$FS_KCONFIG" ] && ! grep -q "KSU_NOMOUNT\|KSU_ZEROMOUNT" "$FS_KCONFIG" 2>/dev/null; then
  cat >> "$FS_KCONFIG" << 'KCONFIG_EOF'

config KSU_NOMOUNT
	bool "KernelSU NoMount support"
	depends on KSU
	default n
	help
	  Skip bind mounts for system partitions from init/zygote.
	  Helps bypass mount detection for root hiding.

config KSU_ZEROMOUNT
	bool "KernelSU ZeroMount support"
	depends on KSU
	default n
	help
	  Redirect bind mounts for system partitions to empty tmpfs.
	  Alternative to NoMount with different detection bypass approach.
KCONFIG_EOF
  echo "[+] Kconfig entries added"
fi

# 2. Inject patch ke namespace.c
python3 - "$NAMESPACE_C" "$METHOD" << 'PYEOF'
import sys

path   = sys.argv[1]
method = sys.argv[2]
content = open(path).read()

if method == "nomount":
    helper = r"""
#ifdef CONFIG_KSU_NOMOUNT
static bool ksu_nomount_skip(struct path *path, unsigned long flags)
{
	static const char * const blocked[] = {
		"/system", "/vendor", "/product",
		"/system_ext", "/odm", "/apex", NULL
	};
	const char * const *p;
	char buf[256];
	char *str;

	if (!(flags & MS_BIND))
		return false;

	str = d_path(path, buf, sizeof(buf));
	if (IS_ERR_OR_NULL(str))
		return false;

	for (p = blocked; *p; p++) {
		if (strncmp(str, *p, strlen(*p)) == 0)
			return true;
	}
	return false;
}
#endif /* CONFIG_KSU_NOMOUNT */

"""
    hook = r"""
#ifdef CONFIG_KSU_NOMOUNT
	if (ksu_nomount_skip(path, flags))
		return 0;
#endif
"""
else:
    helper = r"""
#ifdef CONFIG_KSU_ZEROMOUNT
static bool ksu_zeromount_skip(struct path *path, unsigned long flags)
{
	static const char * const blocked[] = {
		"/system", "/vendor", "/product",
		"/system_ext", "/odm", "/apex", NULL
	};
	const char * const *p;
	char buf[256];
	char *str;

	if (!(flags & MS_BIND))
		return false;

	str = d_path(path, buf, sizeof(buf));
	if (IS_ERR_OR_NULL(str))
		return false;

	for (p = blocked; *p; p++) {
		if (strncmp(str, *p, strlen(*p)) == 0)
			return true;
	}
	return false;
}
#endif /* CONFIG_KSU_ZEROMOUNT */

"""
    hook = r"""
#ifdef CONFIG_KSU_ZEROMOUNT
	if (ksu_zeromount_skip(path, flags))
		return 0;
#endif
"""

anchor = 'int path_mount(const char *dev_name, struct path *path,'
if anchor in content and helper not in content:
    content = content.replace(anchor, helper + anchor)
    print("[+] Helper injected")
else:
    print("[!] anchor not found or already patched")
    sys.exit(1)

hook_anchor = '\tif (!may_mount())\n\t\treturn -EPERM;'
if hook_anchor in content and hook not in content:
    content = content.replace(hook_anchor, hook_anchor + hook)
    print("[+] Hook injected")
else:
    print("[!] hook anchor not found")
    sys.exit(1)

open(path, 'w').write(content)
print(f"[+] {method} patch done")
PYEOF

echo "[+] $METHOD applied successfully"
