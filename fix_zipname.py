path = "scripts/build.sh"

with open(path, "r") as f:
    content = f.read()

old_block = '''# Build zip name
# Variant label (hanya tulis kalau bukan stock)
VARIANT_LABEL=""
case "$VARIANT" in
  root)  VARIANT_LABEL="-root-${ACTUAL_ROOT}" ;;
  susfs) VARIANT_LABEL="-susfs-${ACTUAL_ROOT}" ;;
esac

# Optional features (hanya tulis kalau aktif)
OPT_LABEL=""
[ "$KPM" == "on" ]          && OPT_LABEL="${OPT_LABEL}-kpm"
[ "$HARDENED" == "on" ]     && OPT_LABEL="${OPT_LABEL}-hardened"
[ "$BYPASSCHARGING" == "on" ] && OPT_LABEL="${OPT_LABEL}-bypasscharging"
[ "$DROIDSPACES" == "on" ]  && OPT_LABEL="${OPT_LABEL}-droidspaces"
[ "$HTSR" == "off" ]        && OPT_LABEL="${OPT_LABEL}-nohtsr"
[ "$WIFI_EXPLOIT" == "off" ] && OPT_LABEL="${OPT_LABEL}-nowifi"
[ "$KGSL_EXPLOIT" == "off" ] && OPT_LABEL="${OPT_LABEL}-nokgsl"
[ "$DATA_EXPLOIT" == "off" ] && OPT_LABEL="${OPT_LABEL}-nodata"
[ "$NOMOUNT" == "on" ] && OPT_LABEL="${OPT_LABEL}-nomount"
[ "$DEBUG_MODE" == "on" ]   && OPT_LABEL="${OPT_LABEL}-debug"

case "$HZ_ID" in
  100)  HZ_LABEL="-powersave" ;;
  300)  HZ_LABEL="-smooth" ;;
  500)  HZ_LABEL="-performance" ;;
  1000) HZ_LABEL="-ultra-performance" ;;
  *)    HZ_LABEL="-balance" ;;
esac

# Clang label: "Neutron Clang 23.0.0" -> "NeutronClang23.0.0"
CLANG_SHORT=$(echo "${KBUILD_COMPILER_STRING:-UnknownClang}" | sed 's/ Clang/Clang/g' | tr ' ' '-')

# Spoof label (hanya tulis kalau ada)
SPOOF_LABEL=""
[ -n "${VERSION_SPOOF}" ] && SPOOF_LABEL="-spoof${VERSION_SPOOF}"

ZIP_NAME="anykern3-DumpC2J${VARIANT_LABEL}-${CLANG_SHORT}${HZ_LABEL}${OPT_LABEL}${SPOOF_LABEL}-${TIME}.zip"'''

new_block = '''# Build zip name (simple — semua detail lengkap ada di release notes)
TIME=$(date "+%Y%m%d-%H%M")
KVER=$(grep '^VERSION = ' "$KERNEL_DIR/Makefile" | awk '{print $3}')
KPL=$(grep '^PATCHLEVEL = ' "$KERNEL_DIR/Makefile" | awk '{print $3}')
KSL=$(grep '^SUBLEVEL = ' "$KERNEL_DIR/Makefile" | awk '{print $3}')
KERNEL_VER="${KVER}.${KPL}.${KSL}"

ZIP_NAME="anykern3-DumpC2J-${KERNEL_VER}-${TIME}.zip"'''

if old_block not in content:
    print("[-] Blok lama tidak ditemukan, cek manual!")
else:
    content = content.replace(old_block, new_block)
    with open(path, "w") as f:
        f.write(content)
    print("[+] ZIP_NAME berhasil disederhanakan!")
