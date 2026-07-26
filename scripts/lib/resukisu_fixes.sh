#!/bin/bash
set -e

if [ "$ROOT" == "resukisu" ]; then
  KSUD_INT="$MODULES_DIR/$REPO_NAME/kernel/runtime/ksud_integration.c"
  if [ -f "$KSUD_INT" ]; then
    sed -i 's/ksu_init_rc_hook_key_false/ksu_is_init_rc_hook_enabled/g' "$KSUD_INT"
    echo "[*] ReSukiSU: fixed ksu_init_rc_hook_key_false typo"
  fi

  SUCOMPAT_IMPL="$MODULES_DIR/$REPO_NAME/kernel/feature/sucompat_proc_flag.c"
  SUCOMPAT_KBUILD="$MODULES_DIR/$REPO_NAME/kernel/Kbuild"
  # Check the Kbuild line, not just the .c file. The .c file is untracked and
  # survives `git checkout -B` between runs, but Kbuild is tracked and gets
  # reset to upstream on every checkout -- checking only for the .c file's
  # existence silently drops the Kbuild line (and the fix) on every run after
  # the first.
  if ! grep -qF "feature/sucompat_proc_flag.o" "$SUCOMPAT_KBUILD" 2>/dev/null; then
    echo "[*] Generating sucompat_proc_flag.c for ReSukiSU susfs LTO fix..."
    cat > "$SUCOMPAT_IMPL" << 'SCEOF'
#include <linux/types.h>
#include <linux/thread_info.h>
#ifdef CONFIG_64BIT
#define TIF_PROC_NON_PRIVILEGE 62
#else
#define TIF_PROC_NON_PRIVILEGE 30
#endif
bool ksu_is_current_proc_unprivillege(void) {
    return test_thread_flag(TIF_PROC_NON_PRIVILEGE);
}
void ksu_set_current_proc_unprivillege(void) {
    set_thread_flag(TIF_PROC_NON_PRIVILEGE);
}
void ksu_clear_current_proc_unprivillege(void) {
    clear_thread_flag(TIF_PROC_NON_PRIVILEGE);
}
SCEOF
    echo "kernelsu-objs += feature/sucompat_proc_flag.o" >> "$SUCOMPAT_KBUILD"
    echo "[+] sucompat_proc_flag.c generated and added to Kbuild"
  fi
fi
