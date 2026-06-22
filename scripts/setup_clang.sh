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
