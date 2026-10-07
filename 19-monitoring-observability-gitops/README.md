# Session 20 — Monitoring, Observability & GitOps

| Task | Folder | Contents |
| --- | --- | --- |
| 1. Monitoring | [01-monitoring/](01-monitoring/) | An instrumented app plus Prometheus, Alertmanager, Grafana and kube-state-metrics on minikube. Demonstrates metrics, logs, alerts, CPU and memory utilisation, and application health — all live |
| 2. Observability | [02-observability/](02-observability/) | The three pillars (metrics, logs, traces), why observability is needed, common tools, Kubernetes observability |
| 3. GitOps | [03-gitops/](03-gitops/) | Concepts plus a live Argo CD demo: sync from GitHub, three kinds of self-healing, then the full commit → sync → revert → prune loop against an in-cluster Git server |

Deliverables map:

| Deliverable | Where |
| --- | --- |
| Monitoring demo | [01-monitoring/README.md](01-monitoring/README.md) + [EVIDENCE.md](01-monitoring/EVIDENCE.md) |
| Observability documentation | [02-observability/README.md](02-observability/README.md) |
| GitOps demo | [03-gitops/README.md](03-gitops/README.md) + [EVIDENCE.md](03-gitops/EVIDENCE.md) |
| Screenshots | Grafana, Prometheus (targets, alerts, PromQL) and Alertmanager in [01-monitoring/README.md](01-monitoring/README.md#screenshots); Argo CD syncing from GitHub in [03-gitops/README.md](03-gitops/README.md#try-the-full-commit--sync-loop-yourself) |

Executed on minikube v1.39.0 / Kubernetes v1.37.0 with Prometheus v2.55.1,
Alertmanager v0.27.0, Grafana 11.3.0, kube-state-metrics v2.13.0, Argo CD
v3.5.4 and Gitea 1.27.3.
