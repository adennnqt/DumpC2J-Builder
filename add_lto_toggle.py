# === 1. Edit build.yml ===
yml_path = ".github/workflows/build.yml"
with open(yml_path, "r") as f:
    yml = f.read()

old_yml = '''      kpm:
        description: "Kernel Patch Module (KPM)"
        required: true
        type: choice
        options:
          - "off"
          - "on"
        default: "off"'''

new_yml = '''      kpm:
        description: "Kernel Patch Module (KPM)"
        required: true
        type: choice
        options:
          - "off"
          - "on"
        default: "off"
      lto:
        description: "LTO Mode (auto-override ke Thin kalau KPM/APatch/FolkPatch aktif)"
        required: true
        type: choice
        options:
          - full
          - thin
          - none
        default: full'''

if old_yml not in yml:
    print("[-] build.yml: blok kpm tidak ditemukan, cek manual!")
else:
    yml = yml.replace(old_yml, new_yml)

old_env = '''          INPUT_KPM: ${{ inputs.kpm }}'''
new_env = '''          INPUT_KPM: ${{ inputs.kpm }}
          INPUT_LTO: ${{ inputs.lto }}'''

if old_env not in yml:
    print("[-] build.yml: baris INPUT_KPM tidak ditemukan, cek manual!")
else:
    # Replace only in the "Build Kernel" step's env block (second occurrence)
    parts = yml.split(old_env)
    if len(parts) >= 3:
        yml = old_env.join(parts[:-1]) + new_env + parts[-1]
    else:
        yml = yml.replace(old_env, new_env)

with open(yml_path, "w") as f:
    f.write(yml)
print("[+] build.yml updated")

# === 2. Edit build.sh ===
sh_path = "scripts/build.sh"
with open(sh_path, "r") as f:
    sh = f.read()

old_sh = '''LTO_VAL="full"
if [ "$KPM" == "on" ] || [ "$ACTUAL_ROOT" == "apatch" ] || [ "$ACTUAL_ROOT" == "folkpatch" ]; then
  LTO_VAL="thin"
fi'''

new_sh = '''LTO="${INPUT_LTO:-full}"

LTO_VAL="$LTO"
if [ "$KPM" == "on" ] || [ "$ACTUAL_ROOT" == "apatch" ] || [ "$ACTUAL_ROOT" == "folkpatch" ]; then
  LTO_VAL="thin"
fi'''

if old_sh not in sh:
    print("[-] build.sh: blok LTO_VAL tidak ditemukan, cek manual!")
else:
    sh = sh.replace(old_sh, new_sh)
    with open(sh_path, "w") as f:
        f.write(sh)
    print("[+] build.sh updated")
