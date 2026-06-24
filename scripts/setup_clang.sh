#!/usr/bin/env bash
set -e

CLANG_VARIANT="${1:-neutron}"

echo "[*] Setting up Clang: ${CLANG_VARIANT}"

case "${CLANG_VARIANT}" in
  neutron)
    mkdir -p "${HOME}/toolchains/neutron-clang"
    cd "${HOME}/toolchains/neutron-clang"
    curl -Lo antman https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman
    chmod +x antman
    ./antman -S
    ./antman --patch=glibc
    CLANG_BIN="${HOME}/toolchains/neutron-clang/bin"
    COMPILER_STRING="Neutron Clang 23.0.0"
    ;;
  cirrus)
    curl -Lo ~/get_clang.sh \
      https://raw.githubusercontent.com/greenforce-project/greenforce_clang/refs/heads/main/get_clang.sh
    bash ~/get_clang.sh
    CLANG_BIN="${GITHUB_WORKSPACE}/greenforce-clang/bin"
    GF_VERSION=$("${CLANG_BIN}/clang" --version | head -n1 | grep -oP 'clang version \K[0-9.]+' || echo "23.0.0")
    COMPILER_STRING="Cirrus Clang ${GF_VERSION}"
    ;;
  azure)
    AZURE_URL=$(curl -s https://api.github.com/repos/Panchajanya1999/clang-llvm/releases/latest       | python3 -c "import json,sys; d=json.load(sys.stdin); print(next((x['browser_download_url'] for x in d.get('assets',[]) if x['name'].endswith('.tar.gz')), ''))")
    if [ -z "${AZURE_URL}" ]; then
      echo "[!] Azure Clang release not found, falling back to WeebX"
      AZURE_URL=$(curl -s https://raw.githubusercontent.com/XSans0/WeebX-Clang/main/main/link.txt)
    fi
    mkdir -p "${HOME}/toolchains/azure-clang"
    curl -Lo /tmp/azure-clang.tar.gz "${AZURE_URL}"
    tar -xf /tmp/azure-clang.tar.gz -C "${HOME}/toolchains/azure-clang" --strip-components=1
    rm /tmp/azure-clang.tar.gz
    CLANG_BIN="${HOME}/toolchains/azure-clang/bin"
    AZ_VER=$("${CLANG_BIN}/clang" --version | head -n1 | grep -oP 'clang version \K[0-9.]+' || echo "latest")
    COMPILER_STRING="Azure Clang ${AZ_VER}"
    ;;
  weebx)
    WEEBX_URL=$(curl -s https://raw.githubusercontent.com/XSans0/WeebX-Clang/main/main/link.txt)
    mkdir -p "${HOME}/toolchains/weebx-clang"
    wget -q "${WEEBX_URL}" -O /tmp/weebx-clang.tar.gz
    tar -xf /tmp/weebx-clang.tar.gz -C "${HOME}/toolchains/weebx-clang" --strip-components=1
    rm /tmp/weebx-clang.tar.gz
    CLANG_BIN="${HOME}/toolchains/weebx-clang/bin"
    WX_VER=$("${CLANG_BIN}/clang" --version | head -n1 | grep -oP 'clang version \K[0-9.]+' || echo "latest")
    COMPILER_STRING="WeebX Clang ${WX_VER}"
    ;;
  zyc)
    ZYC_URL=$(curl -sL https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt | tr -d '[:space:]')
    mkdir -p "${HOME}/toolchains/zyc-clang"
    curl -Lo /tmp/zyc-clang.tar.gz "${ZYC_URL}"
    STRIP=1
    FIRST=$(tar -tf /tmp/zyc-clang.tar.gz 2>/dev/null | head -1)
    [[ "$FIRST" == "./" || "$FIRST" == "bin/" ]] && STRIP=0
    tar -xf /tmp/zyc-clang.tar.gz -C "${HOME}/toolchains/zyc-clang" --strip-components=${STRIP}
    rm /tmp/zyc-clang.tar.gz
    CLANG_BIN="${HOME}/toolchains/zyc-clang/bin"
    ZYC_VER=$("${CLANG_BIN}/clang" --version | head -n1 | grep -oP 'clang version \K[0-9.]+' || echo "latest")
    COMPILER_STRING="ZyC Clang ${ZYC_VER}"
    ;;
  aosp)
    mkdir -p "${HOME}/toolchains/aosp-clang"
    git clone --depth=1 --filter=blob:none --sparse \
      https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r536225 \
      /tmp/aosp-clang-repo
    cp -r /tmp/aosp-clang-repo/. "${HOME}/toolchains/aosp-clang/"
    rm -rf /tmp/aosp-clang-repo
    CLANG_BIN="${HOME}/toolchains/aosp-clang/bin"
    AOSP_VER=$("${CLANG_BIN}/clang" --version | head -n1 | grep -oP 'clang version \K[0-9.]+' || echo "latest")
    COMPILER_STRING="AOSP Clang ${AOSP_VER}"
    ;;
  *)
    echo "[!] Unknown clang variant: ${CLANG_VARIANT}"
    exit 1
    ;;
esac

echo "CLANG_PATH=${CLANG_BIN}" >> "${GITHUB_ENV}"
echo "${CLANG_BIN}" >> "${GITHUB_PATH}"
echo "KBUILD_COMPILER_STRING=${COMPILER_STRING}" >> "${GITHUB_ENV}"
echo "KBUILD_BUILD_USER=adennnqt" >> "${GITHUB_ENV}"
echo "KBUILD_BUILD_HOST=DumpC2J" >> "${GITHUB_ENV}"
echo "[+] Clang ready: ${CLANG_BIN}"
${CLANG_BIN}/clang --version
