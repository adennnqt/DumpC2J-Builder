#!/bin/bash
set -e

# ==========================================
# Resolve Root
# ==========================================
case "$ROOT" in
  sukisu)   ROOT_REPO="https://github.com/sukisu-ultra/sukisu-ultra.git"; REPO_NAME="sukisu-ultra"; BRANCH="main" ;;
  resukisu) ROOT_REPO="https://github.com/ReSukiSU/ReSukiSU.git"; REPO_NAME="ReSukiSU"; BRANCH="main"; PIN_COMMIT="v4.1.0" ;;
  ksu-next) ROOT_REPO="https://github.com/KernelSU-Next/KernelSU-Next.git"; REPO_NAME="KernelSU-Next"; BRANCH="dev"; PIN_COMMIT="1de68a8ed2a09ac575c88d3556c1084937669d84" ;;
  kowsu)    ROOT_REPO="https://github.com/KOWX712/KernelSU.git"; REPO_NAME="KOWX712-KernelSU"; BRANCH="master"; PIN_COMMIT="cc559ad732ac73feeafcff7e6b5ee4d2c51c8147" ;;
  *)        REPO_NAME="none" ;;
esac

# ==========================================
# Setup Root Module
# ==========================================
rm -rf "$KERNEL_DIR/drivers/kernelsu"

if [ "$VARIANT" == "stock" ]; then
  mkdir -p "$KERNEL_DIR/drivers/kernelsu"
  touch "$KERNEL_DIR/drivers/kernelsu/Kconfig"
  touch "$KERNEL_DIR/drivers/kernelsu/Makefile"
else
  mkdir -p "$MODULES_DIR"
  if [ ! -d "$MODULES_DIR/$REPO_NAME" ]; then
    if [ -n "${PIN_COMMIT:-}" ]; then
      echo "[+] Cloning $REPO_NAME (full history, pinned to $PIN_COMMIT)..."
      git clone -b "$BRANCH" "$ROOT_REPO" "$MODULES_DIR/$REPO_NAME"
      (cd "$MODULES_DIR/$REPO_NAME" && git checkout "$PIN_COMMIT")
    else
      echo "[+] Cloning $REPO_NAME..."
      git clone --depth=1 -b "$BRANCH" "$ROOT_REPO" "$MODULES_DIR/$REPO_NAME"
    fi
  else
    if [ -n "${PIN_COMMIT:-}" ]; then
      echo "[+] Updating $REPO_NAME (pinned to $PIN_COMMIT)..."
      (cd "$MODULES_DIR/$REPO_NAME" && git fetch origin && git checkout "$PIN_COMMIT" || true)
    else
      echo "[+] Updating $REPO_NAME..."
      (cd "$MODULES_DIR/$REPO_NAME" && git fetch origin && git reset --hard "origin/$BRANCH" || true)
    fi
  fi

  # SUSFS
  if [ "$VARIANT" == "susfs" ]; then
    SUSFS_DIR="$MODULES_DIR/susfs4ksu"
    if [ -n "${SUSFS_PIN:-}" ]; then
      if [ ! -d "$SUSFS_DIR" ]; then
        echo "[+] Cloning susfs4ksu (pinned to $SUSFS_PIN)..."
        git clone https://gitlab.com/simonpunk/susfs4ksu.git "$SUSFS_DIR"
        (cd "$SUSFS_DIR" && git checkout "$SUSFS_PIN")
      else
        echo "[+] Updating susfs4ksu (pinned to $SUSFS_PIN)..."
        (cd "$SUSFS_DIR" && git remote set-url origin https://gitlab.com/simonpunk/susfs4ksu.git && git fetch origin && git checkout "$SUSFS_PIN" || true)
      fi
    else
      echo "[!] WARNING: SUSFS_PIN not set — susfs4ksu will float to latest gki-android15-6.6-dev HEAD."
      echo "[!] WARNING: this can silently break native-susfs roots (ksu-next/resukisu/kowsu) if upstream"
      echo "[!] WARNING: susfs4ksu changes between builds. Set susfs_pin input once a good commit is known."
      if [ ! -d "$SUSFS_DIR" ]; then
        git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android15-6.6-dev "$SUSFS_DIR"
      else
        (cd "$SUSFS_DIR" && git remote set-url origin https://gitlab.com/simonpunk/susfs4ksu.git && git fetch origin && git reset --hard origin/gki-android15-6.6-dev || true)
      fi
    fi

    SUSFS_RESOLVED_SHA="$(cd "$SUSFS_DIR" && git rev-parse HEAD 2>/dev/null || echo unknown)"
    SUSFS_RESOLVED_DATE="$(cd "$SUSFS_DIR" && git log -1 --format=%ci 2>/dev/null || echo unknown)"
    echo "[+] susfs4ksu resolved commit: $SUSFS_RESOLVED_SHA ($SUSFS_RESOLVED_DATE)"
    echo "SUSFS_RESOLVED_SHA=$SUSFS_RESOLVED_SHA" >> "$GITHUB_ENV"

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
        patch -p1 --forward -f \
        < "$SUSFS_DIR/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch" 2>&1 | tee /tmp/susfs_patch.log || true)
      source "$(dirname "${BASH_SOURCE[0]}")/check_susfs_patch.sh"
      check_susfs_patch /tmp/susfs_patch.log
    fi
  fi

  # SukiSU/YukiSU uapi symlink
  if [ ! -d "$MODULES_DIR/$REPO_NAME/kernel/uapi" ] && [ -d "$MODULES_DIR/$REPO_NAME/uapi" ]; then
    ln -sfn ../uapi "$MODULES_DIR/$REPO_NAME/kernel/uapi"
  fi

  echo "[+] Symlinking $REPO_NAME to drivers/kernelsu..."
  ln -sf "$MODULES_DIR/$REPO_NAME/kernel" "$KERNEL_DIR/drivers/kernelsu"
fi

# SUSFS fixup
if [ "$VARIANT" == "susfs" ]; then
  echo "[+] Running SUSFS fixup..."
  bash "$KERNEL_DIR/ksu_susfs_fixup.sh" "$KERNEL_DIR/drivers/kernelsu" "$ROOT"
fi
