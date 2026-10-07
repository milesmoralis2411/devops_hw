# Session 13 — Kubernetes Storage, HPA & Probes

| Task | Folder | Contents |
| --- | --- | --- |
| 1. Kubernetes volumes | [01-kubernetes-volumes/](01-kubernetes-volumes/) | emptyDir, hostPath, PV, PVC, StorageClass and dynamic provisioning — explained, with four working examples |
| 2. HPA hands-on | [02-hpa/](02-hpa/) | `hpa.yml`, a load generator, and scaling observed live: 1 → 10 and back to 1 |
| Probes | [03-probes/](03-probes/) | Startup, readiness and liveness — healthy, failing-liveness, failing-readiness, exec and tcpSocket |
| 3. Mini project | [04-mini-project/](04-mini-project/) | "Resilient Notes": PVC + init container + three probes + CPU/memory HPA + ConfigMap/Secret |

Every manifest was applied on minikube v1.39.0 / Kubernetes v1.37.0 with
metrics-server. Each folder has an `EVIDENCE.md` with the verbatim output.

## Highlights from the runs

| Topic | Observation |
| --- | --- |
| emptyDir | Shared between two containers; **gone** after the Pod was recreated (log back to 1 line) |
| PV/PVC | Data survived a brand-new Pod. Deleting the PVC left the `Retain` PV `Released`, not deleted |
| Dynamic provisioning | A PVC alone produced a PV in under a second, through `k8s.io/minikube-hostpath` |
| HPA | 165% CPU → **1 → 2 → 4 → 8 → 9 → 10** replicas (capped at `maxReplicas`); after the load stopped, a 300s wait then **10 → 5 → 2 → 1** |
| Liveness | A wrong path restarted a healthy nginx twice in 45s |
| Readiness | A failing Pod stayed listed in the EndpointSlice but `ready=false` — no traffic, no restart |
| Shared failure | Deleting the health file from a *shared* PVC took every replica out at once |
| Init containers | A liveness restart does **not** re-run init containers; only a new Pod does |
