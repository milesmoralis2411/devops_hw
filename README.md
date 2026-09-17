# DevOps Homework

This repository contains the completed DevOps homework assignments, one folder
per assignment. Each folder has its own `README.md` (or `.md`) with the tasks,
commands, and output/explanations.

## Contents

| # | Section | Topic |
|---|---------|-------|
| 1 | [01-linux-fundamentals](02-linux/) | Links, user management, journalctl, command cheat sheet |
| 2 | [02-shell-scripting](03-shell-scripting/) | System information script |
| 3 | [03-networking-fundamentals](04-networking/) | Networking command practice |
| 4 | [04-git-github](05-git/) | Commit behavior and cherry-pick |
| 5 | [05-docker-fundamentals](06-docker-hello-world/) | Containerizing NGINX, Apache, Node.js, Python, Java, and React apps |
| 6 | [06-dockerfiles-images](07-docker-multi-stage/) | Dockerfiles, image builds, and multi-stage builds |
| 7 | [07-docker-networking-volumes](01-docker-networking-volumes/) | Bind mounts, container networking, host and overlay networks |
| 8 | [08-kubernetes-fundamentals](08-kubernetes-fundamentals/) | Cluster architecture, Minikube setup, kubectl basics, and namespaces |
| 9 | [09-kubernetes-pods-replicasets-deployments](09-kubernetes-pods-replicasets-deployments/) | Pods, ReplicaSets, and Deployments with rolling update and rollback |
| 10 | [10-kubernetes-networking-services](10-kubernetes-networking-services/) | ClusterIP, NodePort, LoadBalancer, ExternalName, and headless Services |
| 11 | [11-kubernetes-ingress-configmaps-secrets](11-kubernetes-ingress-configmaps-secrets/) | Ingress routing with ConfigMaps and Secrets |

## ToKnow

- Screenshots are named `<topic>_24bcs10326.png` and live beside the task they document.

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
- **08 Kubernetes Fundamentals** — Minikube cluster setup, kubectl basics, namespaces.
  See [`README.md`](08-kubernetes-fundamentals/README.md).
- **09 Kubernetes Pods/ReplicaSets/Deployments** — Pod creation, ReplicaSet self-healing,
  Deployment rolling updates and rollbacks.
  See [`README.md`](09-kubernetes-pods-replicasets-deployments/README.md).
- **10 Kubernetes Networking/Services** — ClusterIP, NodePort, LoadBalancer,
  ExternalName, and headless Services.
  See [`README.md`](10-kubernetes-networking-services/README.md).
- **11 Kubernetes Ingress/ConfigMaps/Secrets** — Ingress routing with ConfigMaps and Secrets.
  See [`README.md`](11-kubernetes-ingress-configmaps-secrets/README.md).

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
