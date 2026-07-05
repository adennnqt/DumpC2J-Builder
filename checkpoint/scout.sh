#!/bin/bash
set -e
# scout.sh — baca checkpoint/manifest.json, export SHA "good" ke GITHUB_ENV
# Tujuan: satu sumber kebenaran buat SHA yang dipin, biar 02_root_setup.sh
# gak perlu tau soal file per-komponen manapun.

MANIFEST="${GITHUB_WORKSPACE}/checkpoint/manifest.json"

get_good() {
  python3 -c "import json,sys; d=json.load(open('$MANIFEST')); print(d.get('$1',{}).get('good') or '')"
}

SUKISU_GOOD=$(get_good "sukisu")
SUSFS_GOOD=$(get_good "susfs_sukisu")

echo "SCOUT_SUKISU_GOOD=${SUKISU_GOOD}" >> "$GITHUB_ENV"
echo "SCOUT_SUSFS_GOOD=${SUSFS_GOOD}" >> "$GITHUB_ENV"

echo "[scout] sukisu good: ${SUKISU_GOOD:0:8}"
echo "[scout] susfs_sukisu good: ${SUSFS_GOOD:0:8}"
