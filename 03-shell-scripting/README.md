# Shell Scripting Homework — System Information Script

A single script, [`sysinfo.sh`](sysinfo.sh), that satisfies every requirement of
the task.

## Requirements covered

| Requirement | How the script does it |
|-------------|------------------------|
| Print current date | `CURRENT_DATE=$(date)` then `echo` |
| Print hostname | `HOST_NAME=$(hostname)` |
| Print username | `USER_NAME=$(whoami)` |
| Print disk usage | `df -h` |
| Print running processes | `ps aux` |
| Use variables | `CURRENT_DATE`, `HOST_NAME`, `USER_NAME`, `DIR_NAME`, `FILE_NAME` |
| Take user input | `read -p "..." DIR_NAME` |
| Create a directory | `mkdir -p "$DIR_NAME"` |
| Create a file | `touch "$DIR_NAME/$FILE_NAME"` |
| `>` output redirection | `ps aux > "$DIR_NAME/$FILE_NAME"` |

## How to run

```bash
chmod +x sysinfo.sh
./sysinfo.sh
# or:
bash sysinfo.sh
```

The script will prompt for a directory name and a file name (press Enter to
accept the defaults `sysinfo_output` / `processes.txt`).

## Actual output

Captured by running `printf 'sysinfo_output\nprocesses.txt\n' | bash sysinfo.sh`:

```text
==========================================
           SYSTEM INFORMATION
==========================================
Current Date : Thu Sep  3 21:59:41 IST 2026
Hostname     : Varun
Username     : Varun Mundada

---------- Disk Usage (df -h) ----------
Filesystem            Size  Used Avail Use% Mounted on
C:/Program Files/Git  953G  588G  365G  62% /

---------- Running Processes (ps) ----------
      PID    PPID    PGID     WINPID   TTY         UID    STIME COMMAND
      947     941     938      44240  ?         197610 21:59:41 /usr/bin/head
      938       1     938      47036  ?         197610 21:59:41 /usr/bin/bash
      946     941     938      25752  ?         197610 21:59:41 /usr/bin/ps
      941     938     938      26852  ?         197610 21:59:41 /usr/bin/bash

Directory 'sysinfo_output' created.
File 'sysinfo_output/processes.txt' created.
Running processes saved to 'sysinfo_output/processes.txt' using > redirection.

Preview of saved file (first 5 lines):
      PID    PPID    PGID     WINPID   TTY         UID    STIME COMMAND
      938       1     938      47036  ?         197610 21:59:41 /usr/bin/bash
      941     938     938      26852  ?         197610 21:59:41 /usr/bin/bash
      950     941     938       6464  ?         197610 21:59:41 /usr/bin/ps
==========================================
Script finished successfully.
==========================================
```

> The output above was captured on a Windows + Git Bash environment (hence the
> `WINPID` column and the `C:/Program Files/Git` mount). On a native Linux host
> `df -h` shows the real partitions and `ps aux` shows the full process list with
> `USER/CPU/MEM` columns.

## Note on the saved file

The `>` operator **overwrites** the target file with the command's stdout. The
script uses it to persist the process list:

```bash
ps aux > "$DIR_NAME/$FILE_NAME"
```

Use `>>` instead if you want to **append** rather than overwrite.
