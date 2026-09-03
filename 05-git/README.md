# Git Homework Tasks

Both tasks were actually executed and the real command output is captured below.
A `demo-repo/` folder is included showing the final state of the repository
(the `.git` folder was removed so it lives inside this homework repo as plain
files).

---

## Task 1: `git commit -a -m` vs `git commit -m`

### The difference

- `git commit -m "msg"` commits **only what is already staged** (added with
  `git add`). Changes to tracked files that you haven't staged are **not**
  committed.
- `git commit -a -m "msg"` **automatically stages all modified/deleted tracked
  files** before committing. It does **not** include brand-new untracked files —
  those still need `git add`.

### Real output

```text
=== TASK 1: git commit -a -m vs git commit -m ===

>> After modifying a tracked file, run 'git commit -m' WITHOUT -a:
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        modified:   notes.txt
>> git status shows the change is still unstaged:
 M notes.txt

>> Now use 'git commit -a -m' which auto-stages tracked files:
[main 5a51ad9] Commit tracked change using -a -m
 1 file changed, 1 insertion(+)
(clean working tree = the -a flag staged and committed the tracked change)
```

**Conclusion:** `commit -m` refused to commit the unstaged edit (nothing was
staged), while `commit -a -m` staged the tracked change and committed it in one
step, leaving a clean working tree.

---

## Task 2: Git Cherry-Pick

Create commits on `main`, branch off, make more commits, then cherry-pick **one**
specific commit from the branch back onto `main`.

### Real output

```text
=== TASK 2: Git Cherry-Pick ===
>> git log on main (oneline):
916b4d5 main: add feature B
0154fbd main: add feature A
5a51ad9 Commit tracked change using -a -m
03adb9f Initial commit: add notes.txt

>> Create a new branch 'feature' and make 3 commits:
>> git log on feature branch:
a5392f1 feature: experimental change 3
ec4316d feature: critical bugfix we want on main
1d69ba1 feature: experimental change 1
916b4d5 main: add feature B
0154fbd main: add feature A
...

>> Identify the bugfix commit hash to cherry-pick:
Selected commit: ec4316d feature: critical bugfix we want on main

>> Switch to main and cherry-pick ONLY that commit:
[main b3593a8] feature: critical bugfix we want on main
 Date: Thu Sep 3 22:00:33 2026 +0530
 1 file changed, 1 insertion(+)
 create mode 100644 bugfix.txt

>> Verify: main now has bugfix.txt but NOT the other experimental files:
b3593a8 feature: critical bugfix we want on main
916b4d5 main: add feature B
0154fbd main: add feature A
5a51ad9 Commit tracked change using -a -m
03adb9f Initial commit: add notes.txt
--- files on main ---
a.txt
b.txt
bugfix.txt
notes.txt
(bugfix.txt present; exp1.txt / exp3.txt absent = only the one commit was cherry-picked)
```

**Conclusion:** Only the `critical bugfix` commit (`ec4316d`) was applied to
`main` — it appears as a **new commit** `b3593a8` with a different hash (a copy,
not a move). The other two experimental commits (`exp1.txt`, `exp3.txt`) stayed
on the `feature` branch, proving cherry-pick transplants a single selected
change without merging the whole branch.

---

## Commands used (for reference)

```bash
# Task 1
git init -b main
echo "line1" > notes.txt && git add notes.txt && git commit -m "Initial commit"
echo "line2" >> notes.txt
git commit -m "without -a"      # nothing committed (unstaged)
git commit -a -m "with -a -m"   # auto-stages tracked change

# Task 2
echo A > a.txt && git add a.txt && git commit -m "main: add feature A"
echo B > b.txt && git add b.txt && git commit -m "main: add feature B"
git log --oneline

git checkout -b feature
echo e1 > exp1.txt && git add . && git commit -m "feature: experimental change 1"
echo fix > bugfix.txt && git add . && git commit -m "feature: critical bugfix we want on main"
echo e3 > exp3.txt && git add . && git commit -m "feature: experimental change 3"
git log --oneline

git checkout main
git cherry-pick <bugfix-hash>   # bring ONLY that commit onto main
git log --oneline               # verify
```
