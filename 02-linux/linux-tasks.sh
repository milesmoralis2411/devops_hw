#!/bin/bash
# Linux Homework — Tasks 1-3 executed on a real Linux host (Ubuntu/WSL2).
# Run as root:  sudo bash linux-tasks.sh
set +e

echo "=================== ENVIRONMENT ==================="
echo "user: $(whoami)"
. /etc/os-release 2>/dev/null && echo "distro: $PRETTY_NAME"
uname -sr

echo
echo "=================== TASK 1: SOFT LINK & HARD LINK ==================="
rm -rf /tmp/linkdemo && mkdir -p /tmp/linkdemo && cd /tmp/linkdemo
echo "original content" > original.txt
ln -s original.txt softlink.txt        # soft (symbolic) link
ln    original.txt hardlink.txt         # hard link
echo "-- ls -li (inode numbers + link counts; note the l---- and -> on softlink) --"
ls -li
echo "-- readlink softlink.txt --"
readlink softlink.txt
echo "-- stat inode of original vs hardlink (identical) --"
echo "original: $(stat -c '%i' original.txt) | hardlink: $(stat -c '%i' hardlink.txt) | softlink: $(stat -c '%i' softlink.txt)"
echo "-- now DELETE the original --"
rm original.txt
echo "-- cat hardlink.txt (data survives via inode) --"
cat hardlink.txt
echo "-- cat softlink.txt (dangling -> should FAIL) --"
cat softlink.txt

echo
echo "=================== TASK 2: adduser vs useradd ==================="
echo "-- location of each command --"
type adduser; type useradd
echo "-- create a test user with the RECOMMENDED command (adduser) --"
deluser --remove-home testuser >/dev/null 2>&1
adduser --disabled-password --gecos "" testuser
echo "-- verify the user, home dir and default shell --"
id testuser
grep '^testuser:' /etc/passwd
ls -ld /home/testuser

echo
echo "=================== TASK 3: journalctl ==================="
if command -v journalctl >/dev/null 2>&1; then
  journalctl --version | head -1
  echo "-- most recent 8 journal entries --"
  journalctl -n 8 --no-pager 2>&1 | head -12
  echo "-- kernel messages (journalctl -k), last 5 --"
  journalctl -k -n 5 --no-pager 2>&1 | head -8
  echo "-- logs for a specific service (example: cron), last 5 --"
  journalctl -u cron -n 5 --no-pager 2>&1 | head -8
else
  echo "journalctl not available on this system"
fi

echo
echo "=================== DONE ==================="
