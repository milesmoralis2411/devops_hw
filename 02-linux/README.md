# Linux Homework Tasks

Covers soft/hard links, `adduser` vs `useradd`, `journalctl`, and a Linux command
cheat sheet. All commands are meant to be run on a Linux host (Ubuntu/Debian).

---

## Task 1: Soft Link & Hard Link

### The difference

| | Soft link (symlink) | Hard link |
|---|---|---|
| What it points to | The **file path/name** | The **inode** (actual data on disk) |
| Across filesystems | ✅ Yes | ❌ No (same filesystem only) |
| Link to a directory | ✅ Yes | ❌ No (not allowed) |
| If original is deleted | ❌ Breaks (dangling link) | ✅ Still works (data survives) |
| Inode number | Different from the original | **Same** as the original |
| Size | Small (stores the path) | Same as the file |

**Key idea:** A hard link is just another name for the *same* data (same inode);
the data is only freed when the last hard link is removed. A soft link is a
pointer to a *name* — delete the target and the symlink dangles.

### Commands

```bash
# Create a source file
echo "original content" > original.txt

# Soft (symbolic) link
ln -s original.txt softlink.txt

# Hard link
ln original.txt hardlink.txt

# Inspect: note the inode numbers (-i) and the '->' on the symlink
ls -li
```

Example output:

```
123456 -rw-r--r-- 2 user user   17 original.txt   <-- link count 2 (shared inode)
123456 -rw-r--r-- 2 user user   17 hardlink.txt   <-- SAME inode 123456
789012 lrwxrwxrwx 1 user user   12 softlink.txt -> original.txt   <-- different inode
```

### Prove the behaviour

```bash
# Delete the original
rm original.txt

cat hardlink.txt     # STILL WORKS -> "original content" (data kept via inode)
cat softlink.txt     # BROKEN -> "No such file or directory" (dangling symlink)
```

### Deleting links

```bash
rm softlink.txt      # removes only the symlink
rm hardlink.txt      # removes one name; data freed only when link count hits 0
```

### Interview one-liner
> A **hard link** is a second directory entry pointing to the same inode (same
> data), works only within one filesystem, and can't link directories. A **soft
> link** is a small file holding a *path* to the target, can cross filesystems
> and link directories, but breaks if the target is removed.

---

## Task 2: `adduser` vs `useradd`

| | `useradd` | `adduser` |
|---|---|---|
| Type | Low-level **binary** utility | High-level **Perl script** wrapper (Debian/Ubuntu) |
| Interactivity | Non-interactive; needs many flags | Interactive; prompts for password, full name, etc. |
| Home directory | Not created unless you pass `-m` | Created automatically |
| Default shell | Often `/bin/sh` or none unless specified | Sets `/bin/bash` |
| Best for | Scripts / automation | Humans at a terminal |

**Preferred on Ubuntu/Debian:** `adduser` — it is the recommended, friendlier
front-end. It creates the home directory, copies `/etc/skel`, sets up the user
group, and prompts for a password automatically. `useradd` is preferred in
**scripts/automation** because it's non-interactive and predictable.

> Note: `adduser` is Debian/Ubuntu-specific. On RHEL/CentOS/Fedora, `adduser`
> is usually just a symlink to `useradd`.

### Create a test user (recommended command on Ubuntu)

```bash
sudo adduser testuser
# Prompts:
#   Adding user `testuser' ...
#   Creating home directory `/home/testuser' ...
#   New password: ...
#   Full Name []: ...

# Verify
id testuser
grep testuser /etc/passwd
ls -ld /home/testuser
```

Equivalent with the low-level tool (note the explicit flags needed):

```bash
sudo useradd -m -s /bin/bash testuser2   # -m creates home, -s sets shell
sudo passwd testuser2                     # set password separately
```

---

## Task 3: `journalctl`

`journalctl` queries and displays logs collected by **systemd's journal**
(`systemd-journald`). It centralises kernel, system, and service logs in one
structured, queryable place.

### Common usage

```bash
journalctl                      # all logs, oldest first
journalctl -e                   # jump to the end (newest)
journalctl -r                   # reverse: newest first
journalctl -f                   # follow live (like tail -f)
journalctl -n 50                # last 50 lines
journalctl -b                   # logs since the current boot
journalctl -k                   # kernel messages only (like dmesg)

# Filter by service unit
journalctl -u ssh.service            # all logs for the SSH service
journalctl -u nginx.service -f       # follow nginx logs live

# Filter by time
journalctl --since "2024-01-01 00:00:00" --until "2024-01-02"
journalctl --since "1 hour ago"

# Filter by priority (0=emerg .. 7=debug); 3 = error and worse
journalctl -p err -b

# Disk usage of the journal
journalctl --disk-usage
```

### Practice: check logs for a specific service

```bash
# Example with the SSH daemon
sudo systemctl status ssh
journalctl -u ssh.service --since "today"
journalctl -u ssh.service -n 20 --no-pager
```

**Expected:** a timestamped stream of that service's log lines, e.g.
`Jan 01 10:15:22 host sshd[1234]: Accepted password for user from ...`.

---

## Task 4: Linux Command Cheat Sheet

| Command | Purpose | Example |
|---------|---------|---------|
| `pwd` | Print working directory | `pwd` |
| `ls` | List files | `ls -la` |
| `cd` | Change directory | `cd /var/log` |
| `cp` | Copy files/dirs | `cp -r src dst` |
| `mv` | Move/rename | `mv a.txt b.txt` |
| `rm` | Remove | `rm -rf dir` |
| `mkdir` | Make directory | `mkdir -p a/b/c` |
| `touch` | Create empty file / update timestamp | `touch file` |
| `cat` | Print file contents | `cat file` |
| `less` | Page through a file | `less bigfile` |
| `head`/`tail` | First/last N lines | `tail -f log` |
| `grep` | Search text | `grep -ri "error" .` |
| `find` | Find files | `find / -name "*.conf"` |
| `chmod` | Change permissions | `chmod 755 script.sh` |
| `chown` | Change owner | `chown user:grp file` |
| `ln` | Create links | `ln -s target link` |
| `ps` | Running processes | `ps aux` |
| `top`/`htop` | Live process monitor | `top` |
| `kill` | Send signal to process | `kill -9 PID` |
| `df` | Disk free space | `df -h` |
| `du` | Directory disk usage | `du -sh *` |
| `free` | Memory usage | `free -h` |
| `tar` | Archive | `tar -czvf a.tgz dir` |
| `wget`/`curl` | Download / HTTP | `curl -O url` |
| `systemctl` | Manage services | `systemctl status ssh` |
| `journalctl` | View logs | `journalctl -u ssh` |
| `sudo` | Run as root | `sudo apt update` |
| `apt`/`yum` | Package manager | `sudo apt install nginx` |
| `man` | Manual pages | `man ls` |

---

## Summary

- **Links:** hard link = same inode (data survives target deletion); soft link =
  path pointer (breaks if target removed).
- **Users:** `adduser` (interactive, recommended on Ubuntu) vs `useradd`
  (low-level, scripting).
- **Logs:** `journalctl -u <service>` is the go-to for per-service systemd logs.
