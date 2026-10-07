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

## Screenshots

Live output from a second run of every task on 2026-10-07. The same images
also appear in each task's README, next to the explanation.

### Task 1 — Kubernetes volumes

![emptyDir shared by two containers, gone with the Pod](01-kubernetes-volumes/screenshots/vol-emptydir-shared-between-two-containers-gone-with_24bcs10326.png)

![hostPath reading a file written on the node](01-kubernetes-volumes/screenshots/vol-hostpath-reading-the-node-filesystem_24bcs10326.png)

![Static PV + PVC: data survives a new Pod](01-kubernetes-volumes/screenshots/vol-persistentvolume-persistentvolumeclaim-static_24bcs10326.png)

![StorageClass dynamically provisions a PV](01-kubernetes-volumes/screenshots/vol-storageclass-dynamic-provisioning_24bcs10326.png)

### Task 2 — HPA hands-on

![1. Deploy the application and 2. configure the HPA](02-hpa/screenshots/hpa-1-deploy-the-application-and-2-configure-the-hpa_24bcs10326.png)

![3. Verify the HPA](02-hpa/screenshots/hpa-3-verify-the-hpa_24bcs10326.png)

![4. Deploy the load generator / 5. increase load](02-hpa/screenshots/hpa-4-deploy-the-load-generator-5-increase-load_24bcs10326.png)

![6. CPU utilisation and 7. Pod scaling, sampled every 30s  (1/3)](02-hpa/screenshots/hpa-6-cpu-utilisation-and-7-pod-scaling-sampled-ever-1_24bcs10326.png)

![6. CPU utilisation and 7. Pod scaling, sampled every 30s  (2/3)](02-hpa/screenshots/hpa-6-cpu-utilisation-and-7-pod-scaling-sampled-ever-2_24bcs10326.png)

![6. CPU utilisation and 7. Pod scaling, sampled every 30s  (3/3)](02-hpa/screenshots/hpa-6-cpu-utilisation-and-7-pod-scaling-sampled-ever-3_24bcs10326.png)

![Scale-out evidence](02-hpa/screenshots/hpa-scale-out-evidence_24bcs10326.png)

![Remove the load and watch it scale back in](02-hpa/screenshots/hpa-remove-the-load-and-watch-it-scale-back-in_24bcs10326.png)

### Probes

![startup, liveness and readiness probes passing](03-probes/screenshots/probe-probes_24bcs10326.png)

![Failing liveness probe: restarts](03-probes/screenshots/probe-failing-liveness-probe-restarts_24bcs10326.png)

![Failing readiness probe: removed from the Service, never restarted](03-probes/screenshots/probe-failing-readiness-probe-removed-from-service-nev_24bcs10326.png)

![exec and tcpSocket probe handlers](03-probes/screenshots/probe-exec-and-tcpsocket-probe-handlers_24bcs10326.png)

### Task 3 — Mini project (Resilient Notes)

![Deploy the mini project](04-mini-project/screenshots/mini-deploy-the-mini-project_24bcs10326.png)

![Storage: the init container seeded the PVC](04-mini-project/screenshots/mini-storage-the-init-container-seeded-the-pvc_24bcs10326.png)

![Data survives Pod replacement](04-mini-project/screenshots/mini-data-survives-pod-replacement_24bcs10326.png)

![Configuration: ConfigMap + Secret injected](04-mini-project/screenshots/mini-configuration-configmap-secret-injected_24bcs10326.png)

![Probes: break /healthz and watch Kubernetes react](04-mini-project/screenshots/mini-probes-break-healthz-and-watch-kubernetes-react_24bcs10326.png)

![HPA: generate load](04-mini-project/screenshots/mini-hpa-generate-load_24bcs10326.png)
