#!/bin/bash
set -e

case "$ROOT" in
  sukisu)   ROOT_REPO="https://github.com/sukisu-ultra/sukisu-ultra.git"; REPO_NAME="sukisu-ultra"
            if [ "$VARIANT" == "susfs" ]; then BRANCH="builtin"; PIN_KEY="sukisu_susfs"; PIN_PREFIX="SUKISU_SUSFS"
            else BRANCH="main"; PIN_KEY="sukisu_root"; PIN_PREFIX="SUKISU_ROOT"; fi ;;
  resukisu) ROOT_REPO="https://github.com/ReSukiSU/ReSukiSU.git"; REPO_NAME="ReSukiSU"; BRANCH="main"
            if [ "$VARIANT" == "susfs" ]; then PIN_KEY="resukisu_susfs"; PIN_PREFIX="RESUKISU_SUSFS"
            else PIN_KEY="resukisu_root"; PIN_PREFIX="RESUKISU_ROOT"; fi ;;
  ksu-next) ROOT_REPO="https://github.com/KernelSU-Next/KernelSU-Next.git"; REPO_NAME="KernelSU-Next"; BRANCH="dev"
            if [ "$VARIANT" == "susfs" ]; then PIN_KEY="ksunext_susfs"; PIN_PREFIX="KSUNEXT_SUSFS"
            else PIN_KEY="ksunext_root"; PIN_PREFIX="KSUNEXT_ROOT"; fi ;;
  kowsu)    ROOT_REPO="https://github.com/KOWX712/KernelSU.git"; REPO_NAME="KOWX712-KernelSU"; BRANCH="master"
            if [ "$VARIANT" == "susfs" ]; then PIN_KEY="kowsu_susfs"; PIN_PREFIX="KOWSU_SUSFS"
            else PIN_KEY="kowsu_root"; PIN_PREFIX="KOWSU_ROOT"; fi ;;
  *)        REPO_NAME="none" ;;
esac

echo "PIN_KEY=${PIN_KEY:-}" >> "$GITHUB_ENV"
echo "PIN_PREFIX=${PIN_PREFIX:-}" >> "$GITHUB_ENV"

echo "REPO_NAME=$REPO_NAME" >> "$GITHUB_ENV"

rm -rf "$KERNEL_DIR/drivers/kernelsu"

if [ "$VARIANT" == "stock" ]; then
  mkdir -p "$KERNEL_DIR/drivers/kernelsu"
  touch "$KERNEL_DIR/drivers/kernelsu/Kconfig"
  touch "$KERNEL_DIR/drivers/kernelsu/Makefile"
else
  mkdir -p "$MODULES_DIR"
  REF_VAR="${PIN_PREFIX}_REF"
  RESOLVED_SHA="${!REF_VAR}"
  [ -z "$RESOLVED_SHA" ] && { echo "[-] ERROR: ${REF_VAR} kosong — scout.sh belum jalan atau gagal resolve."; exit 1; }

  if [ ! -d "$MODULES_DIR/$REPO_NAME" ]; then
    echo "[+] Cloning $REPO_NAME (full history, buat fallback)..."
    git clone -b "$BRANCH" "$ROOT_REPO" "$MODULES_DIR/$REPO_NAME"
  else
    echo "[+] Fetching $REPO_NAME..."
    (cd "$MODULES_DIR/$REPO_NAME" && git fetch origin "$BRANCH")
  fi

  echo "[+] Checkout ${PIN_KEY} @ ${RESOLVED_SHA:0:8} (dari scout.sh)"
  (cd "$MODULES_DIR/$REPO_NAME" && git checkout -B "$BRANCH" --quiet "$RESOLVED_SHA")

  echo "MANAGER_ROOT_NAME=${ROOT}" >> "$GITHUB_ENV"
  echo "MANAGER_REPO_DIR=${MODULES_DIR}/${REPO_NAME}" >> "$GITHUB_ENV"
  cd "$GITHUB_WORKSPACE"

  if [ "$VARIANT" == "susfs" ]; then
    SUSFS_DIR="$MODULES_DIR/susfs4ksu"
    SUSFS_BRANCH="gki-android15-6.6-dev"
    SUSFS_TARGET_SHA="${SUSFS4KSU_REF:-}"
    [ -z "$SUSFS_TARGET_SHA" ] && { echo "[-] ERROR: SUSFS4KSU_REF kosong — scout.sh belum jalan atau gagal resolve."; exit 1; }

    if [ ! -d "$SUSFS_DIR" ]; then
      git clone https://gitlab.com/simonpunk/susfs4ksu.git -b "$SUSFS_BRANCH" "$SUSFS_DIR"
    else
      (cd "$SUSFS_DIR" && git fetch origin "$SUSFS_BRANCH")
    fi

    echo "[+] Checkout susfs4ksu @ ${SUSFS_TARGET_SHA:0:8} (dari scout.sh)"
    (cd "$SUSFS_DIR" && git checkout --quiet "$SUSFS_TARGET_SHA")
    echo "SUSFS_USED_SHA=${SUSFS_TARGET_SHA}" >> "$GITHUB_ENV"

    echo "[+] Injecting SUSFS kernel sources..."
    cp "$SUSFS_DIR/kernel_patches/fs/susfs.c" "$KERNEL_DIR/fs/susfs.c"
    cp "$SUSFS_DIR/kernel_patches/include/linux/susfs.h" "$KERNEL_DIR/include/linux/susfs.h"
    [ -f "$SUSFS_DIR/kernel_patches/include/linux/susfs_def.h" ] && \
      cp "$SUSFS_DIR/kernel_patches/include/linux/susfs_def.h" "$KERNEL_DIR/include/linux/susfs_def.h"

    SUSFS_DEF_H="$KERNEL_DIR/include/linux/susfs_def.h"
    if [ -f "$SUSFS_DEF_H" ] && ! grep -q "linux/sched.h" "$SUSFS_DEF_H" 2>/dev/null; then
      sed -i '/#include <linux\/bits.h>/a\
#include <linux\/sched.h>\
#include <linux\/thread_info.h>\
#include <linux\/cred.h>\
#include <asm\/current.h>' "$SUSFS_DEF_H"
    fi

    if grep -q "KSU_SUSFS" "$MODULES_DIR/$REPO_NAME/kernel/Kconfig" 2>/dev/null || [ "$ROOT" == "sukisu" ] || [ "$ROOT" == "resukisu" ]; then
      echo "[+] $REPO_NAME already has native SUSFS integration. Skipping patch..."
    else
      echo "[+] Patching $REPO_NAME for SUSFS..."
      (cd "$MODULES_DIR/$REPO_NAME" && \
        patch -p1 --forward -f --reject-file=- \
        < "$SUSFS_DIR/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch" || true)
    fi
  fi

  if [ ! -d "$MODULES_DIR/$REPO_NAME/kernel/uapi" ] && [ -d "$MODULES_DIR/$REPO_NAME/uapi" ]; then
    ln -sfn ../uapi "$MODULES_DIR/$REPO_NAME/kernel/uapi"
  fi

  echo "[+] Symlinking $REPO_NAME to drivers/kernelsu..."
  ln -sf "$MODULES_DIR/$REPO_NAME/kernel" "$KERNEL_DIR/drivers/kernelsu"
fi

if [ "$VARIANT" == "susfs" ]; then
  echo "[+] Running SUSFS fixup..."
  bash "$KERNEL_DIR/ksu_susfs_fixup.sh" "$KERNEL_DIR/drivers/kernelsu" "$ROOT"
fi
