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
| 12 | [12-kubernetes-storage-hpa-probes](12-kubernetes-storage-hpa-probes/) | Volumes (emptyDir, hostPath, PV/PVC, StorageClass), HPA, probes, mini project |
| 13 | [13-kubernetes-troubleshooting](13-kubernetes-troubleshooting/) | Troubleshooting commands, nine common failures, layered-bug mini project |
| 14 | [14-helm](14-helm/) | Helm commands, install → upgrade → rollback, multi-environment chart |
| 15 | [15-cicd-github-actions](15-cicd-github-actions/) | CI/CD demo project: app, tests, Dockerfile, CI and CD workflows |
| 16 | [16-cicd-devsecops](16-cicd-devsecops/) | DevSecOps pipeline: SAST, SCA, secret scanning, image scanning, security gate |
| 17 | [17-terraform-iac](17-terraform-iac/) | Terraform S3 demo (full lifecycle) + AWS IAM, EC2, S3, VPC, DynamoDB/RDS research |
| 18 | [18-cloud-terraform-in-action](18-cloud-terraform-in-action/) | VPC + subnet + SG + EC2 + S3 with Terraform, dependency graph, drift |
| 19 | [19-monitoring-observability-gitops](19-monitoring-observability-gitops/) | Prometheus/Grafana/Alertmanager monitoring, observability, Argo CD GitOps |
| 20 | [20-final-devops-project](20-final-devops-project/) | End-to-end platform: CI/CD + DevSecOps + Terraform + Helm + monitoring + GitOps + troubleshooting challenge |

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
- **09 Kubernetes Pods/ReplicaSets/Deployments (additions)** — all four deployment
  strategies (rolling, blue-green, canary 1:4 → 18% traffic, recreate) and eight
  Pod lifecycle states, run live. See
  [`04-deployment-strategies`](09-kubernetes-pods-replicasets-deployments/04-deployment-strategies/)
  and [`05-pod-lifecycle`](09-kubernetes-pods-replicasets-deployments/05-pod-lifecycle/).
- **10 Kubernetes Networking/Services (additions)** — object comparisons, FQDN and
  CoreDNS write-ups, verified live (search path, `ndots:5` seen in the CoreDNS log).
- **11 Kubernetes Ingress/ConfigMaps/Secrets** — Ingress routing with ConfigMaps and Secrets.
  See [`README.md`](11-kubernetes-ingress-configmaps-secrets/README.md). Additions:
  Ingress vs Ingress Controller, why Secrets do not belong in Git, and a
  four-case troubleshooting lab with before/after output.
- **12 Storage, HPA & Probes** — volumes, PV/PVC, dynamic provisioning, the HPA
  scaling 1 → 10 → 1 under load, all probe types, and a mini project.
- **13 Kubernetes Troubleshooting** — every kubectl troubleshooting command, nine
  failure modes reproduced and fixed, and a five-bug layered mini project.
- **14 Helm** — every Helm command, install → upgrade → failed upgrade → rollback,
  and one chart deployed to dev and prod.
- **15 CI/CD** — app with tests, multi-stage Dockerfile (tests inside the build),
  CI and CD workflows; built, smoke-tested and deployed to minikube.
- **16 DevSecOps** — every pipeline stage run locally: SAST, SCA, secret scanning,
  image scanning, gate. Found and fixed 10 HIGH CVEs in the base image's npm, and
  flagged a credential committed in Session 12.
- **17 Terraform** — the S3 project taken through `init` → `destroy` (against
  LocalStack; no AWS account was available), plus five AWS service write-ups.
- **18 Cloud & Terraform** — VPC + subnet + SG + EC2 + S3 (19 resources): plan,
  apply, state, dependency graph, drift detection and destroy (LocalStack).
- **19 Monitoring, Observability & GitOps** — Prometheus/Alertmanager/Grafana with
  alerts that fired and resolved; Argo CD self-healing plus the full Git
  commit → sync → revert → prune loop.
- **20 Final project** — Terraform-bootstrapped cluster, CI pipeline with a
  security gate and a container registry, Helm, Argo CD app-of-apps,
  monitoring, and a five-fault troubleshooting challenge resolved through Git.

### Tooling used for sessions 12–20

minikube v1.39.0 (Kubernetes v1.37.0, containerd), Helm v3.22.0, Terraform v1.16.5,
LocalStack 3.8.1, Argo CD v3.5.4, Prometheus v2.55.1, Grafana 11.3.0,
Trivy 0.57.1, Gitleaks 8.21.2, Semgrep 1.179.0 — on Windows 11 with Docker Desktop.

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
