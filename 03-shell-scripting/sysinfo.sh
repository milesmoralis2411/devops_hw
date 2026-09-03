#!/bin/bash
#
# sysinfo.sh - System Information Script
# -------------------------------------
# Demonstrates the concepts required by the Shell Scripting homework:
#   - Prints current date, hostname, username, disk usage, running processes
#   - Uses variables to store and reuse data
#   - Takes user input with `read -p`
#   - Creates a directory with `mkdir`
#   - Creates a file with `touch`
#   - Stores running-process info in a file using `>` output redirection
#

# ---- 1. Store data in variables ----
CURRENT_DATE=$(date)
HOST_NAME=$(hostname)
USER_NAME=$(whoami)

echo "=========================================="
echo "           SYSTEM INFORMATION"
echo "=========================================="

# ---- 2. Print the stored variables ----
echo "Current Date : $CURRENT_DATE"
echo "Hostname     : $HOST_NAME"
echo "Username     : $USER_NAME"

echo ""
echo "---------- Disk Usage (df -h) ----------"
df -h

echo ""
echo "---------- Running Processes (ps) ----------"
ps aux 2>/dev/null | head -n 10 || ps

# ---- 3. Take user input with read -p ----
echo ""
read -p "Enter a name for the output directory: " DIR_NAME
read -p "Enter a name for the output file: " FILE_NAME

# Provide sensible defaults if the user just presses Enter
DIR_NAME=${DIR_NAME:-sysinfo_output}
FILE_NAME=${FILE_NAME:-processes.txt}

# ---- 4. Create a directory with mkdir ----
mkdir -p "$DIR_NAME"
echo "Directory '$DIR_NAME' created."

# ---- 5. Create a file with touch ----
touch "$DIR_NAME/$FILE_NAME"
echo "File '$DIR_NAME/$FILE_NAME' created."

# ---- 6. Store running processes in the file using > redirection ----
ps aux > "$DIR_NAME/$FILE_NAME" 2>/dev/null || ps > "$DIR_NAME/$FILE_NAME"
echo "Running processes saved to '$DIR_NAME/$FILE_NAME' using > redirection."

echo ""
echo "Preview of saved file (first 5 lines):"
head -n 5 "$DIR_NAME/$FILE_NAME"

echo "=========================================="
echo "Script finished successfully."
echo "=========================================="
