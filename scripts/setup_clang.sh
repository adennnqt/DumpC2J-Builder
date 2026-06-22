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
    ;;
  cirrus)
    mkdir -p "${GITHUB_WORKSPACE}/clang"
    curl -Lo /tmp/get_clang.sh \
      https://raw.githubusercontent.com/greenforce-project/greenforce_clang/refs/heads/main/get_clang.sh
    bash /tmp/get_clang.sh "${GITHUB_WORKSPACE}/clang"
    CLANG_BIN=$(find "${GITHUB_WORKSPACE}/clang" -name "clang" -type f | head -1 | xargs dirname)
    ;;
  *)
    echo "[!] Unknown clang variant: ${CLANG_VARIANT}"
    exit 1
    ;;
esac

echo "CLANG_PATH=${CLANG_BIN}" >> "${GITHUB_ENV}"
echo "[+] Clang ready: ${CLANG_BIN}"
${CLANG_BIN}/clang --version
