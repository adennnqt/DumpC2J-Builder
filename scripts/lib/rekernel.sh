#!/bin/bash
set -e

echo "[*] Integrating Re-Kernel..."

python3 -c "
import os
h = open('$KERNEL_DIR/drivers/android/rekernel.h', 'w')
h.write('''#ifndef REKERNEL_H\n#define REKERNEL_H\n#include <linux/init.h>\n#include <linux/types.h>\n#include <net/sock.h>\n#include <linux/netlink.h>\n#include <linux/proc_fs.h>\n#include <linux/freezer.h>\n#include <linux/sched/jobctl.h>\n\n#define NETLINK_REKERNEL_MAX 26\n#define NETLINK_REKERNEL_MIN 22\n#define USER_PORT 100\n#define PACKET_SIZE 128\n#define MIN_USERAPP_UID (10000)\n#define MAX_SYSTEM_UID (2000)\n#define RESERVE_ORDER 17\n#define WARN_AHEAD_SPACE (1 << RESERVE_ORDER)\n\nstatic struct sock *rekernel_netlink = NULL;\nextern struct net init_net;\nstatic int netlink_unit = NETLINK_REKERNEL_MIN;\n\nstatic inline bool line_is_frozen(struct task_struct *task) {\n    return frozen(task->group_leader) || freezing(task->group_leader);\n}\n\nstatic int send_netlink_message(char *msg, uint16_t len) {\n    struct sk_buff *skbuffer;\n    struct nlmsghdr *nlhdr;\n    skbuffer = nlmsg_new(len, GFP_ATOMIC);\n    if (!skbuffer) { printk(\"netlink alloc failure.\\\\n\"); return -1; }\n    nlhdr = nlmsg_put(skbuffer, 0, 0, netlink_unit, len, 0);\n    if (!nlhdr) { printk(\"nlmsg_put failure.\\\\n\"); nlmsg_free(skbuffer); return -1; }\n    memcpy(nlmsg_data(nlhdr), msg, len);\n    return netlink_unicast(rekernel_netlink, skbuffer, USER_PORT, MSG_DONTWAIT);\n}\n\nstatic void netlink_rcv_msg(struct sk_buff *skbuffer) {}\nstatic struct netlink_kernel_cfg rekernel_cfg = { .input = netlink_rcv_msg };\n\nstatic int rekernel_unit_show(struct seq_file *m, void *v) {\n    seq_printf(m, \"%d\\\\n\", netlink_unit); return 0;\n}\nstatic int rekernel_unit_open(struct inode *inode, struct file *file) {\n    return single_open(file, rekernel_unit_show, NULL);\n}\nstatic const struct proc_ops rekernel_unit_fops = {\n    .proc_open = rekernel_unit_open, .proc_read = seq_read,\n    .proc_lseek = seq_lseek, .proc_release = single_release,\n};\n\nstatic struct proc_dir_entry *rekernel_dir, *rekernel_unit_entry;\n\nstatic int start_rekernel_server(void) {\n    if (rekernel_netlink != NULL) return 0;\n    for (netlink_unit = NETLINK_REKERNEL_MIN; netlink_unit < NETLINK_REKERNEL_MAX; netlink_unit++) {\n        rekernel_netlink = (struct sock *)netlink_kernel_create(&init_net, netlink_unit, &rekernel_cfg);\n        if (rekernel_netlink != NULL) break;\n    }\n    if (rekernel_netlink == NULL) { printk(\"Failed to create Re:Kernel server!\\\\n\"); return -1; }\n    printk(\"Created Re:Kernel server! NETLINK UNIT: %d\\\\n\", netlink_unit);\n    rekernel_dir = proc_mkdir(\"rekernel\", NULL);\n    if (!rekernel_dir) printk(\"create /proc/rekernel failed!\\\\n\");\n    else {\n        char buff[32];\n        sprintf(buff, \"%d\", netlink_unit);\n        rekernel_unit_entry = proc_create(buff, 0644, rekernel_dir, &rekernel_unit_fops);\n        if (!rekernel_unit_entry) printk(\"create rekernel unit failed!\\\\n\");\n    }\n    return 0;\n}\n#endif\n''')
h.close()
print('[+] rekernel.h written')
"

python3 << RKPY
import sys

import os; KERNEL_DIR = os.path.join(os.environ.get('GITHUB_WORKSPACE', ''), 'kernel-source')

bc_path = f"{KERNEL_DIR}/drivers/android/binder.c"
with open(bc_path) as f:
    bc = f.read()

if '#include "rekernel.h"' not in bc:
    bc = bc.replace('#include "binder_trace.h"', '#include "binder_trace.h"\n#include "rekernel.h"')
    print("[+] binder.c: header injected")

reply_hook = '\n\t\t/* rekernel reply hook */\n\t\tif (start_rekernel_server() == 0) {\n\t\t\tif (target_proc && target_proc->tsk && proc->tsk\n\t\t\t\t&& (task_uid(target_proc->tsk).val <= MAX_SYSTEM_UID)\n\t\t\t\t&& (proc->pid != target_proc->pid)\n\t\t\t\t&& line_is_frozen(target_proc->tsk)) {\n\t\t\t\tchar binder_kmsg[PACKET_SIZE];\n\t\t\t\tsnprintf(binder_kmsg, sizeof(binder_kmsg), "type=Binder,bindertype=reply,oneway=0,from_pid=%d,from=%d,target_pid=%d,target=%d;", proc->pid, task_uid(proc->tsk).val, target_proc->pid, task_uid(target_proc->tsk).val);\n\t\t\t\tsend_netlink_message(binder_kmsg, strlen(binder_kmsg));\n\t\t\t}\n\t\t}'

txn_hook = '\n\t\t/* rekernel txn hook */\n\t\tif (start_rekernel_server() == 0) {\n\t\t\tif (target_proc && target_proc->tsk && proc->tsk\n\t\t\t\t&& (task_uid(target_proc->tsk).val > MIN_USERAPP_UID)\n\t\t\t\t&& (proc->pid != target_proc->pid)\n\t\t\t\t&& line_is_frozen(target_proc->tsk)) {\n\t\t\t\tchar binder_kmsg[PACKET_SIZE];\n\t\t\t\tsnprintf(binder_kmsg, sizeof(binder_kmsg), "type=Binder,bindertype=transaction,oneway=%d,from_pid=%d,from=%d,target_pid=%d,target=%d;", tr->flags & TF_ONE_WAY, proc->pid, task_uid(proc->tsk).val, target_proc->pid, task_uid(target_proc->tsk).val);\n\t\t\t\tsend_netlink_message(binder_kmsg, strlen(binder_kmsg));\n\t\t\t}\n\t\t}'

if 'rekernel reply hook' not in bc:
    anchor = '\t\tbinder_inner_proc_unlock(target_thread->proc);\n\t\ttrace_android_vh_binder_reply(target_proc, proc, thread, tr);\n\t} else {'
    if anchor in bc:
        bc = bc.replace(anchor, '\t\tbinder_inner_proc_unlock(target_thread->proc);' + reply_hook + '\n\t\ttrace_android_vh_binder_reply(target_proc, proc, thread, tr);\n\t} else {')
        print("[+] binder.c: reply hook injected")
    else:
        print("[-] binder.c: reply anchor NOT FOUND", file=sys.stderr)

if 'rekernel txn hook' not in bc:
    anchor = '\t\tif (security_binder_transaction(proc->cred,'
    if anchor in bc:
        bc = bc.replace(anchor, txn_hook + '\n\t\tif (security_binder_transaction(proc->cred,')
        print("[+] binder.c: txn hook injected")
    else:
        print("[-] binder.c: txn anchor NOT FOUND", file=sys.stderr)

with open(bc_path, 'w') as f:
    f.write(bc)

sc_path = f"{KERNEL_DIR}/kernel/signal.c"
with open(sc_path) as f:
    sc = f.read()

if '#include "../drivers/android/rekernel.h"' not in sc:
    sc = sc.replace('#include <linux/freezer.h>', '#include <linux/freezer.h>\n#include "../drivers/android/rekernel.h"')
    print("[+] signal.c: header injected")

sig_hook = '\n\t/* rekernel signal hook */\n\tif (start_rekernel_server() == 0) {\n\t\tif (line_is_frozen(current) && (sig == SIGKILL || sig == SIGTERM || sig == SIGABRT || sig == SIGQUIT)) {\n\t\t\tchar binder_kmsg[PACKET_SIZE];\n\t\t\tsnprintf(binder_kmsg, sizeof(binder_kmsg), "type=Signal,signal=%d,killer_pid=%d,killer=%d,dst_pid=%d,dst=%d;", sig, task_tgid_nr(p), task_uid(p).val, task_tgid_nr(current), task_uid(current).val);\n\t\t\tsend_netlink_message(binder_kmsg, strlen(binder_kmsg));\n\t\t}\n\t}'

if 'rekernel signal hook' not in sc:
    anchor = '\tint ret = -ESRCH;\n\ttrace_android_vh_do_send_sig_info(sig, current, p);\n\tif (lock_task_sighand'
    if anchor in sc:
        sc = sc.replace(anchor, '\tint ret = -ESRCH;' + sig_hook + '\n\ttrace_android_vh_do_send_sig_info(sig, current, p);\n\tif (lock_task_sighand')
        print("[+] signal.c: signal hook injected")
    else:
        print("[-] signal.c: anchor NOT FOUND", file=sys.stderr)

with open(sc_path, 'w') as f:
    f.write(sc)

print("[+] Re-Kernel patching done!")
RKPY

echo "[+] Re-Kernel integration done!"
