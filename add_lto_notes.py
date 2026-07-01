# === 1. build.sh: tambah LTO_ACTUAL ke GITHUB_ENV ===
sh_path = "scripts/build.sh"
with open(sh_path, "r") as f:
    sh = f.read()

old_sh = '''LTO="${INPUT_LTO:-full}"

LTO_VAL="$LTO"
if [ "$KPM" == "on" ] || [ "$ACTUAL_ROOT" == "apatch" ] || [ "$ACTUAL_ROOT" == "folkpatch" ]; then
  LTO_VAL="thin"
fi'''

new_sh = '''LTO="${INPUT_LTO:-full}"

LTO_VAL="$LTO"
if [ "$KPM" == "on" ] || [ "$ACTUAL_ROOT" == "apatch" ] || [ "$ACTUAL_ROOT" == "folkpatch" ]; then
  LTO_VAL="thin"
fi
echo "LTO_ACTUAL=$LTO_VAL" >> "$GITHUB_ENV"'''

if old_sh not in sh:
    print("[-] build.sh: blok LTO_VAL tidak ditemukan!")
else:
    sh = sh.replace(old_sh, new_sh)
    with open(sh_path, "w") as f:
        f.write(sh)
    print("[+] build.sh updated")

# === 2. build.yml: tambah step output + job outputs + update notes ===
yml_path = ".github/workflows/build.yml"
with open(yml_path, "r") as f:
    yml = f.read()

old_step = '''      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: DumpC2J-${{ env.BUILD_NAME }}
          path: kernel-source/DumpC2J-Release
          retention-days: 7'''

new_step = '''      - name: Set LTO Output
        id: lto_output
        run: echo "lto_actual=${{ env.LTO_ACTUAL }}" >> "$GITHUB_OUTPUT"

      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: DumpC2J-${{ env.BUILD_NAME }}
          path: kernel-source/DumpC2J-Release
          retention-days: 7'''

if old_step not in yml:
    print("[-] build.yml: step Upload Artifact tidak ditemukan!")
else:
    yml = yml.replace(old_step, new_step)

old_jobname = '''  build:
    name: "Custom Build"
    runs-on: ubuntu-24.04
'''
new_jobname = '''  build:
    name: "Custom Build"
    runs-on: ubuntu-24.04
    outputs:
      lto_actual: ${{ steps.lto_output.outputs.lto_actual }}
'''

if old_jobname not in yml:
    print("[-] build.yml: header job build tidak ditemukan!")
else:
    yml = yml.replace(old_jobname, new_jobname)

old_notes = '''            **Clang:** ${{ inputs.clang_variant }}'''
new_notes = '''            **Clang:** ${{ inputs.clang_variant }}
            **LTO:** ${{ needs.build.outputs.lto_actual }}'''

if old_notes not in yml:
    print("[-] build.yml: baris Clang di notes tidak ditemukan!")
else:
    yml = yml.replace(old_notes, new_notes)

with open(yml_path, "w") as f:
    f.write(yml)
print("[+] build.yml updated")
