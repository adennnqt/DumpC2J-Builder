path = "scripts/build.sh"

with open(path, "r") as f:
    content = f.read()

old_block = '''      SUSFS_DIR="$MODULES_DIR/susfs4ksu"
      if [ ! -d "$SUSFS_DIR" ]; then
        git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android15-6.6-dev "$SUSFS_DIR"
      else
        (cd "$SUSFS_DIR" && git fetch origin && git reset --hard origin/gki-android15-6.6-dev || true)
      fi'''

new_block = '''      # Pinned to v2.1.0 (commit 89b142242282a4bd56ed447ba4958256beb18df6)
      # v2.2.0+ from upstream -dev branch is NOT yet supported by ReSukiSU Manager
      # (Manager only ships config assets up to ksu_susfs_2.1.0), causing version
      # mismatch warnings in-app. Update this pin only after Manager adds 2.2.0 support.
      SUSFS_DIR="$MODULES_DIR/susfs4ksu"
      SUSFS_PIN_COMMIT="89b142242282a4bd56ed447ba4958256beb18df6"
      if [ ! -d "$SUSFS_DIR" ]; then
        mkdir -p "$SUSFS_DIR"
        (cd "$SUSFS_DIR" && \\
          git init -q && \\
          git remote add origin https://gitlab.com/simonpunk/susfs4ksu.git && \\
          (git fetch --depth=1 origin "$SUSFS_PIN_COMMIT" || git fetch origin) && \\
          git checkout -q FETCH_HEAD)
      else
        (cd "$SUSFS_DIR" && \\
          (git fetch --depth=1 origin "$SUSFS_PIN_COMMIT" || git fetch origin) && \\
          git checkout -q FETCH_HEAD || true)
      fi'''

if old_block not in content:
    print("[-] Blok lama tidak ditemukan, cek manual!")
else:
    content = content.replace(old_block, new_block)
    with open(path, "w") as f:
        f.write(content)
    print("[+] SUSFS pinned to v2.1.0!")
