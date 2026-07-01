# === 1. build.sh: export KERNEL_VER biar bisa dipake step lain ===
sh_path = "scripts/build.sh"
with open(sh_path, "r") as f:
    sh = f.read()

old_sh = '''KERNEL_VER="${KVER}.${KPL}.${KSL}"

ZIP_NAME="anykern3-DumpC2J-${KERNEL_VER}-${TIME}.zip"'''

new_sh = '''KERNEL_VER="${KVER}.${KPL}.${KSL}"
echo "KERNEL_VER=$KERNEL_VER" >> "$GITHUB_ENV"

ZIP_NAME="anykern3-DumpC2J-${KERNEL_VER}-${TIME}.zip"'''

if old_sh not in sh:
    print("[-] build.sh: blok KERNEL_VER tidak ditemukan!")
else:
    sh = sh.replace(old_sh, new_sh)
    with open(sh_path, "w") as f:
        f.write(sh)
    print("[+] build.sh updated")

# === 2. Buat file scripts/notify_telegram.sh ===
notify_script = '''#!/bin/bash
set -e

KERNEL_DIR="${GITHUB_WORKSPACE}/kernel-source"
cd "$KERNEL_DIR"

git fetch origin --tags 2>/dev/null || true

TAG_NAME="dumpc2j-last-notified"

if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
  CHANGELOG=$(git log "${TAG_NAME}..HEAD" --no-merges --pretty=format:"%s" | grep -vi '\\[ci\\]' || true)
else
  CHANGELOG=$(git log -10 --no-merges --pretty=format:"%s" | grep -vi '\\[ci\\]' || true)
fi

if [ -z "$CHANGELOG" ]; then
  CHANGELOG_TEXT="No kernel changes since last build."
else
  CHANGELOG_TEXT=$(echo "$CHANGELOG" | sed 's/^/- /')
fi

MESSAGE="🔧 *DumpC2J Kernel Build*
Version: \\`${KERNEL_VER}\\`
Variant: ${ACTUAL_ROOT:-stock} | HZ: ${HZ_ID} | LTO: ${LTO_ACTUAL}
Clang: ${KBUILD_COMPILER_STRING}

*Changes:*
${CHANGELOG_TEXT}

📦 File: \\`${ZIP_NAME}\\`"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \\
  -d chat_id="${TELEGRAM_CHAT_ID}" \\
  -d parse_mode="Markdown" \\
  --data-urlencode text="$MESSAGE" > /dev/null

git tag -f "$TAG_NAME"
git push origin "$TAG_NAME" --force 2>/dev/null || echo "[!] Gagal push tag (cek GH_TOKEN)"
'''

with open("scripts/notify_telegram.sh", "w") as f:
    f.write(notify_script)
print("[+] scripts/notify_telegram.sh created")

# === 3. Edit build.yml: tambah step Notify Telegram + perbesar depth clone ===
yml_path = ".github/workflows/build.yml"
with open(yml_path, "r") as f:
    yml = f.read()

old_clone = '''          git clone --depth=1 \\
            --branch main \\
            https://${{ secrets.GH_TOKEN }}@github.com/adennnqt/DumpC2J-Kernel \\
            kernel-source'''
new_clone = '''          git clone --depth=50 \\
            --branch main \\
            https://${{ secrets.GH_TOKEN }}@github.com/adennnqt/DumpC2J-Kernel \\
            kernel-source'''

if old_clone not in yml:
    print("[-] build.yml: clone command tidak ditemukan!")
else:
    yml = yml.replace(old_clone, new_clone)

old_step = '''      - name: Set LTO Output
        id: lto_output
        run: echo "lto_actual=${{ env.LTO_ACTUAL }}" >> "$GITHUB_OUTPUT"'''
new_step = '''      - name: Set LTO Output
        id: lto_output
        run: echo "lto_actual=${{ env.LTO_ACTUAL }}" >> "$GITHUB_OUTPUT"

      - name: Notify Telegram
        if: success()
        env:
          TELEGRAM_TOKEN: ${{ secrets.TELEGRAM_TOKEN }}
          TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}
        run: bash builder/scripts/notify_telegram.sh'''

if old_step not in yml:
    print("[-] build.yml: step lto_output tidak ditemukan!")
else:
    yml = yml.replace(old_step, new_step)

with open(yml_path, "w") as f:
    f.write(yml)
print("[+] build.yml updated")
