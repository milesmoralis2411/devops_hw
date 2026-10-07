# Kubernetes Pods, ReplicaSets, and Deployments

This lab demonstrates three Kubernetes workload objects using NGINX:

| Object | Manifest | What it demonstrates |
| --- | --- | --- |
| Pod | `01-pod/nginx-pod.yaml` | A single, manually managed NGINX container |
| ReplicaSet | `02-replicaset/nginx-replicaset.yaml` | Maintaining three identical NGINX Pods and self-healing |
| Deployment | `03-deployment/nginx-deployment.yaml` | Managing ReplicaSets with a rolling update and rollback |
| Deployment strategies | [`04-deployment-strategies/`](04-deployment-strategies/) | Rolling update, blue-green, canary and recreate |
| Pod lifecycle | [`05-pod-lifecycle/`](05-pod-lifecycle/) | Pending, Running, Succeeded, Failed, restart back-off, init containers, hooks, probes |

## Pod

A Pod is Kubernetes' smallest deployable unit. This standalone NGINX Pod is running with one container, its own IP address, and defined CPU and memory limits. A Pod is not self-healing: if it is deleted, no controller recreates
it.

![Pod creation and running status](01-pod/pod-running_24bcs10326.png)

![Pod labels and details](01-pod/pod-details_24bcs10326.png)

## ReplicaSet

A ReplicaSet keeps a specified number of identical Pods running. Here, its desired count is three. When one Pod was deleted, the ReplicaSet immediately created a replacement and restored the count to three.

![ReplicaSet creation](02-replicaset/replicaset-created_24bcs10326.png)

![ReplicaSet replacement Pod](02-replicaset/replicaset-self-healing_24bcs10326.png)

## Deployment

A Deployment manages ReplicaSets and provides controlled application updates.
It started with three ready Pods, then replaced NGINX 1.25 with NGINX 1.26 through a rolling update. Kubernetes recorded both revisions, making a rollback to the earlier version possible.

![Deployment creation and initial rollout](03-deployment/deployment-rollout_24bcs10326.png)

![Deployment image update and rollout history](03-deployment/deployment-rolling-update_24bcs10326.png)

![Deployment rollback](03-deployment/deployment-rollback_24bcs10326.png)

## Task 1 — Deployment strategies

All four strategies were implemented and run live; see
[04-deployment-strategies/README.md](04-deployment-strategies/README.md) for the
walkthrough and [EVIDENCE.md](04-deployment-strategies/EVIDENCE.md) for the raw
output.

| Strategy | What the run showed |
| --- | --- |
| Rolling update | Old (1.25) and new (1.26) Pods overlapped; one swapped at a time with zero capacity loss |
| Blue-green | One selector patch moved 100% of traffic from `BLUE v1.0` to `GREEN v2.0`, and back again |
| Canary | 1 canary + 4 stable replicas → 18 of 100 requests hit the canary (~20%) |
| Recreate | All 4 old Pods terminated before any new Pod was created — a visible outage window |

> **Screenshots:** live output from a second run on 2026-10-07; Pod names, ages and the exact canary split differ slightly from the EVIDENCE files.

![Rolling update: rollout to the new version](04-deployment-strategies/screenshots/strategy-1-rolling-update-1_24bcs10326.png)

![Rolling update: old and new ReplicaSets](04-deployment-strategies/screenshots/strategy-1-rolling-update-2_24bcs10326.png)

![Blue-green: switch the Service selector](04-deployment-strategies/screenshots/strategy-2-blue-green_24bcs10326.png)

![Canary: 15/85 split, then promotion](04-deployment-strategies/screenshots/strategy-3-canary_24bcs10326.png)

![Recreate: every old Pod terminates before new ones start](04-deployment-strategies/screenshots/strategy-4-recreate-1_24bcs10326.png)

![Recreate: events and final Pods](04-deployment-strategies/screenshots/strategy-4-recreate-2_24bcs10326.png)

## Task 2 — Pod lifecycle

Eight YAML files each drive a Pod into one lifecycle state. Each was applied,
inspected with `get` and `describe`, and explained; see
[05-pod-lifecycle/README.md](05-pod-lifecycle/README.md).

![01-pending.yaml: Pending, FailedScheduling](05-pod-lifecycle/screenshots/lifecycle-01-pending_24bcs10326.png)

![02-running.yaml: Running and Ready](05-pod-lifecycle/screenshots/lifecycle-02-running_24bcs10326.png)

![03-succeeded.yaml: Completed, exit code 0](05-pod-lifecycle/screenshots/lifecycle-03-succeeded_24bcs10326.png)

![04-failed.yaml: Error, exit code 1](05-pod-lifecycle/screenshots/lifecycle-04-failed_24bcs10326.png)

![05-crashloopbackoff.yaml: restarts with growing back-off](05-pod-lifecycle/screenshots/lifecycle-05-crashloopbackoff_24bcs10326.png)

![06-init-containers.yaml: Init:0/2 to Running](05-pod-lifecycle/screenshots/lifecycle-06-init-containers_24bcs10326.png)

![07-lifecycle-hooks.yaml: postStart and preStop](05-pod-lifecycle/screenshots/lifecycle-07-lifecycle-hooks_24bcs10326.png)

![08-probes.yaml: startup, liveness, readiness](05-pod-lifecycle/screenshots/lifecycle-08-probes_24bcs10326.png)

![Every phase side by side](05-pod-lifecycle/screenshots/lifecycle-summary-of-every-phase_24bcs10326.png)

## Takeaway

A Pod runs an application, a ReplicaSet maintains the required number of Pods and a Deployment manages ReplicaSets to support safe updates and rollbacks.
