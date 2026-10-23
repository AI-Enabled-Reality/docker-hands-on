"""Turn the capability masks in /proc/<pid>/status into names (lesson 10.1).

    docker exec <container> grep Cap /proc/1/status | python3 tools/caps.py

CapEff is what the process can use now; CapBnd is the most it could ever get (the bounding set).
"""
import sys

NAMES = ["chown", "dac_override", "dac_read_search", "fowner", "fsetid", "kill", "setgid", "setuid",
         "setpcap", "linux_immutable", "net_bind_service", "net_broadcast", "net_admin", "net_raw",
         "ipc_lock", "ipc_owner", "sys_module", "sys_rawio", "sys_chroot", "sys_ptrace", "sys_pacct",
         "sys_admin", "sys_boot", "sys_nice", "sys_resource", "sys_time", "sys_tty_config", "mknod",
         "lease", "audit_write", "audit_control", "setfcap", "mac_override", "mac_admin", "syslog",
         "wake_alarm", "block_suspend", "audit_read", "perfmon", "bpf", "checkpoint_restore"]

for line in sys.stdin:
    field, _, value = line.partition(":")
    if field not in ("CapEff", "CapBnd"):
        continue
    mask = int(value.strip(), 16)
    names = [name for bit, name in enumerate(NAMES) if mask >> bit & 1]
    print(f"{field}: {len(names)} {', '.join(names) or '(none)'}")
