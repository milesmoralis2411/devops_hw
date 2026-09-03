# DevOps Homework

This repository contains the completed DevOps homework assignments, one folder
per assignment. Each folder has its own `README.md` (or `.md`) with the tasks,
commands, and output/explanations.

## Contents

| # | Folder | Topic | Deliverables |
|---|--------|-------|--------------|
| 1 | [`01-docker-networking-volumes/`](01-docker-networking-volumes/) | Docker container/host/overlay networking & bind-mount volumes | Documented commands + expected output for all 4 tasks |
| 2 | [`02-linux/`](02-linux/) | Soft/hard links, `adduser` vs `useradd`, `journalctl`, cheat sheet | Full explanations, commands, comparison tables |
| 3 | [`03-shell-scripting/`](03-shell-scripting/) | System-information shell script | [`sysinfo.sh`](03-shell-scripting/sysinfo.sh) + real captured output |
| 4 | [`04-networking/`](04-networking/) | Networking commands (`ping`, DNS, `curl`, `ip addr`, …) | [`networking-commands.md`](04-networking/networking-commands.md) with real output + explanations |
| 5 | [`05-git/`](05-git/) | `git commit -a -m` vs `-m`, cherry-pick | Real command output + `demo-repo/` |
| 6 | [`06-docker-hello-world/`](06-docker-hello-world/) | 6 "Hello World" Dockerized apps | Node, Python, Java, Apache, React, Nginx — code + Dockerfiles |
| 7 | [`07-docker-multi-stage/`](07-docker-multi-stage/) | Multi-stage Docker build on port 8080 | Go app + multi-stage Dockerfile + docs |

## How this repo was completed

- **Tasks executed live** (real output captured in the READMEs): the shell script
  (03), the Git commit/cherry-pick workflow (05), and the networking commands (04).
- **Docker tasks (01, 06, 07):** all application code and `Dockerfile`s are
  provided and ready to build/run. Each README lists the exact `docker build` /
  `docker run` commands and the expected result. Docker was not installed on the
  machine used to author this repo, so add your own screenshots of the running
  containers into a `screenshots/` folder under each Docker homework.
- **Linux tasks (02):** documented with commands and comparison tables (best run
  on a native Linux host).

## Quick start (Docker homeworks)

```bash
# Example: the multi-stage build
cd 07-docker-multi-stage
docker build -t multistage-hello .
docker run -d -p 8080:8080 --name multistage-hello multistage-hello
curl http://localhost:8080   # -> Hello World from Docker multi-stage build
```

See each folder's README for the full instructions.
