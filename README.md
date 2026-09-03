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
| 4 | [`04-networking/`](04-networking/) | Networking commands (`ping`, DNS, `curl`, `ip addr`, …) | [`README.md`](04-networking/README.md) with real output + explanations |
| 5 | [`05-git/`](05-git/) | `git commit -a -m` vs `-m`, cherry-pick | Real command output + `demo-repo/` |
| 6 | [`06-docker-hello-world/`](06-docker-hello-world/) | 6 "Hello World" Dockerized apps | Node, Python, Java, Apache, React, Nginx — code + Dockerfiles |
| 7 | [`07-docker-multi-stage/`](07-docker-multi-stage/) | Multi-stage Docker build on port 8080 | Go app + multi-stage Dockerfile + docs |

## How this repo was completed

Almost everything was **executed live** and the real command output is captured
in the READMEs / `EVIDENCE.md` files:

- **03 Shell script** — ran `sysinfo.sh`, real output in its README.
- **04 Networking** — ran the commands, real output + explanations.
- **05 Git** — ran the `commit -a -m` and cherry-pick workflow, real output.
- **01 Docker networking & volumes** — all 4 tasks run on Docker Desktop
  (Engine v29.7.2, WSL2). See [`EVIDENCE.md`](01-docker-networking-volumes/EVIDENCE.md):
  network isolation proven, host-network port 80 confirmed, bind-mount live edit,
  overlay service converged.
- **06 Docker Hello World** — all 6 apps built and running, each returns
  "Hello World". See [`EVIDENCE.md`](06-docker-hello-world/EVIDENCE.md).
- **07 Docker multi-stage** — built & run on port 8080, final image only 23.2 MB.
  See [`EVIDENCE.md`](07-docker-multi-stage/EVIDENCE.md).
- **02 Linux** — Tasks 1–3 executed on **Ubuntu 26.04 (WSL2, systemd 259)**:
  soft/hard links (with the symlink correctly breaking), `adduser` created a real
  user, `journalctl` returned real logs. See
  [`EVIDENCE.md`](02-linux/EVIDENCE.md).

> The `EVIDENCE.md` files contain the verbatim terminal output. For image-style
> screenshots (browser windows), open the running apps at the ports listed and
> capture them — the apps are live once you run the build commands.

## Quick start (Docker homeworks)

```bash
# Example: the multi-stage build
cd 07-docker-multi-stage
docker build -t multistage-hello .
docker run -d -p 8080:8080 --name multistage-hello multistage-hello
curl http://localhost:8080   # -> Hello World from Docker multi-stage build
```

See each folder's README for the full instructions.
